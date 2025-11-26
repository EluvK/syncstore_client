import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncstore_client/syncstore_client.dart';
import 'package:sync_annotation/sync_annotation.dart';

part 'main.g.dart';

Future<void> debug() async {
  // print('Debugging...');

  // final RepoDataItem? item = await RepoRepository().getFromLocalDb('6664c918-dd2e-47b6-b82c-a2add61ac702');
  // if (item != null) {
  //   print('Fetched from local db: ${item.toJson((Repo r) => r.toJson())}');
  //   print('updated at: ${item.updatedAt.toIso8601String()}');
  // } else {
  //   print('No such item in local db.');
  // }

  // print('Debugging done.');
}

void main() async {
  final storage = InMemoryTokenStorage();
  final client = SyncStoreClient(baseUrl: 'http://localhost:1011/api', tokenStorage: storage);
  try {
    await client.login('test', 'password');
    print('Login successful');
  } catch (e) {
    print('Login failed: $e');
    return;
  }

  // local repos:
  var currentRepos = await RepoRepository().listFromLocalDb();
  print('1. Local repos count: ${currentRepos.length}');
  for (DataItem<Repo> item in currentRepos) {
    print(item.toJson((Repo r) => r.toJson()));
  }

  // try load from server and store to local db if not synced
  try {
    print('2. Syncing repos from server...');
    final serverRepos = await client.list<Repo>('xbb', 'repo', fromJson: Repo.fromJson, limit: 50);
    for (DataItem<Repo> item in serverRepos.items) {
      final RepoDataItem? findLocal = currentRepos.firstWhereOrNull((e) => e.id == item.id);
      if (findLocal == null || findLocal.updatedAt.isBefore(item.updatedAt)) {
        print('  Remote data: ${item.toJson((Repo r) => r.toJson())}');
        await RepoRepository().upsertToLocalDb(item);
        print('  Synced repo && Update local db: ${item.id}');
        // debug: fetch it see
        final RepoDataItem? checkItem = await RepoRepository().getFromLocalDb(item.id);
        print('  Checked from local db: ${checkItem?.toJson((Repo r) => r.toJson())}');
      } else {
        print('  Local repo is up-to-date: ${item.id}');
      }
    }
  } catch (e) {
    print('Failed to sync repos from server: $e');
  }
  await debug();

  // try update one of the local repos (if any)
  if (currentRepos.isNotEmpty) {
    RepoDataItem firstRepo = currentRepos.first;
    // todo not satisfied with this updated body API design
    RepoDataItem newUpdatedRepo = firstRepo.updatedBody(
      Repo(
        description: 'Updated locally at ${DateTime.now().toIso8601String()}',
        name: firstRepo.body.name,
        status: firstRepo.body.status,
      ),
    );
    await RepoRepository().updateToLocalDb(newUpdatedRepo);
    print('3. Updated local repo: ${newUpdatedRepo.id}');
    try {
      await client.update('xbb', 'repo', newUpdatedRepo.id, newUpdatedRepo.body.toJson());
      print('   Also updated on server: ${newUpdatedRepo.id}');
    } catch (e) {
      print('   Failed to update on server: $e');
    }
  }

  await debug();
  // try create a new one, then fetch from server and store to local db
  // actually we need a temporary repo item, we can makeup the meta info and then override it after fetching from server
  // which can be flagged by sync_status field
  Repo newRepo = Repo(name: 'some-repo', status: 'normal', description: 'Created from client example');
  String newLocalId = 'local-only-repo-id';
  try {
    newLocalId = await client.create('xbb', 'repo', newRepo.toJson());
    print('4. Created new repo on server: $newLocalId');
  } catch (e) {
    print('Failed to create repo on server: $e');
  }
  RepoDataItem item = await client.get<Repo>('xbb', 'repo', newLocalId, Repo.fromJson);
  print('Fetched newly created repo from server: ${item.toJson((Repo r) => r.toJson())}');
  await RepoRepository().addToLocalDb(item);

  await debug();
  // try delete a repo at local and server
  if (currentRepos.isNotEmpty) {
    final toDelete = currentRepos.last;
    try {
      await client.delete('xbb', 'repo', toDelete.id);
      print('5. Deleted repo on server: ${toDelete.id}');
    } catch (e) {
      print('Failed to delete repo on server: $e');
    }
    await RepoRepository().deleteFromLocalDb(toDelete.id);
    print('   Also deleted from local db: ${toDelete.id}');
  }

  return;
}

@Repository(tableName: 'repo', db: TestDataBase)
@JsonSerializable(includeIfNull: false)
class Repo {
  String name;
  String status;
  String? description;

  Repo({required this.name, required this.status, this.description});

  factory Repo.fromJson(Map<String, dynamic> json) => _$RepoFromJson(json);
  Map<String, dynamic> toJson() => _$RepoToJson(this);
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
          await db.execute(LocalStoreRepo.onCreateTableRepoSQL);
        },
      ),
    );
    return _db!;
  }
}
