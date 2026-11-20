import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_file_read_app/app/app.dart';
import 'package:md_file_read_app/data/models/recent_document.dart';
import 'package:md_file_read_app/presentation/providers/library_providers.dart';

void main() {
  testWidgets('shows the library tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentDocumentsProvider.overrideWith(_TestRecentDocuments.new),
        ],
        child: const MarkdownReaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MD 파일 리더'), findsOneWidget);
    expect(find.text('로컬 파일'), findsOneWidget);
    expect(find.text('구글 드라이브'), findsOneWidget);
  });
}

class _TestRecentDocuments extends RecentDocumentsNotifier {
  @override
  Future<List<RecentDocument>> build() async => const [];
}
