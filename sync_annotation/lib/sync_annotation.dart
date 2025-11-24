library sync_annotation;

/// 标记一个 class 是可同步模型
class SyncModel {
  const SyncModel();
}

/// 云端字段
class RemoteField {
  const RemoteField();
}

/// 本地字段（不上传）
class LocalField {
  const LocalField();
}
