/// Contains functions and extensions that parse MS Shell Link (Windows Shorcut) files
///
/// Implemented based on [the open spec of Shell Links.](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-shllink/16cb4ca1-9339-4d0c-a68d-bf1d6cc0f943)
library resolve_windows_shortcut;

import 'dart:io';
import 'dart:typed_data';

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

/// A file system entity type that can be resolved from a Shell Link.
enum ShortcutResolverEntityType { file, directory, any }

class ShortcutResolver {
  /// Resolves the target path linked by the Shell Link (Windows Shortcut) file.
  /// The [targetType] argument restricts what types of paths can be resolved.
  ///
  /// Throws an [ArgumentError] on failure.
  static String resolveTarget(Uint8List bytes,
      {ShortcutResolverEntityType targetType = ShortcutResolverEntityType.any}) {
    // Shortcuts should be at least this long
    if (bytes.lengthInBytes < 0xff) throw ArgumentError('More data needed to attempt path resolution');

    // Check if bytes 4-20 match the GUID (UUID) of MS Shell Link files
    if (!_listEquals(Uint8List.sublistView(bytes, 0x04, 0x14), shellLinkGuidHexList)) {
      throw ArgumentError('Data is not in Shell Link format');
    }

    // Flags
    final int shellLinkFlags = bytes[0x14];
    const int fileAttributesOffset = 0x18;

    // Attributes
    final int fileAttributes = bytes[fileAttributesOffset];
    const int hasWorkingDirFlag = 0x10; // E
    final bool linksToFile = fileAttributes & hasWorkingDirFlag < 1;

    // Do not attempt to resolve if the link points to the wrong entity type
    if ((targetType == ShortcutResolverEntityType.directory && linksToFile) ||
        (targetType == ShortcutResolverEntityType.file && !linksToFile)) {
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
    return _parseLnkTarget(bytes, fileStart, isUnicode: isUnicodeTarget);
  }
}

extension ResolvableFile on File {
  /// Resolves the target path linked by the Shell Link (Windows Shortcut) file
  /// [targetType] will only resolve if the path points to the given type
  ///
  /// Throws an [ArgumentError] on failure.
  Future<String> resolveIfShortcut({ShortcutResolverEntityType targetType = ShortcutResolverEntityType.any}) async =>
      ShortcutResolver.resolveTarget(await readAsBytes(), targetType: targetType);

  /// Resolves the target path linked by the Shell Link (Windows Shortcut) file
  /// [targetType] will only resolve if the path points to the given type
  ///
  /// Throws an [ArgumentError] on failure.
  String resolveIfShortcutSync({ShortcutResolverEntityType targetType = ShortcutResolverEntityType.any}) =>
      ShortcutResolver.resolveTarget(readAsBytesSync(), targetType: targetType);
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

/// Compares 2 lists for equality in elements (via ==) and order
bool _listEquals(List a, List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; ++i) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
