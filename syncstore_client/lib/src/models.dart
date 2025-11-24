import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

// --- UserProfile ---

@JsonSerializable(fieldRename: FieldRename.snake)
class UserProfile {
  final String userId;
  final String name;
  final String? avatarUrl;

  UserProfile({required this.userId, required this.name, this.avatarUrl});
  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class UpdateUserProfileRequest {
  final String? name;
  final String? password;
  final String? avatarUrl;

  UpdateUserProfileRequest({this.name, this.password, this.avatarUrl});
  factory UpdateUserProfileRequest.fromJson(Map<String, dynamic> json) => _$UpdateUserProfileRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateUserProfileRequestToJson(this);
}

// --- Data Models ---

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
