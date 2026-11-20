import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:md_file_read_app/core/theme/app_colors.dart';
import 'package:md_file_read_app/data/models/reader_settings.dart';
import 'package:md_file_read_app/data/models/recent_document.dart';
import 'package:md_file_read_app/presentation/providers/library_providers.dart';

class MarkdownViewerScreen extends ConsumerStatefulWidget {
  const MarkdownViewerScreen({
    super.key,
    required this.document,
    required this.markdown,
  });

  final RecentDocument document;
  final String markdown;

  @override
  ConsumerState<MarkdownViewerScreen> createState() =>
      _MarkdownViewerScreenState();
}

class _MarkdownViewerScreenState extends ConsumerState<MarkdownViewerScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _markdownKey = GlobalKey<MarkdownWidgetState>();
  final _tocController = TocController();
  ReaderSettings _settings = const ReaderSettings();
  bool _appBarVisible = true;
  double _lastOffset = 0;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _restoreState();
  }

  Future<void> _restoreState() async {
    final repository = ref.read(preferencesRepositoryProvider);
    final settings = await repository.loadReaderSettings();
    final offset = await repository.loadScrollOffset(widget.document.id);
    if (!mounted) return;
    setState(() => _settings = settings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _markdownKey.currentState?.controller;
      if (controller == null || !controller.hasClients) return;
      controller.jumpTo(offset.clamp(0, controller.position.maxScrollExtent));
      _lastOffset = controller.offset;
      controller.addListener(_onScroll);
    });
  }

  void _onScroll() {
    final controller = _markdownKey.currentState?.controller;
    if (controller == null || !controller.hasClients) return;
    final offset = controller.offset;
    final shouldShow = offset < 24 || offset < _lastOffset;
    if (shouldShow != _appBarVisible) {
      setState(() => _appBarVisible = shouldShow);
    }
    _lastOffset = offset;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(preferencesRepositoryProvider)
          .saveScrollOffset(widget.document.id, offset);
    });
  }

  void _toggleAppBar(Offset position) {
    final height = MediaQuery.sizeOf(context).height;
    if (position.dy > height * 0.35 && position.dy < height * 0.65) {
      setState(() => _appBarVisible = !_appBarVisible);
    }
  }

  Future<void> _showReadingSettings() async {
    var draft = _settings;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('가독성 설정', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<ReaderTheme>(
                segments: const [
                  ButtonSegment(value: ReaderTheme.light, label: Text('라이트')),
                  ButtonSegment(value: ReaderTheme.dark, label: Text('다크')),
                  ButtonSegment(value: ReaderTheme.sepia, label: Text('세피아')),
                ],
                selected: {draft.theme},
                onSelectionChanged: (selection) {
                  setSheetState(
                    () => draft = draft.copyWith(theme: selection.first),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('글자 크기 ${draft.fontSize.toStringAsFixed(0)}'),
              Slider(
                value: draft.fontSize,
                min: 14,
                max: 26,
                divisions: 12,
                onChanged: (value) => setSheetState(
                  () => draft = draft.copyWith(fontSize: value),
                ),
              ),
              Text('줄 간격 ${draft.lineHeight.toStringAsFixed(1)}'),
              Slider(
                value: draft.lineHeight,
                min: 1.2,
                max: 2,
                divisions: 8,
                onChanged: (value) => setSheetState(
                  () => draft = draft.copyWith(lineHeight: value),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() => _settings = draft);
                    ref
                        .read(preferencesRepositoryProvider)
                        .saveReaderSettings(draft);
                    Navigator.pop(context);
                  },
                  child: const Text('적용'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    final controller = _markdownKey.currentState?.controller;
    if (controller != null && controller.hasClients) {
      ref
          .read(preferencesRepositoryProvider)
          .saveScrollOffset(widget.document.id, controller.offset);
      controller.removeListener(_onScroll);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ViewerPalette.from(_settings.theme);
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: palette.brightness,
        scaffoldBackgroundColor: palette.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          brightness: palette.brightness,
          surface: palette.background,
        ),
      ),
      child: Builder(
        builder: (context) => Scaffold(
          key: _scaffoldKey,
          endDrawer: Drawer(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      '목차',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Expanded(child: TocWidget(controller: _tocController)),
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) => _toggleAppBar(details.globalPosition),
                  child: MarkdownWidget(
                    key: _markdownKey,
                    data: widget.markdown,
                    tocController: _tocController,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.paddingOf(context).top + 72,
                      20,
                      96,
                    ),
                    config: _markdownConfig(palette),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                top: _appBarVisible ? 0 : -120,
                left: 0,
                right: 0,
                child: AppBar(
                  title: Text(widget.document.name),
                  actions: [
                    IconButton(
                      tooltip: '가독성 설정',
                      onPressed: _showReadingSettings,
                      icon: const Icon(Icons.text_fields),
                    ),
                    IconButton(
                      tooltip: '목차',
                      onPressed: () =>
                          _scaffoldKey.currentState?.openEndDrawer(),
                      icon: const Icon(Icons.toc),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.small(
            tooltip: '목차',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: const Icon(Icons.toc),
          ),
        ),
      ),
    );
  }

  MarkdownConfig _markdownConfig(_ViewerPalette palette) {
    final style = TextStyle(
      color: palette.foreground,
      fontSize: _settings.fontSize,
      height: _settings.lineHeight,
    );
    final base = palette.brightness == Brightness.dark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;
    return base.copy(
      configs: [
        PConfig(textStyle: style),
        H1Config(
          style: style.copyWith(
            fontSize: _settings.fontSize * 1.8,
            fontWeight: FontWeight.bold,
          ),
        ),
        H2Config(
          style: style.copyWith(
            fontSize: _settings.fontSize * 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        H3Config(
          style: style.copyWith(
            fontSize: _settings.fontSize * 1.25,
            fontWeight: FontWeight.bold,
          ),
        ),
        PreConfig(
          textStyle: style.copyWith(
            fontFamily: 'monospace',
            fontSize: _settings.fontSize - 1,
          ),
          wrapper: (child, code, language) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: child,
          ),
        ),
        TableConfig(
          wrapper: (child) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _ViewerPalette {
  const _ViewerPalette({
    required this.background,
    required this.foreground,
    required this.brightness,
  });

  final Color background;
  final Color foreground;
  final Brightness brightness;

  factory _ViewerPalette.from(ReaderTheme theme) {
    return switch (theme) {
      ReaderTheme.light => const _ViewerPalette(
        background: Color(0xFFFDFEFF),
        foreground: Color(0xFF102A43),
        brightness: Brightness.light,
      ),
      ReaderTheme.dark => const _ViewerPalette(
        background: Color(0xFF071A2B),
        foreground: Color(0xFFE3F2FD),
        brightness: Brightness.dark,
      ),
      ReaderTheme.sepia => const _ViewerPalette(
        background: Color(0xFFF4ECD8),
        foreground: Color(0xFF4A3B2A),
        brightness: Brightness.light,
      ),
    };
  }
}
