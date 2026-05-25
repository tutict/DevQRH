import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../features/lookup/domain/models.dart';

class RagSidecarClient {
  Process? _process;
  Uri? _baseUri;
  Future<Uri?>? _startFuture;

  Future<LookupResponse?> search(
    String query, {
    required ContentBootstrap bootstrap,
  }) async {
    final json = await _postJson('/lookup', {
      'query': query,
      'bootstrap': bootstrap.toJson(),
    });
    if (json == null) {
      return null;
    }
    return LookupResponse.fromJson(json);
  }

  Future<AgentNavigationResponse?> navigateAgent(
    String query, {
    required ContentBootstrap bootstrap,
  }) async {
    final json = await _postJson('/agent/navigate', {
      'query': query,
      'bootstrap': bootstrap.toJson(),
    });
    if (json == null) {
      return null;
    }
    return AgentNavigationResponse.fromJson(json);
  }

  Future<RagAnswerResponse?> answerQuestion(
    String query, {
    required ContentBootstrap bootstrap,
  }) async {
    final json = await _postJson('/rag/answer', {
      'query': query,
      'bootstrap': bootstrap.toJson(),
    });
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
    process?.kill();
  }

  Future<Map<String, dynamic>?> _postJson(
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
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final raw = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
    return null;
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

      process.stderr.transform(utf8.decoder).listen((_) {});
      process.exitCode.then((_) {
        if (!ready.isCompleted) {
          ready.complete(null);
        }
        _process = null;
        _baseUri = null;
        _startFuture = null;
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
