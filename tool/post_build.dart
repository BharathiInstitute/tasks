// tool/post_build.dart
import 'dart:convert';
import 'dart:io';

void main() async {
  final buildDir = Directory('build/web');
  if (!await buildDir.exists()) {
    stderr.writeln('build/web not found. Run flutter build web first.');
    exit(1);
  }

  final buildId = DateTime.now().toUtc().toIso8601String();
  // 1) Write version.json (useful for diagnostics or future update prompts)
  final versionFile = File('${buildDir.path}/version.json');
  await versionFile.writeAsString(jsonEncode({"version": buildId}));

  // 2) Add ?v=<buildId> to flutter_bootstrap.js in index.html (cache-bust)
  final indexFile = File('${buildDir.path}/index.html');
  var html = await indexFile.readAsString();

  // Replace only if not already versioned
  if (!html.contains('flutter_bootstrap.js?v=')) {
    html = html.replaceFirst(
      'flutter_bootstrap.js',
      'flutter_bootstrap.js?v=$buildId',
    );
    await indexFile.writeAsString(html);
    stdout.writeln('Added cache-busting query (?v=$buildId) to flutter_bootstrap.js');
  } else {
    stdout.writeln('index.html already has a versioned flutter_bootstrap.js');
  }
}
