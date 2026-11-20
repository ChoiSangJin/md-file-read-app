class DriveEntry {
  const DriveEntry({
    required this.id,
    required this.name,
    required this.isFolder,
    this.modifiedTime,
  });

  final String id;
  final String name;
  final bool isFolder;
  final DateTime? modifiedTime;
}
