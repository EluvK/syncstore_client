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

enum SyncStatus { synced, pending, failed }

@JsonSerializable(fieldRename: FieldRename.snake, genericArgumentFactories: true)
class DataItem<T> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String owner;
  final String? parentId;
  final String? unique;

  // this field is client-side only, but since nothings happened even we do send it to server
  // it's ok to keep it here to make this usage easier, less type gymnastics.
  final SyncStatus syncStatus;

  final T body;

  DataItem(
    this.id,
    this.createdAt,
    this.updatedAt,
    this.owner,
    this.parentId,
    this.unique, {
    required this.body,
    // the default is synced, as we usually fetch data from server, which is definitely ''synced''
    this.syncStatus = SyncStatus.synced,
  });

  // ? what's the design philosophy here?
  DataItem<T> updatedBody(T newBody) {
    return DataItem<T>(
      id,
      createdAt,
      DateTime.now().toUtc(),
      owner,
      parentId,
      unique,
      body: newBody,
      // todo
      syncStatus: SyncStatus.pending,
    );
  }

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
