// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Repo _$RepoFromJson(Map<String, dynamic> json) =>
    Repo(name: json['name'] as String, status: json['status'] as String, description: json['description'] as String?);

Map<String, dynamic> _$RepoToJson(Repo instance) => <String, dynamic>{
  'name': instance.name,
  'status': instance.status,
  'description': ?instance.description,
};

// **************************************************************************
// RepositoryGenerator
// **************************************************************************

extension LocalStoreRepo on Repo {
  static String get tableName => 'repo';

  static String get onCreateTableRepoSQL =>
      """
        CREATE TABLE $tableName (
          id TEXT PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          owner TEXT NOT NULL,
          parent_id TEXT,
          "unique" TEXT,
          sync_status TEXT NOT NULL,
          body TEXT NOT NULL
        )
      """;

  static Future<Database> getDb() async {
    return await TestDataBase().getDb();
  }
}

typedef RepoDataItem = DataItem<Repo>;

class RepoRepository {
  Future<void> addToLocalDb(RepoDataItem item) async {
    final db = await LocalStoreRepo.getDb();
    await db.insert(LocalStoreRepo.tableName, item.toJson((r) => json.encode(r.toJson())));
  }

  Future<RepoDataItem?> getFromLocalDb(String id) async {
    final db = await LocalStoreRepo.getDb();
    final List<Map<String, dynamic>> maps = await db.query(LocalStoreRepo.tableName, where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return DataItem<Repo>.fromJson(maps.first, (jsonStr) => Repo.fromJson(json.decode(jsonStr as String)));
    }
    return null;
  }

  Future<List<RepoDataItem>> listFromLocalDb({String? parentId}) async {
    final db = await LocalStoreRepo.getDb();
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (parentId != null) {
      whereClauses.add('parent_id = ?');
      whereArgs.add(parentId);
    }
    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final List<Map<String, dynamic>> maps = await db.query(
      LocalStoreRepo.tableName,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    return maps
        .map((map) => DataItem<Repo>.fromJson(map, (jsonStr) => Repo.fromJson(json.decode(jsonStr as String))))
        .toList();
  }

  Future<void> deleteFromLocalDb(String id) async {
    final db = await LocalStoreRepo.getDb();
    await db.delete(LocalStoreRepo.tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateToLocalDb(RepoDataItem item) async {
    final db = await LocalStoreRepo.getDb();
    await db.update(
      LocalStoreRepo.tableName,
      item.toJson((r) => json.encode(r.toJson())),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> upsertToLocalDb(RepoDataItem item) async {
    if (await getFromLocalDb(item.id) == null) {
      await addToLocalDb(item);
    } else {
      await updateToLocalDb(item);
    }
  }
}

class RepoController extends GetxController {
  final SyncStoreClient client;
  final _RepoSyncEngine _syncEngine;
  RepoController(this.client) : _syncEngine = _RepoSyncEngine(client);

  final RxList<RepoDataItem> _items = <RepoDataItem>[].obs;
  final Rx<String?> currentRepoId = Rx<String?>(null);

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
    _items.value = await RepoRepository().listFromLocalDb();
  }

  void onSelectRepo(String id) {
    currentRepoId.value = id;
  }

  List<RepoDataItem> onViewRepos(String? parent_id) {
    if (parent_id == null) {
      return _items;
    }
    return _items.where((item) => item.parentId == parent_id).toList();
  }

  Future<void> trySyncAll() async => await _syncEngine.syncAll();
  void _replaceLocal(String id, RepoDataItem fetchedItem) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index] = fetchedItem;
    }
    // print('Replaced local Repo with id: $id, new id: ${fetchedItem.id}');
    if (currentRepoId.value == id && fetchedItem.id != id) {
      // update current selected id if changed by server generated id
      currentRepoId.value = fetchedItem.id;
    }
  }

  void addData(Repo newData) {
    // generate a local uuid before successfully created on server
    final owner = client.currentUserId();
    final newItem = RepoDataItem.localNew(owner, newData);
    // it's a temporary memory data, not even in local db yet.
    _items.add(newItem);
    _syncEngine.create(newItem).then((fetchedItem) {
      _replaceLocal(newItem.id, fetchedItem);
    });
  }

  void updateData(String id, Repo updatedData) {
    final item = _items.firstWhere((item) => item.id == id);
    // todo maybe rewrite this update body method...
    final updatedItem = item.updatedBody(updatedData);
    _items[_items.indexOf(item)] = updatedItem;
    _syncEngine.update(updatedItem).then((fetchedItem) {
      _replaceLocal(updatedItem.id, fetchedItem);
    });
  }

  void deleteData(String id) {
    _items.removeWhere((item) => item.id == id);
    if (currentRepoId.value == id) {
      currentRepoId.value = null;
    }
    final status = _items.firstWhereOrNull((item) => item.id == id)?.syncStatus;
    _syncEngine.delete(id, status != SyncStatus.deleted);
  }
}

class _RepoSyncEngine {
  final SyncStoreClient client;
  _RepoSyncEngine(this.client);

