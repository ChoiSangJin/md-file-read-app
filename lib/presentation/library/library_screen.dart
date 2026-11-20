import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:md_file_read_app/data/models/recent_document.dart';
import 'package:md_file_read_app/presentation/library/drive_browser.dart';
import 'package:md_file_read_app/presentation/providers/library_providers.dart';
import 'package:md_file_read_app/presentation/viewer/markdown_viewer_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _pickLocalFile(BuildContext context, WidgetRef ref) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['md'],
    );
    if (file == null || !context.mounted) return;

    final bytes = await file.readAsBytes();
    final markdown = utf8.decode(bytes, allowMalformed: true);
    final document = RecentDocument(
      id: file.path ?? file.uri.toString(),
      name: file.name,
      source: DocumentSource.local,
      lastOpenedAt: DateTime.now(),
    );
    await ref.read(recentDocumentsProvider.notifier).record(document);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            MarkdownViewerScreen(document: document, markdown: markdown),
      ),
    );
  }

  Future<void> _openRecent(
    BuildContext context,
    WidgetRef ref,
    RecentDocument document,
  ) async {
    if (document.source == DocumentSource.drive) {
      final fileId = document.id.replaceFirst('drive:', '');
      final markdown = await ref
          .read(driveRepositoryProvider)
          .readCachedMarkdown(fileId);
      if (!context.mounted) return;
      if (markdown == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오프라인 캐시가 없습니다. Drive에서 다시 열어 주세요.')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              MarkdownViewerScreen(document: document, markdown: markdown),
        ),
      );
      return;
    }
    try {
      final path = Uri.tryParse(document.id)?.scheme == 'file'
          ? Uri.parse(document.id).toFilePath()
          : document.id;
      final markdown = await File(path).readAsString();
      final refreshed = RecentDocument(
        id: document.id,
        name: document.name,
        source: document.source,
        lastOpenedAt: DateTime.now(),
      );
      await ref.read(recentDocumentsProvider.notifier).record(refreshed);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              MarkdownViewerScreen(document: refreshed, markdown: markdown),
        ),
      );
    } on FileSystemException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일에 다시 접근할 수 없습니다. 파일을 다시 선택해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentDocuments = ref.watch(recentDocumentsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MD 파일 리더'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder_outlined), text: '로컬 파일'),
              Tab(icon: Icon(Icons.cloud_outlined), text: '구글 드라이브'),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '최근 읽은 파일',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SizedBox(
              height: 106,
              child: recentDocuments.when(
                data: (documents) => documents.isEmpty
                    ? const Center(child: Text('최근 읽은 파일이 없습니다.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: documents.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final document = documents[index];
                          return SizedBox(
                            width: 230,
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: () =>
                                    _openRecent(context, ref, document),
                                leading: Icon(
                                  document.source == DocumentSource.local
                                      ? Icons.description_outlined
                                      : Icons.cloud_outlined,
                                ),
                                title: Text(
                                  document.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  _formatOpenedAt(document.lastOpenedAt),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (_, _) =>
                    const Center(child: Text('최근 파일을 불러오지 못했습니다.')),
              ),
            ),
            const Divider(height: 1),
            const Expanded(
              child: TabBarView(
                children: [
                  _EmptyLibrary(
                    icon: Icons.description_outlined,
                    message: '아래 버튼을 눌러 Markdown 파일을 추가하세요.',
                  ),
                  DriveBrowser(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _pickLocalFile(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('파일 열기'),
        ),
      ),
    );
  }

  String _formatOpenedAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}.${twoDigits(local.month)}.${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
