import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

/// Core models used by the client.
/// DataItem<T> is generic: T is the typed body that user will provide/parse.

@JsonSerializable(fieldRename: FieldRename.snake, genericArgumentFactories: true)
class DataItem<T> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String owner;
  final String? parentId;
  final String? unique;

  final T body;

  DataItem(this.id, this.createdAt, this.updatedAt, this.owner, this.parentId, this.unique, {required this.body});

  factory DataItem.fromJson(Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$DataItemFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) => _$DataItemToJson(this, toJsonT);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class PageInfo {
  final int count;
  final String? nextMarker;

  PageInfo({required this.count, this.nextMarker});

  factory PageInfo.fromJson(Map<String, dynamic> json) => _$PageInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PageInfoToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, genericArgumentFactories: true)
class ListResponse<T> {
  final List<DataItem<T>> items;
  final PageInfo pageInfo;

  ListResponse({required this.items, required this.pageInfo});

  factory ListResponse.fromJson(Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$ListResponseFromJson(json, fromJsonT);
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) => _$ListResponseToJson(this, toJsonT);
}
