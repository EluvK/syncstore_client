import 'package:dio/dio.dart';
import 'package:syncstore_client/syncstore_client.dart';

void main() async {
  final storage = InMemoryTokenStorage();
  final client = SyncStoreClient(baseUrl: 'http://localhost:7878/api', tokenStorage: storage);

  try {
    // login
    await client.login('alice', 'password');

    // list repos, here we treat each item as raw Map
    final list = await client.list<Map<String, dynamic>>(
      'xbb',
      'repo',
      fromMap: (m) => m,
      limit: 10,
    );
    print('got ${list.items.length} repos, next marker: ${list.pageInfo.nextMarker}');

    // create a repo
    final created = await client.create<Map<String, dynamic>>(
      'xbb',
      'repo',
      {'name': 'client-demo', 'status': 'normal'},
      (m) => m,
    );
    print('created: $created');
  } catch (e) {
    print('Error: $e');
  }
}
