import 'package:material_ui/material_ui.dart';
import 'package:md_file_read_app/core/theme/app_theme.dart';
import 'package:md_file_read_app/presentation/library/library_screen.dart';

class MarkdownReaderApp extends StatelessWidget {
  const MarkdownReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MD 파일 리더',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const LibraryScreen(),
    );
  }
}
