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
