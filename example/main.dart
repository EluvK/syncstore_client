import 'package:syncstore_client/syncstore_client.dart';

void main() async {
  final storage = InMemoryTokenStorage();
  final client = SyncStoreClient(baseUrl: 'http://localhost:1011/api', tokenStorage: storage);

  try {
    final res = await perform(() async {
      // logged in
      await client.login('test', 'password');
      print('login successful');
      final list = await client.list<Map<String, dynamic>>(
        'xbb',
        'repo',
        fromMap: (m) => m,
        limit: 10,
      );

      print('got ${list.items.length} repos, next marker: ${list.pageInfo.nextMarker}');

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
