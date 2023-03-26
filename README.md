This package lets you resolve target paths of Windows Shortcut (.lnk) files.

## Getting Started

Add `resolve_windows_shortcut` as a depenency to `pubspec.yaml`.

## Basic Usage

```dart
import 'package:resolve_windows_shortcut/resolve_windows_shortcut.dart';

final File shortcut = File('C:\\ShortcutPath.lnk');
final String resolvedShortcutPath = shortcut.resolveIfShortcut();
// OR
final String resolvedShortcutPath = resolveTartget(shortcut.readAsBytesSync());
```

## Sample Directory Extension Code

```dart
extension ResolvableDirectory on Directory {
  /// Determines if the directory contains any entities that
  /// point to directories or are directories themselves
  Future<bool> hasSubDirectory() async {
    await for (final entity in list(recursive: false)) {
      if (entity is Directory ||
          _getPathExtension(entity.path) == 'lnk' &&
              await (entity as File).resolveIfShortcut(targetType: FileSystemEntityType.directory) != null) {
        return true;
      }
    }
    return false;
  }

  /// Lists the contents of the directory with any functioning links resolved
  Stream<FileSystemEntity> listWithResolvedShortcuts(
      {FileSystemEntityType fsEntityType = FileSystemEntityType.any, bool recursive = false}) async* {
    await for (final FileSystemEntity entity in list()) {
      if (entity is File && _getPathExtension(entity.path) == 'lnk') {
        Directory resolvedDir =
            Directory((await Future<String?>(() => entity.resolveIfShortcut(targetType: fsEntityType)) ?? ''));
        if (resolvedDir.path.isEmpty || !resolvedDir.existsSync()) continue;
        if (recursive) {
          yield* resolvedDir.listWithResolvedShortcuts(fsEntityType: fsEntityType, recursive: recursive);
        }
        yield resolvedDir;
      } else if (entity is Directory && recursive) {
        yield* entity.listWithResolvedShortcuts(fsEntityType: fsEntityType, recursive: recursive);
      } else {
        yield entity;
      }
    }
  }

  /// Get the extension of the given file path if it exists
  String _getPathExtension(String path) => path.split(RegExp(r'[/\\]')).last.split('.').last;
}
```

## Additional information

_Tested on shortcuts made in Windows 10 21H2_

Comments in this package refer to Windows Shortcuts as Shell Links.
