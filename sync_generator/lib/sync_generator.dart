import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:sync_annotation/sync_annotation.dart';

class RepositoryGenerator extends GeneratorForAnnotation<Repository> {
  @override
  generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) return '';

    final className = element.name!;
    final collectionName = annotation.read('collectionName').stringValue;
    final tableName = annotation.read('tableName').stringValue;
    final dbType = annotation.read('db').typeValue.getDisplayString();

    final bool generateAcl = annotation.peek('withAcl')?.boolValue ?? false;

    final dataItemType = '${className}DataItem';
    final repositoryType = '${className}Repository';
    final controllerType = '${className}Controller';
    final activeItemId = 'current${className}Id';
    final extName = 'LocalStore$className';
    final syncEngineType = '_${className}SyncEngine';

    final buffer = StringBuffer();

    buffer.writeln(_generateExtension(className, extName, tableName, dbType));
    buffer.writeln('typedef $dataItemType = DataItem<$className>;\n');
    buffer.writeln(_generateRepository(className, repositoryType, dataItemType, extName));
    buffer.writeln(
      _generateController(className, controllerType, dataItemType, repositoryType, syncEngineType, activeItemId),
    );
    if (generateAcl) {
      // todo
    }
    buffer.writeln(
      _generateSyncEngine(className, syncEngineType, dataItemType, repositoryType, collectionName, tableName),
    );

    return buffer.toString();
  }

  String _generateExtension(String className, String extName, String tableName, String dbType) {
    return '''
extension $extName on $className {
  static String get tableName => '$tableName';

  static String get onCreateTable${className}SQL => 
      """
        CREATE TABLE \$tableName (
          id TEXT PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          owner TEXT NOT NULL,
          parent_id TEXT,
          "unique" TEXT,
          sync_status TEXT NOT NULL,
          color_tag TEXT NOT NULL,
          body TEXT NOT NULL
        )
      """;

  static Future<Database> getDb() async {
    return await $dbType().getDb();
  }
}
''';
  }

  String _generateRepository(String className, String repositoryType, String dataItemType, String extName) {
    return '''
class $repositoryType {
  Future<void> addToLocalDb($dataItemType item) async {
    final db = await $extName.getDb();
    await db.insert(
      $extName.tableName, item.toJson((r) => json.encode(r.toJson())),
    );
  }

  Future<$dataItemType?> getFromLocalDb(String id) async {
    final db = await $extName.getDb();
    final List<Map<String, dynamic>> maps = await db.query($extName.tableName, where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return DataItem<$className>.fromJson(maps.first, (jsonStr) => $className.fromJson(json.decode(jsonStr as String)));
    }
    return null;
  }

  Future<List<$dataItemType>> listFromLocalDb({String? parentId}) async {
    final db = await $extName.getDb();
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (parentId != null) {
      whereClauses.add('parent_id = ?');
      whereArgs.add(parentId);
    }
    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final List<Map<String, dynamic>> maps = await db.query(
      $extName.tableName,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    return maps.map((map) => DataItem<$className>.fromJson(
      map, (jsonStr) => $className.fromJson(json.decode(jsonStr as String))))
      .toList();
  }

  Future<void> deleteFromLocalDb(String id) async {
    final db = await $extName.getDb();
    await db.delete($extName.tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateToLocalDb($dataItemType item) async {
    final db = await $extName.getDb();
    await db.update(
      $extName.tableName,
      item.toJson((r) => json.encode(r.toJson())),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> upsertToLocalDb($dataItemType item) async {
    if (await getFromLocalDb(item.id) == null) {
      await addToLocalDb(item);
    } else {
      await updateToLocalDb(item);
    }
  }
}
''';
  }

  String _generateController(
    String className,
    String controllerType,
    String dataItemType,
    String repositoryType,
    String syncEngineType,
    String activeItemId,
  ) {
    return '''
class $controllerType extends GetxController {
  final SyncStoreClient client;
  final $syncEngineType _syncEngine;
  $controllerType(this.client) : _syncEngine = $syncEngineType(client);

  final RxList<$dataItemType> _items = <$dataItemType>[].obs;
  final Rx<String?> $activeItemId = Rx<String?>(null);

  @override
  Future<void> onInit() async {
    await rebuildLocal();
    super.onInit();
    _initialized = true;
  }

  bool _initialized = false;
  Future<void> ensureInitialization() async {
    while (!_initialized) {
      await onInit();
    }
    return;
  }
  Future<void> rebuildLocal() async {
    _items.value = await $repositoryType().listFromLocalDb();
  }
  void onSelect$className(String id) {
    $activeItemId.value = id;
  }
  List<$dataItemType> onView${className}s({List<DataItemFilter> filters = const []}) {
    if (filters.isEmpty) {
      return _items;
    }
    return _items.where((item) => filters.every((filter) => filter.apply(item))).toList();
  }
  Future<void> trySyncAll() async {
    await _syncEngine.syncAll();
    await rebuildLocal();
  }
  void _replaceLocal(String id, $dataItemType fetchedItem) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = fetchedItem;
    }
    if ($activeItemId.value == id && fetchedItem.id != id) {
      // update current selected id if changed by server generated id
      $activeItemId.value = fetchedItem.id;
    }
  }
  void addData($className newData) {
    // generate a local uuid before successfully created on server
    final owner = client.currentUserId();
    final newItem = $dataItemType.localNew(owner, newData);
    // it's a temporary memory data, not even in local db yet.
    _items.add(newItem); 
    _syncEngine.create(newItem).then((fetchedItem) {
      _replaceLocal(newItem.id, fetchedItem);
    });
  }
  void updateData(String id, $className updatedData) {
    final item = _items.firstWhere((item) => item.id == id);
    // todo maybe rewrite this update body method...
    final updatedItem = item.updatedBody(updatedData);
    _items[_items.indexOf(item)] = updatedItem;
    _syncEngine.update(updatedItem).then((fetchedItem) {
      _replaceLocal(updatedItem.id, fetchedItem);
    });
  }
  void onUpdateLocalField(String id) {
    final item = _items.firstWhere((item) => item.id == id);
    $repositoryType().updateToLocalDb(item);
  }
  void deleteData(String id) {
    _items.removeWhere((item) => item.id == id);
    if ($activeItemId.value == id) {
      $activeItemId.value = null;
    }
    final status = _items.firstWhereOrNull((item) => item.id == id)?.syncStatus;
    _syncEngine.delete(id, status != SyncStatus.deleted);
  }
}
''';
  }

  String _generateSyncEngine(
    String className,
    String syncEngineType,
    String dataItemType,
    String repositoryType,
    String collectionName,
    String tableName,
  ) {
    return '''
class $syncEngineType {
  final SyncStoreClient client;
  $syncEngineType(this.client);

  Future<$dataItemType> create($dataItemType local) async {
    local.syncStatus = SyncStatus.syncing;
    await $repositoryType().addToLocalDb(local);

    $dataItemType createdItem;
    try {
      final newId = await client.create('$collectionName', '$tableName', local.body.toJson());
      createdItem = await client.get<$className>('$collectionName', '$tableName', newId, $className.fromJson);
    } catch (e) {
      local.syncStatus = SyncStatus.failed;
      await $repositoryType().updateToLocalDb(local);
      rethrow;
    }
    createdItem.syncStatus = SyncStatus.archived;
    createdItem.colorTag = local.colorTag;

    await $repositoryType().deleteFromLocalDb(local.id);
    await $repositoryType().addToLocalDb(createdItem);
    return createdItem;
  }
  Future<$dataItemType> update($dataItemType local) async {
    local.syncStatus = SyncStatus.syncing;
    await $repositoryType().updateToLocalDb(local);

    $dataItemType updatedItem;
    try {
      await client.update('$collectionName', '$tableName', local.id, local.body.toJson());
      updatedItem = await client.get<$className>('$collectionName', '$tableName', local.id, $className.fromJson);
    } catch (e) {
      local.syncStatus = SyncStatus.failed;
      await $repositoryType().updateToLocalDb(local);
      rethrow;
    }
    updatedItem.syncStatus = SyncStatus.archived;
    updatedItem.colorTag = local.colorTag;
    
    await $repositoryType().updateToLocalDb(updatedItem);
    return updatedItem;
  }
  void delete(String id, bool deleteFromServer) {
    $repositoryType().deleteFromLocalDb(id);
    if (!deleteFromServer) return;
    try {
      client.delete('$collectionName', '$tableName', id);
    } catch (e) {
      rethrow;
    }
  }
  Future<void> syncAll() async {
    try {
      String? nextMarker;
      final serviceIds = <String>{};
      do {
        final ListResponse resp = await client.list('$collectionName', '$tableName', limit: 50, marker: nextMarker);
        nextMarker = resp.pageInfo.nextMarker;
        for (var summary in resp.items) {
          serviceIds.add(summary.id);
          final $dataItemType? localItem = await $repositoryType().getFromLocalDb(summary.id);
          if (localItem == null) {
            // new from server
            final $dataItemType item = await client.get<$className>('$collectionName', '$tableName', summary.id, $className.fromJson);
            await $repositoryType().addToLocalDb(item);
          } else if (localItem.updatedAt.isBefore(summary.updatedAt)) {
            // update local data.
            final $dataItemType item = await client.get<$className>('$collectionName', '$tableName', summary.id, $className.fromJson);
            await $repositoryType().updateToLocalDb(item);
          } else if (localItem.updatedAt.isAfter(summary.updatedAt)) {
            // local data is newer, need to sync to server
            localItem.syncStatus = SyncStatus.failed;
            await $repositoryType().updateToLocalDb(localItem);
          } else if (localItem.syncStatus == SyncStatus.deleted) {
            // same updatedAt but marked as deleted as local before
            localItem.syncStatus = SyncStatus.archived;
            await $repositoryType().updateToLocalDb(localItem);
          }
        }
      } while (nextMarker != null);
      // clean up local data that are deleted from server
      final localItems = await $repositoryType().listFromLocalDb();
      for ($dataItemType localItem in localItems) {
        if (!serviceIds.contains(localItem.id)) {
          localItem.syncStatus = SyncStatus.deleted;
          await $repositoryType().updateToLocalDb(localItem);
        }
      }
    } catch (e) {
      // todo more error handling?
      rethrow;
    }
  }
}
''';
  }
}

Builder syncModelBuilder(BuilderOptions options) => SharedPartBuilder([RepositoryGenerator()], 'syncstore');
