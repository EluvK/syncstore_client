/// Core models used by the client.
/// DataItem<T> is generic: T is the typed body that user will provide/parse.

class Meta {
  final String id;
  final String owner;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentId;
  final String? unique;

  Meta({
    required this.id,
    required this.owner,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.unique,
  });

  factory Meta.fromMap(Map<String, dynamic> m) {
    return Meta(
      id: m['id'] as String,
      owner: m['owner'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
      parentId: m['parent_id'] as String?,
      unique: m['unique'] as String?,
    );
  }
}

class DataItem<T> {
  final T body;
  final Meta meta;

  DataItem({required this.body, required this.meta});

  /// Provide a helper to parse when response shape is { "body": {...}, "meta": {...} }
  factory DataItem.fromMap(Map<String, dynamic> m, T Function(Map<String, dynamic>) fromMap) {
    final bodyRaw = m['body'] as Map<String, dynamic>;
    final metaRaw = m['meta'] as Map<String, dynamic>;
    return DataItem(body: fromMap(bodyRaw), meta: Meta.fromMap(metaRaw));
  }
}

class PageInfo {
  final int count;
  final String? nextMarker;

  PageInfo({required this.count, this.nextMarker});

  factory PageInfo.fromMap(Map<String, dynamic> m) {
    return PageInfo(
      count: m['count'] as int? ?? 0,
      nextMarker: m['next_marker'] as String?,
    );
  }
}

class ListResponse<T> {
  final List<T> items;
  final PageInfo pageInfo;

  ListResponse({required this.items, required this.pageInfo});

  factory ListResponse.fromMap(Map<String, dynamic> m, T Function(Map<String, dynamic>) fromMap) {
    final itemsRaw = m['items'] as List<dynamic>;
    final items = itemsRaw.map((e) => fromMap(e as Map<String, dynamic>)).toList();
    final pageInfo = PageInfo.fromMap(m['page_info'] as Map<String, dynamic>);
    return ListResponse(items: items, pageInfo: pageInfo);
  }
}
