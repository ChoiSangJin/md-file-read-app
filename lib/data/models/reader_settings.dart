enum ReaderTheme { light, dark, sepia }

class ReaderSettings {
  const ReaderSettings({
    this.theme = ReaderTheme.light,
    this.fontSize = 17,
    this.lineHeight = 1.6,
  });

  final ReaderTheme theme;
  final double fontSize;
  final double lineHeight;

  ReaderSettings copyWith({
    ReaderTheme? theme,
    double? fontSize,
    double? lineHeight,
  }) {
    return ReaderSettings(
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}
