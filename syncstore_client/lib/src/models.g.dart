// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  userId: json['user_id'] as String,
  name: json['name'] as String,
  avatarUrl: json['avatar_url'] as String?,
);

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) => <String, dynamic>{
  'user_id': instance.userId,
  'name': instance.name,
  'avatar_url': instance.avatarUrl,
};

UpdateUserProfileRequest _$UpdateUserProfileRequestFromJson(Map<String, dynamic> json) => UpdateUserProfileRequest(
  name: json['name'] as String?,
  password: json['password'] as String?,
  avatarUrl: json['avatar_url'] as String?,
);

Map<String, dynamic> _$UpdateUserProfileRequestToJson(UpdateUserProfileRequest instance) => <String, dynamic>{
  'name': instance.name,
  'password': instance.password,
  'avatar_url': instance.avatarUrl,
};

DataItem<T> _$DataItemFromJson<T>(Map<String, dynamic> json, T Function(Object? json) fromJsonT) => DataItem<T>(
  json['id'] as String,
  DateTime.parse(json['created_at'] as String),
  DateTime.parse(json['updated_at'] as String),
  json['owner'] as String,
  json['parent_id'] as String?,
  json['unique'] as String?,
  body: fromJsonT(json['body']),
  syncStatus: $enumDecodeNullable(_$SyncStatusEnumMap, json['sync_status']) ?? SyncStatus.synced,
);

Map<String, dynamic> _$DataItemToJson<T>(DataItem<T> instance, Object? Function(T value) toJsonT) => <String, dynamic>{
  'id': instance.id,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'owner': instance.owner,
  'parent_id': instance.parentId,
  'unique': instance.unique,
  'sync_status': _$SyncStatusEnumMap[instance.syncStatus]!,
  'body': toJsonT(instance.body),
};

const _$SyncStatusEnumMap = {SyncStatus.synced: 'synced', SyncStatus.pending: 'pending', SyncStatus.failed: 'failed'};

PageInfo _$PageInfoFromJson(Map<String, dynamic> json) =>
    PageInfo(count: (json['count'] as num).toInt(), nextMarker: json['next_marker'] as String?);

Map<String, dynamic> _$PageInfoToJson(PageInfo instance) => <String, dynamic>{
  'count': instance.count,
  'next_marker': instance.nextMarker,
};

ListResponse<T> _$ListResponseFromJson<T>(Map<String, dynamic> json, T Function(Object? json) fromJsonT) =>
    ListResponse<T>(
      items: (json['items'] as List<dynamic>)
          .map((e) => DataItem<T>.fromJson(e as Map<String, dynamic>, (value) => fromJsonT(value)))
          .toList(),
      pageInfo: PageInfo.fromJson(json['page_info'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ListResponseToJson<T>(ListResponse<T> instance, Object? Function(T value) toJsonT) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson((value) => toJsonT(value))).toList(),
      'page_info': instance.pageInfo,
    };
