import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:md_file_read_app/data/models/drive_entry.dart';
import 'package:md_file_read_app/data/models/recent_document.dart';
import 'package:md_file_read_app/presentation/providers/library_providers.dart';
import 'package:md_file_read_app/presentation/viewer/markdown_viewer_screen.dart';

class DriveBrowser extends ConsumerStatefulWidget {
  const DriveBrowser({super.key});

  @override
  ConsumerState<DriveBrowser> createState() => _DriveBrowserState();
}

class _DriveBrowserState extends ConsumerState<DriveBrowser> {
  final _folderStack = <_DriveFolder>[
    const _DriveFolder(id: 'root', name: '내 드라이브'),
  ];
  List<DriveEntry> _entries = const [];
  bool _connected = false;
  bool _loading = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(driveRepositoryProvider).connect();
      _connected = true;
      await _loadFolder();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFolder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await ref
          .read(driveRepositoryProvider)
          .listFolder(_folderStack.last.id);
      if (mounted) setState(() => _entries = entries);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEntry(DriveEntry entry) async {
    if (entry.isFolder) {
      _folderStack.add(_DriveFolder(id: entry.id, name: entry.name));
      await _loadFolder();
      return;
    }
    setState(() => _loading = true);
    try {
      final markdown = await ref
          .read(driveRepositoryProvider)
          .downloadMarkdown(entry.id);
      final document = RecentDocument(
        id: 'drive:${entry.id}',
        name: entry.name,
        source: DocumentSource.drive,
        lastOpenedAt: DateTime.now(),
      );
      await ref.read(recentDocumentsProvider.notifier).record(document);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              MarkdownViewerScreen(document: document, markdown: markdown),
        ),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _goBack() async {
    if (_folderStack.length == 1) return true;
    _folderStack.removeLast();
    await _loadFolder();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_connected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_to_drive_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Google Drive의 Markdown 파일을 읽으려면 로그인하세요.\n읽기 전용 권한만 요청합니다.',
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loading ? null : _connect,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: const Text('Google Drive 연결'),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: _folderStack.length == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Column(
        children: [
          ListTile(
            leading: _folderStack.length > 1
                ? IconButton(
                    onPressed: _goBack,
                    icon: const Icon(Icons.arrow_back),
                  )
                : const Icon(Icons.drive_folder_upload_outlined),
            title: Text(_folderStack.last.name),
            trailing: IconButton(
              tooltip: '새로고침',
              onPressed: _loading ? null : _loadFolder,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _entries.isEmpty && !_loading
                ? const Center(child: Text('이 폴더에 Markdown 파일이 없습니다.'))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return ListTile(
                        leading: Icon(
                          entry.isFolder
                              ? Icons.folder_outlined
                              : Icons.description_outlined,
                        ),
                        title: Text(entry.name),
                        trailing: entry.isFolder
                            ? const Icon(Icons.chevron_right)
                            : const Icon(Icons.download_outlined),
                        onTap: _loading ? null : () => _openEntry(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('clientConfigurationError')) {
      return 'OAuth 클라이언트 설정이 필요합니다. README의 설정 안내를 확인하세요.';
    }
    return 'Google Drive 작업에 실패했습니다. 네트워크와 권한을 확인해 주세요.';
  }
}

class _DriveFolder {
  const _DriveFolder({required this.id, required this.name});

  final String id;
  final String name;
}
