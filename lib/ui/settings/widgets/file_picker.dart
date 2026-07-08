import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/i18n.dart';

class FilePickerDialog extends StatefulWidget {
  const FilePickerDialog({
    super.key,
    required this.pickerKind,
    required this.initialPath,
    required this.onSelect,
    required this.onClose,
  });

  final String pickerKind; // 'model' | 'labels' | 'image'
  final String initialPath;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  State<FilePickerDialog> createState() => _FilePickerDialogState();
}

class _FilePickerDialogState extends State<FilePickerDialog> {
  late String currentPath;
  List<FileSystemEntity> entries = [];
  String error = '';
  bool isLoading = false;

  late bool isGridView;
  String sortBy = 'name'; // 'name' | 'size' | 'date'

  @override
  void initState() {
    super.initState();
    isGridView = widget.pickerKind == 'image';
    _initPath();
  }

  void _initPath() {
    String path = widget.initialPath.trim();
    if (path.isEmpty) {
      path = Platform.environment['HOME'] ?? '/';
    } else {
      // If it's a file, get its parent directory
      final file = File(path);
      if (file.existsSync()) {
        path = file.parent.path;
      } else {
        final dir = Directory(path);
        if (!dir.existsSync()) {
          path = Platform.environment['HOME'] ?? '/';
        }
      }
    }
    currentPath = path;
    _loadPath(currentPath);
  }

  void _loadPath(String path) {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        throw FileSystemException("Directory does not exist", path);
      }

      final List<FileSystemEntity> all = dir.listSync();
      final Set<String> allowedSuffixes = _getAllowedSuffixes();

      final List<Directory> dirs = [];
      final List<File> files = [];

