import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../features/lookup/domain/models.dart';

class RagSidecarClient {
  Process? _process;
  Uri? _baseUri;
  Future<Uri?>? _startFuture;
  String? _syncedBootstrapMarker;
  String? _contentVersion;

  Future<LookupResponse?> search(
    String query, {
    required ContentBootstrap bootstrap,
  }) async {
    final json = await _postQueryJson('/lookup', query, bootstrap);
    if (json == null) {
      return null;
    }
    return LookupResponse.fromJson(json);
  }

  Future<AgentNavigationResponse?> navigateAgent(
    String query, {
    required ContentBootstrap bootstrap,
  }) async {
    final json = await _postQueryJson('/agent/navigate', query, bootstrap);
    if (json == null) {
      return null;
    }
    return AgentNavigationResponse.fromJson(json);
  }

  Future<RagAnswerResponse?> answerQuestion(
    String query, {
    required ContentBootstrap bootstrap,
  }) async {
    final json = await _postQueryJson('/rag/answer', query, bootstrap);
    if (json == null) {
      return null;
    }
    return RagAnswerResponse.fromJson(json);
  }

  void dispose() {
    final process = _process;
    _process = null;
    _baseUri = null;
    _startFuture = null;
    _syncedBootstrapMarker = null;
    _contentVersion = null;
    process?.kill();
  }

  Future<Map<String, dynamic>?> _postQueryJson(
    String path,
    String query,
    ContentBootstrap bootstrap,
  ) async {
    final marker = _bootstrapMarker(bootstrap);
    final contentVersion = await _ensureContentSynced(bootstrap, marker);
    if (contentVersion != null) {
      final response = await _postJson(path, {
        'query': query,
        'contentVersion': contentVersion,
      });
      if (response != null && response.isSuccess && response.json != null) {
        return response.json;
      }
      if (response?.statusCode == HttpStatus.conflict) {
        _syncedBootstrapMarker = null;
        _contentVersion = null;
        final retriedVersion = await _ensureContentSynced(bootstrap, marker);
        if (retriedVersion != null) {
          final retry = await _postJson(path, {
            'query': query,
            'contentVersion': retriedVersion,
          });
          if (retry != null && retry.isSuccess && retry.json != null) {
            return retry.json;
          }
        }
      }
      if (response?.statusCode != HttpStatus.notFound) {
        return null;
      }
    }

    final legacy = await _postJson(path, {
      'query': query,
      'bootstrap': bootstrap.toJson(),
    });
    if (legacy != null && legacy.isSuccess && legacy.json != null) {
      return legacy.json;
    }
    return null;
  }

  Future<String?> _ensureContentSynced(
    ContentBootstrap bootstrap,
    String marker,
  ) async {
    if (_syncedBootstrapMarker == marker && _contentVersion != null) {
      return _contentVersion;
    }

    final response = await _postJson('/content/sync', {
      'bootstrap': bootstrap.toJson(),
    });
    if (response == null || !response.isSuccess || response.json == null) {
      return null;
    }
    final contentVersion = response.json!['contentVersion'];
    if (contentVersion is! String || contentVersion.trim().isEmpty) {
      return null;
    }
    _syncedBootstrapMarker = marker;
    _contentVersion = contentVersion;
    return contentVersion;
  }

  String _bootstrapMarker(ContentBootstrap bootstrap) {
    final manifest = bootstrap.manifest;
    return [
      manifest.version,
      manifest.checklistCount,
      manifest.generatedAt,
      bootstrap.checklists.length,
    ].join(':');
  }

  Future<_SidecarJsonResponse?> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final baseUri = await _ensureStarted();
    if (baseUri == null) {
      return null;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client
          .postUrl(baseUri.resolve(path))
          .timeout(const Duration(seconds: 2));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      final raw = await utf8.decoder.bind(response).join();
      Map<String, dynamic>? decoded;
      if (raw.trim().isNotEmpty) {
        final json = jsonDecode(raw);
        if (json is Map) {
          decoded = json.cast<String, dynamic>();
        }
      }
      return _SidecarJsonResponse(response.statusCode, decoded);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Uri?> _ensureStarted() async {
    if (_baseUri != null && _process != null) {
      return _baseUri;
    }
    if (!_supportsSidecar) {
      return null;
    }

    _startFuture ??= _start();
    return _startFuture;
  }

  Future<Uri?> _start() async {
    final executable = _resolveExecutable();
    if (executable == null) {
      return null;
    }

    final ready = Completer<Uri?>();
    try {
      final process = await Process.start(executable.path, const ['--port=0']);
      _process = process;
      _syncedBootstrapMarker = null;
      _contentVersion = null;

      process.stderr.transform(utf8.decoder).listen((_) {});
      process.exitCode.then((_) {
        if (!ready.isCompleted) {
          ready.complete(null);
        }
        _process = null;
        _baseUri = null;
        _startFuture = null;
        _syncedBootstrapMarker = null;
        _contentVersion = null;
      });

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (ready.isCompleted) {
              return;
            }
            final uri = _parseReadyLine(line);
            if (uri != null) {
              _baseUri = uri;
              ready.complete(uri);
            }
          });

      final uri = await ready.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (uri == null) {
        process.kill();
      }
      return uri;
    } catch (_) {
      _process = null;
      _baseUri = null;
      _startFuture = null;
      return null;
    }
  }

  Uri? _parseReadyLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return null;
      }
      if (decoded['event'] != 'ready') {
        return null;
      }
      final port = decoded['port'];
      if (port is! int || port <= 0) {
        return null;
      }
      return Uri.parse('http://127.0.0.1:$port');
    } catch (_) {
      return null;
    }
  }

  File? _resolveExecutable() {
    final fileName = Platform.isWindows ? 'rag_sidecar.exe' : 'rag_sidecar';
    final envPath = Platform.environment['DEVQRH_RAG_SIDECAR'];
    final candidates = <File>[
      if (envPath != null && envPath.trim().isNotEmpty) File(envPath.trim()),
      File(_join(Directory.current.path, fileName)),
      File(
        _join(
          _join(Directory.current.path, 'build'),
          _join('sidecar', fileName),
        ),
      ),
      File(
        _join(_join(Directory.current.path, 'sidecar'), _join('rag', fileName)),
      ),
      File(
        _join(
          _join(Directory.current.parent.path, 'sidecar'),
          _join('rag', fileName),
        ),
      ),
      File(_join(_executableDirectory.path, fileName)),
    ];

    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  Directory get _executableDirectory {
    return File(Platform.resolvedExecutable).parent;
  }

  bool get _supportsSidecar {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  String _join(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }
}

class _SidecarJsonResponse {
  const _SidecarJsonResponse(this.statusCode, this.json);

  final int statusCode;
  final Map<String, dynamic>? json;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
