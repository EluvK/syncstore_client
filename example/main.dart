import 'package:json_annotation/json_annotation.dart';
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
      final list = await client.list<Repo>(
        'xbb',
        'repo',
        fromJson: (m) => Repo.fromJson(m),
        limit: 10,
      );

      print('got ${list.items.length} repos, next marker: ${list.pageInfo.nextMarker}');
      for (DataItem<Repo> item in list.items) {
        print(item.toJson((Repo r) => r.toJson()));
      }

      // create a repo
      final newId = await client.create(
        'xbb',
        'repo',
        {'name': 'client-demo', 'status': 'normal'},
      );
      print('created: $newId');
    });
  } on ApiException catch (e) {
    print('Error: ${e.error}, message: ${e.message}');
  }
}

@JsonSerializable()
class Repo {
  String name;
  String status;

  Repo({required this.name, required this.status});

  factory Repo.fromJson(Map<String, dynamic> json) => _$RepoFromJson(json);
  Map<String, dynamic> toJson() => _$RepoToJson(this);
}
