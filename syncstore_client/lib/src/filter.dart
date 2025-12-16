import 'package:syncstore_client/src/models.dart' show SyncStatus, DataItem, ColorTag;

abstract interface class DataItemFilter<T> {
  bool apply(DataItem<T> item);
}

abstract class DataItemBodyFilter<T> implements DataItemFilter<T> {
  bool applyBody(T body);
  @override
  bool apply(DataItem<T> item) => applyBody(item.body);
}

class ParentIdFilter implements DataItemFilter {
  final String parentId;
  ParentIdFilter(this.parentId);

  @override
  bool apply(DataItem<dynamic> item) {
    return item.parentId == parentId;
  }
}

enum StatusFilter implements DataItemFilter {
  synced,
  all;

  @override
  bool apply(DataItem<dynamic> item) {
    switch (this) {
      case StatusFilter.synced:
        return item.syncStatus == SyncStatus.synced;
      case StatusFilter.all:
        return true;
    }
  }
}

enum ColorTagFilter implements DataItemFilter {
  // none,
  red,
  orange,
  yellow,
  green,
  blue,
  gray,
  all;

  @override
  bool apply(DataItem<dynamic> item) {
    switch (this) {
      case ColorTagFilter.red:
        return item.colorTag == ColorTag.red;
      case ColorTagFilter.orange:
        return item.colorTag == ColorTag.orange;
      case ColorTagFilter.yellow:
        return item.colorTag == ColorTag.yellow;
      case ColorTagFilter.green:
        return item.colorTag == ColorTag.green;
      case ColorTagFilter.blue:
        return item.colorTag == ColorTag.blue;
      case ColorTagFilter.gray:
        return item.colorTag == ColorTag.gray;
      case ColorTagFilter.all:
        return true;
    }
  }

  factory ColorTagFilter.fromColorTag(ColorTag tag) {
    switch (tag) {
      case ColorTag.red:
        return ColorTagFilter.red;
      case ColorTag.orange:
        return ColorTagFilter.orange;
      case ColorTag.yellow:
        return ColorTagFilter.yellow;
      case ColorTag.green:
        return ColorTagFilter.green;
      case ColorTag.blue:
        return ColorTagFilter.blue;
      case ColorTag.gray:
        return ColorTagFilter.gray;
      case ColorTag.none:
        return ColorTagFilter.all;
    }
  }
}

class OrFilter<T> implements DataItemFilter<T> {
  final Iterable<DataItemFilter<T>> filters;
  OrFilter(this.filters);

  @override
  bool apply(DataItem<T> item) {
    for (var filter in filters) {
      if (filter.apply(item)) {
        return true;
      }
    }
    return false;
  }
}
