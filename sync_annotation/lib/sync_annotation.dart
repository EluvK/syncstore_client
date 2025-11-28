library sync_annotation;

class Repository {
  final String collectionName;
  final String tableName;
  final Type db;

  const Repository({required this.collectionName, required this.tableName, required this.db});
}
