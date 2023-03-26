import 'dart:io';

import 'package:resolve_win_shortcut/resolve_win_shortcut.dart';
import 'package:test/test.dart';

void main() {
  // Test Shell Link paths
  const asciiFile = 'test_file.lnk';
  const asciiDirectory = 'test_folder.lnk';
  const unicodeFile = 'test_unicode_file.lnk';
  const unicodeDirectory = 'test_unicode_folder.lnk';

  group('Shortcut Resolver Tests - Any Target', () {
    test('ASCII file path', () async {
      expect(ShortcutResolver.resolveTarget(await File(asciiFile).readAsBytes()), "C:\\test\\a.txt");
    });
    test('ASCII folder path', () async {
      expect(ShortcutResolver.resolveTarget(await File(asciiDirectory).readAsBytes()), "C:\\test");
    });
    test('Unicode file path', () async {
      expect(ShortcutResolver.resolveTarget(await File(unicodeFile).readAsBytes()), "C:\\test\\☆.txt");
    });
    test('Unicode folder path', () async {
      expect(ShortcutResolver.resolveTarget(await File(unicodeDirectory).readAsBytes()), "C:\\test\\☆");
    });
  });

  group('Shortcut Resolver - File Targets Only', () {
    test('ASCII file path', () {
      expect(
          () async => ShortcutResolver.resolveTarget(await File(asciiFile).readAsBytes(),
              targetType: FileSystemEntityType.file),
          throwsArgumentError);
    });
    test('ASCII folder path', () async {
      expect(
          ShortcutResolver.resolveTarget(await File(asciiDirectory).readAsBytes(),
              targetType: FileSystemEntityType.file),
          "C:\\test");
    });
    test('Unicode file path', () {
      expect(
          () async => ShortcutResolver.resolveTarget(await File(unicodeFile).readAsBytes(),
              targetType: FileSystemEntityType.file),
          throwsArgumentError);
    });
    test('Unicode folder path', () async {
      expect(
          ShortcutResolver.resolveTarget(await File(unicodeDirectory).readAsBytes(),
              targetType: FileSystemEntityType.file),
          "C:\\test\\☆");
    });
  });

  group('Shortcut Resolver - Directory Targets Only', () {
    test('ASCII file path', () async {
      expect(
          ShortcutResolver.resolveTarget(await File(asciiFile).readAsBytes(),
              targetType: FileSystemEntityType.directory),
          "C:\\test\\a.txt");
    });
    test('ASCII folder path', () {
      expect(
          () async => ShortcutResolver.resolveTarget(await File(asciiDirectory).readAsBytes(),
              targetType: FileSystemEntityType.directory),
          throwsArgumentError);
    });
    test('Unicode file path', () async {
      expect(
          ShortcutResolver.resolveTarget(await File(unicodeFile).readAsBytes(),
              targetType: FileSystemEntityType.directory),
          "C:\\test\\☆.txt");
    });
    test('Unicode folder path', () {
      expect(
          () async => ShortcutResolver.resolveTarget(await File(unicodeDirectory).readAsBytes(),
              targetType: FileSystemEntityType.directory),
          throwsArgumentError);
    });
  });
}
