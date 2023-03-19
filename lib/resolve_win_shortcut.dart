/// Contains functions and extensions that parse MS Shell Link (Windows Shorcut) files
///
/// Implemented based on [the open spec of Shell Links.](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-shllink/16cb4ca1-9339-4d0c-a68d-bf1d6cc0f943)
library resolve_win_shortcut;

export 'src/resolve_win_shortcut_base.dart';

import 'dart:io';
import 'dart:typed_data';

extension DirectoryHelpers on Directory {
  /// Determines if the directory contains any entities that
  /// point to directories or are directories themselves
  Future<bool> hasSubDirectory() async {
    await for (final entity in list(recursive: false)) {
      if (entity is Directory ||
          _getPathExtension(entity.path) == '.lnk' &&
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
}

/// Unique Identifier for Shell Link files in byte array form
const shellLinkGuidHexList = [
  0x01,
  0x14,
  0x02,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0xc0,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x46
];

enum FileSystemEntityType { file, directory, any }

class ShortcutResolver {
  /// Resolves the target path linked by the Shell Link (Windows Shortcut) file
  /// [targetType] will only resolve if the path points to the given type
  ///
  /// Throws an [ArgumentError] on failure
  static Future<String?> resolveTarget(Uint8List bytes,
      {FileSystemEntityType targetType = FileSystemEntityType.any}) async {
    // Shortcuts should be at least this long
    if (bytes.lengthInBytes < 0xff) throw ArgumentError('More data needed to attempt path resolution');

    // Check if bytes 4-20 match the GUID (UUID) of MS Shell Link files
    if (!_listEquals(Uint8List.sublistView(bytes, 0x04, 0x14), shellLinkGuidHexList)) {
      throw ArgumentError('Data is not in Shell Link format');
    }

    // Flags
    final int shellLinkFlags = bytes[0x14];
    const int fileAttributesOffset = 0x18;
    const int hasLocationInfoFlag = 0x02; // B

    // Attributes
    final int fileAttributes = bytes[fileAttributesOffset];
    const int hasWorkingDirFlag = 0x10; // E
    final bool linksToDir = fileAttributes & hasWorkingDirFlag < 1;

    // Do not attempt to resolve if the link points to the wrong entity type
    if ((targetType == FileSystemEntityType.directory && !linksToDir) ||
        (targetType == FileSystemEntityType.file && linksToDir)) {
      throw ArgumentError.value('Link points to invalid shortcut type. Expected: ${targetType.name}');
    }

    const int shellOffset = 0x4c; // 76, length of the Shell Link header
    const int hasShellFlag = 0x01; // A
    const int isUnicodeFlag = 0x80; // H

    int shellLength = 0;
    if ((shellLinkFlags & hasShellFlag) > 0) {
      // Converts 2 bytes into a short, little endian
      shellLength = ((bytes[shellOffset + 1] << 8) | (bytes[shellOffset])) + 2;
    }

    final int fileStart = shellOffset + shellLength;
    final bool isUnicodeTarget = (shellLinkFlags & isUnicodeFlag) > 0 &&
        ByteData.sublistView(bytes).getUint32(fileStart + 0x04, Endian.little) > 28;
    // final bool hasLocationInfo = flags & hasLocationInfoFlag > 0;
    // get the local volume and local system values
    // const int basenameOffsetOffset = 0x10;
    // const int finalnameOffsetOffset = 0x18;
    // final int basenameOffset = rawContent[fileStart + basenameOffsetOffset] + fileStart;
    // final int finalnameOffset = rawContent[fileStart + finalnameOffsetOffset] + fileStart;
    return _parseLnkTarget(bytes, fileStart, isUnicode: isUnicodeTarget);
  }
}

extension FileHelpers on File {
  Future<String?> resolveIfShortcut({FileSystemEntityType targetType = FileSystemEntityType.any}) async =>
      ShortcutResolver.resolveTarget(await readAsBytes(), targetType: targetType);
}

/// Parses the target the list of bytes beginning at the given offset.
/// For proper parsing, [isUnicode] must be true if and only if the target is in Unicode
String _parseLnkTarget(Uint8List bytes, int offset, {bool isUnicode = false}) {
  if (!isUnicode) {
    // Characters are in ASCII and thus only 8 bits wide
    return _getNullTerminatedString(bytes, bytes[offset + 0x10] + offset) +
        _getNullTerminatedString(bytes, bytes[offset + 0x18] + offset);
  }

  final Uint8List fromOffset = bytes.sublist(offset);
  final byteView = ByteData.view(fromOffset.buffer);
  // final int stringLength = byteView.getUint32(offset + 0x00, Endian.little);
  // final int locationFlagsOffset = byteView.getUint32(offset + 0x08, Endian.little);
  // final int volumeInfoOffset = byteView.getUint32(offset + 0x0c, Endian.little);
  final int localPathOffset = byteView.getUint32(0x1c, Endian.little);
  final int remainingPathOffset = byteView.getUint32(0x20, Endian.little);

  int length = 0;
  String as16LocalPath = '';
  String as16RemainingPath = '';
  final as16Local = fromOffset.sublist(localPathOffset).buffer.asUint16List();
  final as16Remaining = fromOffset.sublist(remainingPathOffset).buffer.asUint16List();
  for (final char in as16Local) {
    if (char == 0) {
      as16LocalPath = String.fromCharCodes(as16Local, 0, length);
      break;
    }
    length++;
  }
  length = 0;
  for (final char in as16Remaining) {
    if (char == 0) {
      as16RemainingPath = String.fromCharCodes(as16Remaining, 0, length);
      break;
    }
    length++;
  }

  return as16LocalPath + as16RemainingPath;
}

/// Returns a UTF-16 string using character codes found in [bytes]
/// starting from [offset] and ending at the first null character code.
///
/// The input characters are expected to be 1-byte wide.
String _getNullTerminatedString(Uint8List bytes, int offset) {
  int length = 0;
  // Count bytes until the null character (0)
  while (true) {
    if (bytes[offset + length] == 0) {
      return String.fromCharCodes(bytes, offset, offset + length);
    }
    length++;
  }
}

/// Get the extension of the given file path if it exists
String _getPathExtension(String path) => path.split(RegExp(r'[/\\]')).last.split('.').last;

/// Compares 2 lists for equality in elements (via ==) and order
bool _listEquals(List a, List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; ++i) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
