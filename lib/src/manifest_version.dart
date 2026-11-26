import 'package:yaml/yaml.dart';

/// The numeric version scalar in a pubspec and its offset in the source.
class ManifestVersion {
  const ManifestVersion._(this.value, this._start);

  static final _numeric = RegExp(r'^\d+\.\d+\.\d+(?:\+\d+)?$');
  static bool isSupported(String value) => _numeric.hasMatch(value);

  final String value;
  final int _start;

  static ManifestVersion? parse(String source) {
    try {
      final root = loadYamlNode(source);
      final node = root is YamlMap ? root.nodes['version'] : null;
      if (node is! YamlScalar || node.value is! String) return null;
      final value = node.value as String;
      if (!isSupported(value)) return null;

      // An alias can point at another field. Only edit a literal scalar.
      final span = node.span;
      if (span.text == value) {
        return ManifestVersion._(value, span.start.offset);
      }
      if (span.text == "'$value'" || span.text == '"$value"') {
        return ManifestVersion._(value, span.start.offset + 1);
      }
      return null;
    } on YamlException {
      return null;
    }
  }

  String replaceIn(String source, String replacement) =>
      source.replaceRange(_start, _start + value.length, replacement);
}
