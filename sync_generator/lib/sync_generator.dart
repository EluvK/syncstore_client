import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:sync_annotation/sync_annotation.dart';

class SyncModelGenerator extends GeneratorForAnnotation<SyncModel> {
  @override
  String generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) return '';

    final clazz = element;
    final className = clazz.name;
    final fields = clazz.fields.where((f) => !f.isStatic);

    final localFields = fields.where(
      (f) => !f.metadata.annotations.any((m) => m.element?.enclosingElement?.name == 'SkipField'),
    );
    final remoteFields = localFields.where(
      (f) => !f.metadata.annotations.any((m) => m.element?.enclosingElement?.name == 'LocalField'),
    );

    final buffer = StringBuffer();
    buffer.writeln('// Generated code for $className');
    buffer.writeln('// local fields: ${localFields.map((f) => f.name).toList()}');
    buffer.writeln('// remote fields: ${remoteFields.map((f) => f.name).toList()}');

    // fromRemoteJson, toLocalJson, fromLocalJson, toRemoteJson,
    buffer.write('$className _\$${className}FromRemoteJson(Map<String, dynamic> json) => $className(');
    for (var f in remoteFields) {
      buffer.writeln("    ${f.name}: json['${f.name}'],");
    }
    buffer.writeln('  );');
    buffer.writeln("Map<String, dynamic> _\$${className}ToRemoteJson($className instance) => <String, dynamic>{");
    for (var f in remoteFields) {
      buffer.writeln("  '${f.name}': instance.${f.name},");
    }
    buffer.writeln('};');
    buffer.write('$className _\$${className}FromLocalJson(Map<String, dynamic> json) => $className(');
    for (var f in localFields) {
      buffer.writeln("    ${f.name}: json['${f.name}'],");
    }
    buffer.writeln('  );');
    buffer.writeln("Map<String, dynamic> _\$${className}ToLocalJson($className instance) => <String, dynamic>{");
    for (var f in localFields) {
      buffer.writeln("  '${f.name}': instance.${f.name},");
    }
    buffer.writeln('};');

    // buffer.writeln('extension ${className}SyncExt on $className {');

    // // toLocalJson
    // buffer.writeln('  Map<String, dynamic> toLocalJson() => {');
    // for (var f in localFields) {
    //   buffer.writeln("    '${f.name}': ${f.name},");
    // }
    // buffer.writeln('  };');
    // // fromLocalJson
    // buffer.writeln('  static $className fromLocalJson(Map<String, dynamic> json) => $className(');
    // for (var f in localFields) {
    //   buffer.writeln("    ${f.name}: json['${f.name}'],");
    // }
    // buffer.writeln('  );');

    // // toRemoteJson
    // buffer.writeln('  Map<String, dynamic> toRemoteJson() => {');
    // for (var f in remoteFields) {
    //   buffer.writeln("    '${f.name}': ${f.name},");
    // }
    // buffer.writeln('  };');
    // // fromRemoteJson
    // buffer.writeln('  static $className fromRemoteJson(Map<String, dynamic> json) => $className(');
    // for (var f in remoteFields) {
    //   buffer.writeln("    ${f.name}: json['${f.name}'],");
    // }
    // for (var f in localFields) {
    //   buffer.writeln("    ${f.name}: null,"); // 本地字段可用默认值
    // }
    // buffer.writeln('  );');

    // buffer.writeln('}');

    return buffer.toString();
  }
}

class RepositoryGenerator extends GeneratorForAnnotation<Repository> {
  @override
  generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) return '';

    final className = element.name; // Repo
    final tableName = annotation.read('tableName').stringValue;
    final dbType = annotation.read('db').typeValue.getDisplayString();

    final extName = 'LocalStore$className';

    return '''
extension $extName on $className {
  static String get tableName => '$tableName';

  static String get onCreateTable${className}SQL => 
      """
        CREATE TABLE \$tableName (
          id TEXT PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          owner TEXT NOT NULL,
          parent_id TEXT,
          "unique" TEXT,
          sync_status TEXT NOT NULL,
          body TEXT NOT NULL
        )
      """;

  static Future<Database> getDb() async {
    return await $dbType().getDb();
  }
}

typedef ${className}DataItem = DataItem<$className>;

class ${className}Repository {
  Future<void> addToLocalDb(${className}DataItem item) async {
    final db = await $extName.getDb();
    await db.insert(
      $extName.tableName, item.toJson((r) => json.encode(r.toJson())),
    );
  }

  Future<${className}DataItem?> getFromLocalDb(String id) async {
    final db = await $extName.getDb();
    final List<Map<String, dynamic>> maps = await db.query($extName.tableName, where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return DataItem<$className>.fromJson(maps.first, (jsonStr) => $className.fromJson(json.decode(jsonStr as String)));
    }
    return null;
  }

  Future<List<${className}DataItem>> listFromLocalDb({String? parentId}) async {
    final db = await $extName.getDb();
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    if (parentId != null) {
      whereClauses.add('parent_id = ?');
      whereArgs.add(parentId);
    }
    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final List<Map<String, dynamic>> maps = await db.query(
      $extName.tableName,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    return maps.map((map) => DataItem<$className>.fromJson(
      map, (jsonStr) => $className.fromJson(json.decode(jsonStr as String))))
      .toList();
  }

  Future<void> deleteFromLocalDb(String id) async {
    final db = await $extName.getDb();
    await db.delete($extName.tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateToLocalDb(${className}DataItem item) async {
    final db = await $extName.getDb();
    await db.update(
      $extName.tableName,
      item.toJson((r) => json.encode(r.toJson())),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> upsertToLocalDb(${className}DataItem item) async {
    if (await getFromLocalDb(item.id) == null) {
      await addToLocalDb(item);
    } else {
      await updateToLocalDb(item);
    }
  }
}
''';
  }
}

Builder syncModelBuilder(BuilderOptions options) =>
    SharedPartBuilder([SyncModelGenerator(), RepositoryGenerator()], 'syncstore');