  Future<RepoDataItem> create(RepoDataItem local) async {
    local.syncStatus = SyncStatus.syncing;
    await RepoRepository().addToLocalDb(local);

    RepoDataItem createdItem;
    try {
      final newId = await client.create('xbb', 'repo', local.body.toJson());
      createdItem = await client.get<Repo>('xbb', 'repo', newId, Repo.fromJson);
    } catch (e) {
      local.syncStatus = SyncStatus.failed;
      await RepoRepository().updateToLocalDb(local);
      rethrow;
    }
    createdItem.syncStatus = SyncStatus.archived;

    await RepoRepository().deleteFromLocalDb(local.id);
    await RepoRepository().addToLocalDb(createdItem);
    return createdItem;
  }

  Future<RepoDataItem> update(RepoDataItem local) async {
    local.syncStatus = SyncStatus.syncing;
    await RepoRepository().updateToLocalDb(local);

    RepoDataItem updatedItem;
    try {
      await client.update('xbb', 'repo', local.id, local.body.toJson());
      updatedItem = await client.get<Repo>('xbb', 'repo', local.id, Repo.fromJson);
    } catch (e) {
      local.syncStatus = SyncStatus.failed;
      await RepoRepository().updateToLocalDb(local);
      rethrow;
    }
    updatedItem.syncStatus = SyncStatus.archived;

    await RepoRepository().updateToLocalDb(updatedItem);
    return updatedItem;
  }

  void delete(String id, bool deleteFromServer) {
    RepoRepository().deleteFromLocalDb(id);
    if (!deleteFromServer) {
      return;
    }
    try {
      client.delete('xbb', 'repo', id);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncAll() async {
    try {
      var nextMarker = null;
      final serviceIds = <String>{};
      do {
        final ListResponse resp = await client.list('xbb', 'repo', limit: 50, marker: nextMarker);
        nextMarker = resp.pageInfo.nextMarker;
        for (var summary in resp.items) {
          serviceIds.add(summary.id);
          final RepoDataItem? localItem = await RepoRepository().getFromLocalDb(summary.id);
          if (localItem == null) {
            // new from server
            final RepoDataItem item = await client.get<Repo>('xbb', 'repo', summary.id, Repo.fromJson);
            await RepoRepository().addToLocalDb(item);
          } else if (localItem.updatedAt.isBefore(summary.updatedAt)) {
            // update local data.
            final RepoDataItem item = await client.get<Repo>('xbb', 'repo', summary.id, Repo.fromJson);
            await RepoRepository().updateToLocalDb(item);
          } else if (localItem.updatedAt.isAfter(summary.updatedAt)) {
            // local data is newer, need to sync to server
            localItem.syncStatus = SyncStatus.failed;
            await RepoRepository().updateToLocalDb(localItem);
          }
        }
      } while (nextMarker != null);
      // clean up local data that are deleted from server
      final localItems = await RepoRepository().listFromLocalDb();
      for (RepoDataItem localItem in localItems) {
        if (!serviceIds.contains(localItem.id)) {
          localItem.syncStatus = SyncStatus.deleted;
          await RepoRepository().updateToLocalDb(localItem);
        }
      }
    } catch (e) {
      // todo more error handling?
      rethrow;
    }
  }
}
