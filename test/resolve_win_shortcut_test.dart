import 'dart:io';

import 'package:resolve_win_shortcut/resolve_win_shortcut.dart';
import 'package:test/test.dart';

void main() {
  group('Shortcut Resolver Tests', () {
    test('ASCII file path', () async {
      assert(await ShortcutResolver.resolve(await File('test_file.lnk').readAsBytes()) == "C:\\test\\a.txt");
    });
    test('ASCII folder path', () async {
      assert(await ShortcutResolver.resolve(await File('test_folder.lnk').readAsBytes()) == "C:\\test");
    });
    test('Unicode file path', () async {
      assert(await ShortcutResolver.resolve(await File('test_unicode_file.lnk').readAsBytes()) == "C:\\test\\☆.txt");
    });
    test('Unicode folder path', () async {
      assert(await ShortcutResolver.resolve(await File('test_unicode_folder.lnk').readAsBytes()) == "C:\\test\\☆");
    });
  });
}