      for (final entity in all) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) continue;

        if (entity is Directory) {
          dirs.add(entity);
        } else if (entity is File) {
          final ext = '.${name.split('.').last.toLowerCase()}';
          if (allowedSuffixes.contains(ext)) {
            files.add(entity);
          }
        }
      }

      // Sorting Logic
      int compareEntities(FileSystemEntity a, FileSystemEntity b) {
        if (sortBy == 'size') {
          int sizeA = 0;
          int sizeB = 0;
          if (a is File) {
            try {
              sizeA = a.lengthSync();
            } catch (_) {}
          }
          if (b is File) {
            try {
              sizeB = b.lengthSync();
            } catch (_) {}
          }
          return sizeB.compareTo(sizeA); // descending
        } else if (sortBy == 'date') {
          DateTime dateA = DateTime(1970);
          DateTime dateB = DateTime(1970);
          try {
            dateA = a.statSync().modified;
          } catch (_) {}
          try {
            dateB = b.statSync().modified;
          } catch (_) {}
          return dateB.compareTo(dateA); // newest first (descending)
        } else {
          final nameA = a.path.split(Platform.pathSeparator).last.toLowerCase();
          final nameB = b.path.split(Platform.pathSeparator).last.toLowerCase();
          return nameA.compareTo(nameB); // ascending (A-Z)
        }
      }

      dirs.sort(compareEntities);
      files.sort(compareEntities);

      setState(() {
        currentPath = path;
        entries = [...dirs, ...files];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Set<String> _getAllowedSuffixes() {
    return switch (widget.pickerKind) {
      'model' => {'.onnx', '.hef'},
      'labels' => {'.txt', '.json', '.yaml', '.yml', '.names'},
      'image' => {'.png', '.jpg', '.jpeg', '.svg', '.webp', '.gif'},
      _ => {'.onnx', '.hef', '.txt', '.json'},
    };
  }

  List<Map<String, String>> _getShortcuts() {
    final List<Map<String, String>> shortcuts = [];

    // Bundled model root
    final bundledPath = '${Directory.current.path}/service/models';
    if (Directory(bundledPath).existsSync()) {
      shortcuts.add({'label': 'Bundled Models', 'path': bundledPath});
    }

    // Project root
    shortcuts.add({'label': 'Project', 'path': Directory.current.path});

    // Home root
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      shortcuts.add({'label': 'Home', 'path': home});

      final downloads = '$home/Downloads';
      if (Directory(downloads).existsSync()) {
        shortcuts.add({'label': 'Downloads', 'path': downloads});
      }
    }

    // Scan USBs
    final List<String> usbBases = [];
    if (Platform.isMacOS) {
      usbBases.add('/Volumes');
    } else if (Platform.isLinux) {
      usbBases.addAll(['/media', '/mnt', '/run/media']);
    }

    for (final base in usbBases) {
      final dir = Directory(base);
      if (dir.existsSync()) {
        try {
          for (final entity in dir.listSync()) {
            if (entity is Directory) {
              final name = entity.path.split(Platform.pathSeparator).last;
              if (name.startsWith('.')) continue;
              // Avoid system volumes on macOS
              if (Platform.isMacOS && name == 'Macintosh HD') continue;
              shortcuts.add({'label': 'Drive: $name', 'path': entity.path});
            }
          }
        } catch (_) {}
      }
    }

    return shortcuts;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  void _handleEntryClick(FileSystemEntity entry) async {
    if (entry is Directory) {
      _loadPath(entry.path);
    } else if (entry is File) {
      final path = entry.path;
      final fileName = path.split(Platform.pathSeparator).last;

      if (_isExternalPath(path)) {
        final choice = await _showImportConfirmDialog(context, fileName);
        if (choice == null) {
          // Cancelled
          return;
        }

        if (choice == 'copy') {
          if (!mounted) return;
          _showCopyingLoader(context);

          try {
            final localPath = await _copyFileToLocal(path, widget.pickerKind);
            if (mounted) {
              Navigator.of(context).pop(); // Close copying loader
              widget.onSelect(localPath);
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pop(); // Close copying loader
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    I18n.t(
                      context,
                      'failed_copy_file',
                      args: {'error': e.toString()},
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        } else {
          // Direct
          widget.onSelect(path);
        }
      } else {
        // Local file
        widget.onSelect(path);
      }
    }
  }

  bool _isExternalPath(String path) {
    if (Platform.isMacOS) {
      return path.startsWith('/Volumes/');
    } else if (Platform.isLinux) {
      return path.startsWith('/media/') ||
          path.startsWith('/mnt/') ||
          path.startsWith('/run/media/');
    }
    return false;
  }

  String _getApplicationSupportDirectory() {
    final home = Platform.environment['HOME'] ?? '.';
    if (Platform.isMacOS) {
      return '$home/Library/Application Support/beenut';
    } else if (Platform.isLinux) {
      final xdgConfig = Platform.environment['XDG_CONFIG_HOME'];
      if (xdgConfig != null && xdgConfig.isNotEmpty) {
        return '$xdgConfig/beenut';
      }
      return '$home/.config/beenut';
    } else {
      return '$home/.beenut';
    }
  }

  Future<String> _copyFileToLocal(String sourcePath, String kind) async {
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) return sourcePath;

    final appSupport = _getApplicationSupportDirectory();
    final targetDir = Directory('$appSupport/custom_assets/$kind');
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final fileName = sourcePath.split(Platform.pathSeparator).last;
    final targetPath = '${targetDir.path}/$fileName';

    // Copy file
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  Future<String?> _showImportConfirmDialog(
    BuildContext context,
    String fileName,
  ) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.usb, color: scheme.primary, size: 24),
              SizedBox(width: 10),
              Text(
                I18n.t(context, 'external_storage_detected'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                  fontFamily: BeenutTheme.fontFamily,
                  fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                I18n.t(context, 'file_label', args: {'name': fileName}),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                  fontFamily: BeenutTheme.fontFamily,
                  fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                I18n.t(context, 'copy_to_kiosk_prompt'),
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                  fontFamily: BeenutTheme.fontFamily,
                  fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                I18n.t(context, 'cancel'),
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  fontFamily: BeenutTheme.fontFamily,
                  fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop('direct'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: scheme.outline),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Text(
                I18n.t(context, 'use_directly_from_usb'),
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface,
                  fontFamily: BeenutTheme.fontFamily,
                  fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('copy'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Text(
                I18n.t(context, 'copy_to_kiosk_btn'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: BeenutTheme.fontFamily,
                  fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCopyingLoader(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 3),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  I18n.t(context, 'copying_file_progress'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                    fontFamily: BeenutTheme.fontFamily,
                    fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = switch (widget.pickerKind) {
      'model' => 'Select Model File',
      'labels' => 'Select Class Labels',
      'image' => 'Select Image File',
      _ => 'Select File',
    };

    final pathParts = currentPath
        .split(Platform.pathSeparator)
        .where((s) => s.isNotEmpty)
        .toList();
    final shortcuts = _getShortcuts();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.of(context).size.height - 64).clamp(
              200.0,
              520.0,
            ),
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: Icon(Icons.close, size: 18),
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(28, 28),
                        side: BorderSide(color: scheme.outlineVariant),
                        backgroundColor: scheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),

              // Breadcrumbs
              Container(
                height: 36,
                color: scheme.surfaceContainer,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.computer,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      onPressed: () => _loadPath('/'),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: 24,
                        height: 24,
                      ),
                    ),
                    const VerticalDivider(width: 10, indent: 8, endIndent: 8),
                    TextButton(
                      onPressed: () => _loadPath('/'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                      child: Text(
                        'root',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    for (int i = 0; i < pathParts.length; i++) ...[
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      TextButton(
                        onPressed: i == pathParts.length - 1
                            ? null
                            : () {
                                final p =
                                    '/${pathParts.sublist(0, i + 1).join(Platform.pathSeparator)}';
                                _loadPath(p);
                              },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: i == pathParts.length - 1
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                        child: Text(
                          pathParts[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: i == pathParts.length - 1
                                ? FontWeight.w700
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),

              // Shortcuts
              if (shortcuts.isNotEmpty) ...[
                Container(
                  height: 36,
                  color: scheme.surfaceContainerLow,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: shortcuts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final item = shortcuts[index];
                      return OutlinedButton(
                        onPressed: () => _loadPath(item['path']!),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          side: BorderSide(color: scheme.outlineVariant),
                          backgroundColor: scheme.surfaceContainerLowest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          item['label']!,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
              ],

              // Toolbar: View toggle & Sort dropdown
              Container(
                height: 36,
                color: scheme.surfaceContainerLow,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sort options
                    Row(
                      children: [
                        Text(
                          I18n.t(context, 'sort_by'),
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        DropdownButton<String>(
                          value: sortBy,
                          underline: const SizedBox(),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                            fontFamily: BeenutTheme.fontFamily,
                            fontFamilyFallback: BeenutTheme.fontFamilyFallback,
                          ),
                          isDense: true,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                sortBy = val;
                              });
                              _loadPath(currentPath);
                            }
                          },
                          items: [
                            DropdownMenuItem(
                              value: 'name',
                              child: Text(I18n.t(context, 'name_az')),
                            ),
                            DropdownMenuItem(
                              value: 'size',
                              child: Text(I18n.t(context, 'size_largest')),
                            ),
                            DropdownMenuItem(
                              value: 'date',
                              child: Text(I18n.t(context, 'last_modified')),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // View Toggle (List/Grid)
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.list_outlined,
                            size: 16,
                            color: !isGridView
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => isGridView = false),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          tooltip: I18n.t(context, 'list_view'),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.grid_view_outlined,
                            size: 16,
                            color: isGridView
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => isGridView = true),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          tooltip: I18n.t(context, 'grid_view'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),

              // Directory Listing
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator())
                    : error.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            error,
                            style: TextStyle(color: scheme.error, fontSize: 12),
                          ),
                        ),
                      )
                    : entries.isEmpty
                    ? Center(
                        child: Text(
                          'No matching files found',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: entries.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.85,
                            ),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final name = entry.path
                              .split(Platform.pathSeparator)
                              .last;
                          final isDir = entry is Directory;
                          final isImageFile =
                              entry is File && widget.pickerKind == 'image';

                          return Card(
                            elevation: 0,
                            color: scheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: scheme.outlineVariant),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _handleEntryClick(entry),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Container(
                                      color: scheme.surfaceContainerHighest,
                                      child: isDir
                                          ? Center(
                                              child: Icon(
                                                Icons.folder,
                                                size: 36,
                                                color: scheme.secondary,
                                              ),
                                            )
                                          : isImageFile
                                          ? Image.file(
                                              File(entry.path),
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Center(
                                                    child: Icon(
                                                      Icons.image,
                                                      size: 24,
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                            )
                                          : Center(
                                              child: Icon(
                                                Icons.insert_drive_file,
                                                size: 28,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(6),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final name = entry.path
                              .split(Platform.pathSeparator)
                              .last;
                          final isDir = entry is Directory;

                          int? sizeBytes;
                          if (entry is File) {
                            try {
                              sizeBytes = entry.lengthSync();
                            } catch (_) {}
                          }

                          return InkWell(
                            onTap: () => _handleEntryClick(entry),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isDir
                                        ? Icons.folder
                                        : Icons.insert_drive_file,
                                    size: 20,
                                    color: isDir
                                        ? scheme.secondary
                                        : widget.pickerKind == 'model'
                                        ? scheme.primary
                                        : scheme.tertiary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (entry is File)
                                          Text(
                                            '${name.split('.').last.toUpperCase()} file',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (sizeBytes != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest,
                                        border: Border.all(
                                          color: scheme.outlineVariant,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _formatSize(sizeBytes),
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 9,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
