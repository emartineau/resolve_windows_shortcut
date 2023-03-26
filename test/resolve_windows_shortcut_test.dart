import 'dart:io';

import 'package:resolve_windows_shortcut/resolve_windows_shortcut.dart';
import 'package:test/test.dart';

class ShortcutTestData {
  final String testTitle;
  final String shortcutPath;
  final String targetPath;
  final ShortcutResolverEntityType targetType;
  const ShortcutTestData(this.testTitle, this.shortcutPath, this.targetPath, this.targetType);
}

void main() {
  // Test Shortcut data
  const ShortcutTestData asciiFile =
      ShortcutTestData('ASCII file path', 'test_file.lnk', 'C:\\test\\a.txt', ShortcutResolverEntityType.file);
  const ShortcutTestData asciiDirectory =
      ShortcutTestData('ASCII folder path', 'test_folder.lnk', 'C:\\test', ShortcutResolverEntityType.directory);
  const ShortcutTestData unicodeFile = ShortcutTestData(
      'Unicode file path', 'test_unicode_file.lnk', 'C:\\test\\☆.txt', ShortcutResolverEntityType.file);
  const ShortcutTestData unicodeDirectory = ShortcutTestData(
      'Unicode folder path', 'test_unicode_folder.lnk', 'C:\\test\\☆', ShortcutResolverEntityType.directory);

  const Iterable<ShortcutTestData> allShortcuts = [asciiFile, asciiDirectory, unicodeFile, unicodeDirectory];
  final Iterable<ShortcutTestData> fileShortcuts =
      allShortcuts.where((element) => element.targetType == ShortcutResolverEntityType.file);
  final Iterable<ShortcutTestData> folderShortcuts =
      allShortcuts.where((element) => element.targetType == ShortcutResolverEntityType.directory);

  group('Shortcut Resolver Tests - Any Target', () {
    // Success Cases
    for (ShortcutTestData shortcut in allShortcuts) {
      test(shortcut.testTitle, () async {
        expect(ShortcutResolver.resolveTarget(await File(shortcut.shortcutPath).readAsBytes()), shortcut.targetPath);
      });
    }
  });

  group('Shortcut Resolver - File Targets Only', () {
    // Success Cases
    for (ShortcutTestData shortcut in fileShortcuts) {
      test(shortcut.testTitle, () async {
        expect(
            ShortcutResolver.resolveTarget(await File(shortcut.shortcutPath).readAsBytes(),
                targetType: ShortcutResolverEntityType.file),
            shortcut.targetPath);
      });
    }
    // Failure Cases
    for (ShortcutTestData shortcut in folderShortcuts) {
      test(shortcut.testTitle, () async {
        expect(
            () async => ShortcutResolver.resolveTarget(await File(shortcut.shortcutPath).readAsBytes(),
                targetType: ShortcutResolverEntityType.file),
            throwsArgumentError);
      });
    }
  });

  group('Shortcut Resolver - Directory Targets Only', () {
    // Success Cases
    for (ShortcutTestData shortcut in folderShortcuts) {
      test(shortcut.testTitle, () async {
        expect(
            ShortcutResolver.resolveTarget(await File(shortcut.shortcutPath).readAsBytes(),
                targetType: ShortcutResolverEntityType.directory),
            shortcut.targetPath);
      });
    }
    // Failure Cases
    for (ShortcutTestData shortcut in fileShortcuts) {
      test(shortcut.testTitle, () async {
        expect(
            () async => ShortcutResolver.resolveTarget(await File(shortcut.shortcutPath).readAsBytes(),
                targetType: ShortcutResolverEntityType.directory),
            throwsArgumentError);
      });
    }
  });
}
