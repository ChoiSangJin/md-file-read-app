import 'dart:io';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:md_file_read_app/data/models/drive_entry.dart';
import 'package:path_provider/path_provider.dart';

class DriveRepository {
  static const scopes = <String>[drive.DriveApi.driveReadonlyScope];
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  final GoogleSignIn _signIn = GoogleSignIn.instance;
  AuthClient? _client;
  drive.DriveApi? _driveApi;
  GoogleSignInAccount? _account;
  bool _initialized = false;

  GoogleSignInAccount? get account => _account;

  Future<GoogleSignInAccount> connect() async {
    if (!_initialized) {
      await _signIn.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      );
      _initialized = true;
    }
    final account = await _signIn.authenticate(scopeHint: scopes);
    final authorization =
        await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);
    _client?.close();
    _client = authorization.authClient(scopes: scopes);
    _driveApi = drive.DriveApi(_client!);
    _account = account;
    return account;
  }

  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    _driveApi = null;
    _account = null;
    await _signIn.disconnect();
  }

  Future<List<DriveEntry>> listFolder(String folderId) async {
    final api = _driveApi;
    if (api == null) throw StateError('Google Drive에 먼저 연결해 주세요.');
    final response = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      spaces: 'drive',
      orderBy: 'folder,name_natural',
      $fields: 'files(id,name,mimeType,modifiedTime)',
      pageSize: 1000,
    );
    final entries = (response.files ?? const <drive.File>[])
        .where(
          (file) =>
              file.mimeType == 'application/vnd.google-apps.folder' ||
              (file.name?.toLowerCase().endsWith('.md') ?? false),
        )
        .map(
          (file) => DriveEntry(
            id: file.id!,
            name: file.name ?? '이름 없는 파일',
            isFolder: file.mimeType == 'application/vnd.google-apps.folder',
            modifiedTime: file.modifiedTime,
          ),
        )
        .toList(growable: false);
    return entries;
  }

  Future<String> downloadMarkdown(String fileId) async {
    final api = _driveApi;
    if (api == null) throw StateError('Google Drive에 먼저 연결해 주세요.');
    final response = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (response is! drive.Media) {
      throw const FormatException('Markdown 파일을 다운로드할 수 없습니다.');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
    }
    final file = await _cacheFile(fileId);
    await file.writeAsBytes(bytes, flush: true);
    return String.fromCharCodes(Uint8List.fromList(bytes));
  }

  Future<String?> readCachedMarkdown(String fileId) async {
    final file = await _cacheFile(fileId);
    return file.existsSync() ? file.readAsString() : null;
  }

  Future<File> _cacheFile(String fileId) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/drive_markdown');
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final safeId = fileId.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    return File('${directory.path}/$safeId.md');
  }
}
