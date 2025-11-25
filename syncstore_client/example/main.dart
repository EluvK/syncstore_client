import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncstore_client/syncstore_client.dart';

part 'main.g.dart';

void main() async {
  final storage = InMemoryTokenStorage();
  final client = SyncStoreClient(baseUrl: 'http://localhost:1011/api', tokenStorage: storage);

  try {
    final res = await perform(() async {
      // logged in
      await client.login('test', 'password');
      print('login successful');
      final list = await client.list<Repo>('xbb', 'repo', fromJson: Repo.fromJson, limit: 10);

      // list repos
      print('got ${list.items.length} repos, next marker: ${list.pageInfo.nextMarker}');
      for (DataItem<Repo> item in list.items) {
        print(item.toJson((Repo r) => r.toJson()));
      }

      // get specific repo
      if (list.items.isNotEmpty) {
        final firstRepoId = list.items.first.id;
        final DataItem<Repo> repoItem = await client.get<Repo>('xbb', 'repo', firstRepoId, Repo.fromJson);
        print('fetched repo by id: ${repoItem.toJson((Repo r) => r.toJson())}');
        await RepoRepository().addToLocalDb(repoItem);
      }

      // delete repos
      for (DataItem<Repo> item in list.items) {
        await client.delete('xbb', 'repo', item.id);
        print('deleted repo: ${item.id}');
      }

      // create a repo
      final newRepo = Repo(name: 'client-demo', status: 'normal');
      final newId = await client.create('xbb', 'repo', newRepo.toJson());
      print('created: $newId');

      // update the repo
      newRepo.name = 'client-updated-name';
      final updatedId = await client.update('xbb', 'repo', newId, newRepo.toJson());
      print('updated: $updatedId');
    });
  } on ApiException catch (e) {
    print('Error: ${e.error}, message: ${e.message}');
  }
}

abstract class TestDBBasic {
  Future<Database> getDb();
}

@JsonSerializable(includeIfNull: false)
class Repo extends TestDBBasic {
  String name;
  String status;
  String? description;

  Repo({required this.name, required this.status, this.description});

  factory Repo.fromJson(Map<String, dynamic> json) => _$RepoFromJson(json);
  Map<String, dynamic> toJson() => _$RepoToJson(this);

  @override
  Future<Database> getDb() async {
    return await TestDataBase().getDb();
  }
}

extension SSRepo on Repo {
  static String get tableName => 'repo';
  static String get onCreateTableRepoSQL =>
      '''
        CREATE TABLE ${SSRepo.tableName} (
          id TEXT PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          owner TEXT NOT NULL,
          parent_id TEXT,
          "unique" TEXT,
          body TEXT NOT NULL
        )
      ''';
  static Future<Database> DB() async {
    return await TestDataBase().getDb();
  }
}

typedef RepoDataItem = DataItem<Repo>;

class RepoRepository {
  Future<void> addToLocalDb(RepoDataItem item) async {
    final db = await SSRepo.DB();
    await db.insert(SSRepo.tableName, item.toJson((Repo r) => json.encode(r.toJson())));
  }

  Future<RepoDataItem?> getFromLocalDb(String id) async {
    final db = await SSRepo.DB();
    final List<Map<String, dynamic>> maps = await db.query(SSRepo.tableName, where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      print('maps first: ${maps.first}');
      return DataItem<Repo>.fromJson(maps.first, (jsonStr) => Repo.fromJson(json.decode(jsonStr as String)));
    }
    return null;
  }

  Future<List<RepoDataItem>> listFromLocalDb({String? parentId}) async {
    final db = await SSRepo.DB();
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (parentId != null) {
      whereClauses.add('parent_id = ?');
      whereArgs.add(parentId);
    }
    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final List<Map<String, dynamic>> maps = await db.query(SSRepo.tableName, where: whereString, whereArgs: whereArgs);
    return maps
        .map((map) => DataItem<Repo>.fromJson(map, (jsonStr) => Repo.fromJson(json.decode(jsonStr as String))))
        .toList();
  }

  Future<void> deleteFromLocalDb(String id) async {
    final db = await SSRepo.DB();
    await db.delete(SSRepo.tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateToLocalDb(RepoDataItem item) async {
    final db = await SSRepo.DB();
    await db.update(
      SSRepo.tableName,
      item.toJson((Repo r) => json.encode(r.toJson())),
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

class TestDataBase {
  static Database? _db;

  Future<Database> getDb() async {
    if (_db != null) return _db!;
    if (!Platform.isAndroid && !Platform.isIOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'example_c.db');

    _db ??= await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute(SSRepo.onCreateTableRepoSQL);
        },
      ),
    );
    return _db!;
  }
}
