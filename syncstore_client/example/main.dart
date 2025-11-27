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
  // final controller = Get.find<RepoController>();
  // var currentRepos = controller.onViewRepos(null);
  // print('Current repos count: ${currentRepos.length}');
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

  await Get.putAsync(() async {
    final controller = RepoController(client);
    return controller;
  });

  final controller = Get.find<RepoController>();
  await controller.ensureInitialization();

  print("0. Syncing all repos from server...");
  await controller.trySyncAll();

  // try update one of the local repos (if any)
  final viewRepos = controller.onViewRepos(null);
  if (viewRepos.length > 2) {
    String secondRepoId = viewRepos[1].id;
    print('1. Updated local repo: ${secondRepoId}');
    final Repo updatedData = Repo(
      name: viewRepos.last.body.name,
      status: viewRepos.last.body.status,
      description: 'Updated locally at ${DateTime.now().toIso8601String()}',
    );
    controller.updateData(secondRepoId, updatedData);
    await Future.delayed(Duration(seconds: 2)); // wait for background sync to finish
  }

  await debug();
  print('2. Created new repo');
  Repo newRepo = Repo(name: 'some-repo', status: 'normal', description: 'Created from client example');
  controller.addData(newRepo);
  await Future.delayed(Duration(seconds: 2)); // wait for background sync to finish

  await debug();
  // try delete a repo at local and server
  if (viewRepos.isNotEmpty) {
    final toDelete = viewRepos.first;
    print('3. Deleted repo: ${toDelete.id}');
    controller.deleteData(toDelete.id);
    await Future.delayed(Duration(seconds: 2)); // wait for background sync to finish
  }
  await debug();

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

class RepoController extends GetxController {
  final SyncStoreClient client;
  RepoController(this.client);

  final _repos = <RepoDataItem>[].obs;

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
    _repos.value = await RepoRepository().listFromLocalDb();
  }

  void onSelectRepo(String repoId) {
    currentRepoId.value = repoId;
  }

  List<RepoDataItem> onViewRepos(String? parent_id) {
    if (parent_id == null) {
      return _repos;
    }
    return _repos.where((item) => item.parentId == parent_id).toList();
  }

  Future<void> trySyncAll() async {
    try {
      var nextMarker = null;
      final serviceIds = <String>{};
      do {
        final ListResponse resp = await client.list('xbb', 'repo', limit: 50, marker: nextMarker);
        nextMarker = resp.pageInfo.nextMarker;
        for (var summary in resp.items) {
          serviceIds.add(summary.id);
          final RepoDataItem? localItem = _repos.firstWhereOrNull((e) => e.id == summary.id);
          if (localItem == null) {
            // new from server
            print('Found new repo from server: ${summary.id}');
            final RepoDataItem item = await client.get<Repo>('xbb', 'repo', summary.id, Repo.fromJson);
            await RepoRepository().addToLocalDb(item);
            _repos.add(item);
          } else if (localItem.updatedAt.isBefore(summary.updatedAt)) {
            // update local data.
            print('Found updated repo from server: ${summary.id}');
            final index = _repos.indexWhere((e) => e.id == summary.id);
            _repos[index].syncStatus = SyncStatus.syncing;
            final RepoDataItem item = await client.get<Repo>('xbb', 'repo', summary.id, Repo.fromJson);
            await RepoRepository().updateToLocalDb(item);
            _repos[index] = item;
          } else if (localItem.updatedAt.isAfter(summary.updatedAt)) {
            // local data is newer, need to sync to server
            print('Local repo ${summary.id} is newer than server, need to sync to server.');
            localItem.syncStatus = SyncStatus.failed;
          }
        }
      } while (nextMarker != null);
      // clean up local data that are deleted from server
      for (RepoDataItem localItem in _repos) {
        if (!serviceIds.contains(localItem.id)) {
          localItem.syncStatus = SyncStatus.deleted;
          await RepoRepository().updateToLocalDb(localItem);
        }
      }
    } catch (e) {
      // todo more error handling
      print('Failed to sync repos from server: $e');
    }
  }

  void addData(Repo newData) {
    // generate a local uuid before successfully created on server
    final owner = client.currentUserId();
    final newItem = RepoDataItem.localNew(owner, newData);
    _repos.add(newItem); // it's a temporary memory data, not even in local db yet.
    _bgSyncNew(newItem); // async background sync to server
  }

  void updateData(String id, Repo updatedData) {
    final index = _repos.indexWhere((item) => item.id == id);
    if (index != -1) {
      final RepoDataItem oldItem = _repos[index];
      // todo maybe rewrite this update body method...
      final updatedItem = oldItem.updatedBody(updatedData);
      _repos[index] = updatedItem;
      _bgSyncUpdate(updatedItem);
    } else {
      print('[panic] No such repo with id $id to update');
    }
  }

  void deleteData(String id) {
    final index = _repos.indexWhere((item) => item.id == id);
    if (index != -1) {
      _repos.removeAt(index);
    }
    _bgSyncDelete(id);
  }

  Future<void> _bgSyncNew(RepoDataItem newItem) async {
    assert(newItem.syncStatus == SyncStatus.pending);
    try {
      newItem.syncStatus = SyncStatus.syncing;
      final newId = await client.create('xbb', 'repo', newItem.body.toJson());
      final fetchedItem = await client.get<Repo>('xbb', 'repo', newId, Repo.fromJson);
      // change from synced to archived as it's a new one.
      fetchedItem.syncStatus = SyncStatus.archived;
      await RepoRepository().addToLocalDb(fetchedItem);
      final index = _repos.indexWhere((item) => item.id == newItem.id);
      if (index != -1) {
        _repos[index] = fetchedItem;
      }
      if (currentRepoId.value == newItem.id) {
        currentRepoId.value = fetchedItem.id;
      }
    } catch (e) {
      print('_bgSyncNew Failed to sync new repo to server: $e');
      newItem.syncStatus = SyncStatus.failed;
      await RepoRepository().updateToLocalDb(newItem);
    }
  }

  Future<void> _bgSyncUpdate(RepoDataItem updatedItem) async {
    assert(updatedItem.syncStatus == SyncStatus.pending);
    try {
      updatedItem.syncStatus = SyncStatus.syncing;
      await RepoRepository().updateToLocalDb(updatedItem);
      await client.update('xbb', 'repo', updatedItem.id, updatedItem.body.toJson());
      // fetch the latest from server to avoid any conflict, mainly update the timestamps
      final fetchedItem = await client.get<Repo>('xbb', 'repo', updatedItem.id, Repo.fromJson);
      fetchedItem.syncStatus = SyncStatus.archived;
      await RepoRepository().updateToLocalDb(fetchedItem);
      final index = _repos.indexWhere((item) => item.id == updatedItem.id);
      if (index != -1) {
        _repos[index] = fetchedItem;
      }
    } catch (e) {
      print('_bgSyncUpdate Failed to sync updated repo to server: $e');
      updatedItem.syncStatus = SyncStatus.failed;
      await RepoRepository().updateToLocalDb(updatedItem);
    }
  }

  Future<void> _bgSyncDelete(String id) async {
    try {
      await RepoRepository().deleteFromLocalDb(id);
      await client.delete('xbb', 'repo', id);
    } catch (e) {
      print('_bgSyncDelete Failed to delete repo on server: $e');
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
          await db.execute(LocalStoreRepo.onCreateTableRepoSQL);
        },
      ),
    );
    return _db!;
  }
}
