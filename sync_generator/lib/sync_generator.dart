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
      (f) => f.metadata.annotations.any((m) => m.element?.enclosingElement?.name == 'LocalField'),
    );
    final remoteFields = fields.where(
      (f) => f.metadata.annotations.any((m) => m.element?.enclosingElement?.name == 'RemoteField'),
    );

    final buffer = StringBuffer();
    buffer.writeln('extension ${className}SyncExt on $className {');

    // toLocalJson
    buffer.writeln('  Map<String, dynamic> toLocalJson() => {');
    for (var f in fields) {
      buffer.writeln("    '${f.name}': ${f.name},");
    }
    buffer.writeln('  };');

    // toRemoteJson
    buffer.writeln('  Map<String, dynamic> toRemoteJson() => {');
    for (var f in remoteFields) {
      buffer.writeln("    '${f.name}': ${f.name},");
    }
    buffer.writeln('  };');

    // fromLocalJson
    buffer.writeln('  static $className fromLocalJson(Map<String, dynamic> json) => $className(');
    for (var f in fields) {
      buffer.writeln("    ${f.name}: json['${f.name}'],");
    }
    buffer.writeln('  );');

    // fromRemoteJson
    buffer.writeln('  static $className fromRemoteJson(Map<String, dynamic> json) => $className(');
    for (var f in remoteFields) {
      buffer.writeln("    ${f.name}: json['${f.name}'],");
    }
    for (var f in localFields) {
      buffer.writeln("    ${f.name}: null,"); // 本地字段可用默认值
    }
    buffer.writeln('  );');

    buffer.writeln('}');

    return buffer.toString();
  }
}

Builder syncModelBuilder(BuilderOptions options) => SharedPartBuilder([SyncModelGenerator()], 'sync_generator');
