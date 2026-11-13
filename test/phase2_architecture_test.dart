import 'package:flutter_test/flutter_test.dart';

import 'package:fima/domain/entity/file_system_item.dart';
import 'package:fima/domain/entity/panel_state.dart';
import 'package:fima/domain/utils/file_item_sorter.dart';
import 'package:fima/domain/utils/file_size_formatter.dart';
import 'package:fima/infrastructure/service/metadata/file_kind_descriptor.dart';
import 'package:fima/infrastructure/service/metadata/posix_permissions_service.dart';
import 'package:fima/presentation/widgets/popups/omni/omni_models.dart';

void main() {
  group('FileItemSorter', () {
    final baseTime = DateTime(2026, 1, 1);
    final parent = FileSystemItem(
      path: '/tmp',
      name: '..',
      size: 0,
      modified: baseTime,
      isDirectory: true,
      isParentDetails: true,
    );
    final dirA = FileSystemItem(
      path: '/tmp/alpha',
      name: 'alpha',
      size: 0,
      modified: baseTime,
      isDirectory: true,
    );
    final dirB = FileSystemItem(
      path: '/tmp/beta',
      name: 'beta',
      size: 0,
      modified: baseTime.add(const Duration(minutes: 1)),
      isDirectory: true,
    );
    final file1 = FileSystemItem(
      path: '/tmp/readme.md',
      name: 'readme.md',
      size: 200,
      modified: baseTime,
      isDirectory: false,
    );
    final file2 = FileSystemItem(
      path: '/tmp/archive.zip',
      name: 'archive.zip',
      size: 500,
      modified: baseTime.add(const Duration(minutes: 2)),
      isDirectory: false,
    );

    test('keeps parent item first and separates directories from files', () {
      final sorted = FileItemSorter.sortItems(
        [file1, dirB, parent, file2, dirA],
        SortColumn.name,
        true,
      );

      expect(
        sorted.map((e) => e.name).toList(),
        equals(['..', 'alpha', 'beta', 'archive.zip', 'readme.md']),
      );
    });

    test('sorts directories using computed directorySizes when available', () {
      final sorted = FileItemSorter.sortItems(
        [parent, dirA, dirB],
        SortColumn.size,
        false,
        directorySizes: {'/tmp/alpha': 1024, '/tmp/beta': 128},
      );

      expect(
        sorted.map((e) => e.name).toList(),
        equals(['..', 'alpha', 'beta']),
      );
    });

    test('filterByPrefix keeps parent and selects shortest prefix match', () {
      final (filtered, bestIndex) = FileItemSorter.filterByPrefix([
        parent,
        dirA,
        file2,
        file1,
      ], 'ar');

      expect(
        filtered.map((e) => e.name).toList(),
        equals(['..', 'archive.zip']),
      );
      expect(bestIndex, equals(1));
    });
  });

  group('FileSizeFormatter', () {
    test('formats bytes, KB, MB, and GB with expected precision', () {
      expect(FileSizeFormatter.format(-1), equals('N/A'));
      expect(FileSizeFormatter.format(512), equals('512 B'));
      expect(FileSizeFormatter.format(1300), equals('1.3 KB'));
      expect(
        FileSizeFormatter.formatWithExact(1300, exactFormatter: (v) => '1,300'),
        equals('1.3 KB (1,300 bytes)'),
      );
      expect(
        FileSizeFormatter.format(2 * 1024 * 1024, largeDecimals: 2),
        equals('2.00 MB'),
      );
    });
  });

  group('OmniModeSpec', () {
    test('parses prefix modes and query strings accurately', () {
      expect(OmniModeSpec.fromInput('w dev').mode, equals(OmniMode.workspace));
      expect(OmniModeSpec.fromInput('w Dev').query, equals('dev'));
      expect(OmniModeSpec.fromInput('b Docs').mode, equals(OmniMode.bookmark));
      expect(OmniModeSpec.fromInput('r Prod').mode, equals(OmniMode.remote));
      expect(OmniModeSpec.fromInput('>Copy').mode, equals(OmniMode.action));
      expect(OmniModeSpec.fromInput('>Copy').query, equals('copy'));
      expect(OmniModeSpec.fromInput('/Users').mode, equals(OmniMode.path));
    });
  });

  group('Metadata helpers', () {
    test('FileKindDescriptor describes local, remote, and zip entries', () {
      expect(
        FileKindDescriptor.describeKind('notes.md', isDirectory: false),
        equals('Markdown Document'),
      );
      expect(
        FileKindDescriptor.describeKind(
          'src',
          isDirectory: true,
          isInsideZip: true,
        ),
        equals('Folder (in ZIP Archive)'),
      );
      expect(
        FileKindDescriptor.describeKind(
          'data.custom',
          isDirectory: false,
          isRemote: true,
        ),
        equals('Remote CUSTOM File'),
      );
    });

    test('PosixPermissionsService formats permission bits cleanly', () {
      expect(
        PosixPermissionsService.formatFromBits(0x1ED),
        equals('rwxr-xr-x (0755)'),
      );
      expect(
        PosixPermissionsService.formatFromBits(0x1A4),
        equals('rw-r--r-- (0644)'),
      );
    });
  });
}
