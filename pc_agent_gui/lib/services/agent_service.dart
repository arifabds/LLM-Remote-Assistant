// lib/services/agent_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
// 'path' paketine artık ihtiyacımız yok çünkü 'workingDirectory' kullanıyoruz.
// import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart';

/// Uygulama genelinde erişilebilecek tek AgentService örneği.
final AgentService agentService = AgentService();

class AgentService {
  late StreamController<List<int>> _stdinController;
  late ShellLinesController _stdoutController;
  late ShellLinesController _stderrController;

  final _jsonEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;
  Shell? _shell;

  Stream<Map<String, dynamic>> get events => _jsonEventController.stream;

  AgentService() {
    _initializeControllers();
  }

  void _initializeControllers() {
    _stdinController = StreamController<List<int>>();
    _stdoutController = ShellLinesController();
    _stderrController = ShellLinesController();
  }

  Future<void> startAgent() async {
    if (_shell != null) {
      dispose();
    }
    _initializeControllers();

    // Python script'inin bulunduğu göreceli yol.
    final scriptPath = Platform.isWindows ? r'..\pc-agent' : '../pc-agent';
    // Çalıştırılacak olan Python executable'ı.
    final pythonExecutable = Platform.isWindows
        ? r'.venv\Scripts\python.exe'
        : '.venv/bin/python';

    // Shell nesnesini, doğru çalışma dizinini belirterek oluşturuyoruz.
    _shell = Shell(
      stdin: _stdinController.stream,
      stdout: _stdoutController.sink,
      stderr: _stderrController.sink,
      workingDirectory: scriptPath, // <<-- EN KRİTİK KISIM
      runInShell: true,
    );

    try {
      // Artık sadece 'python agent.py' demek yeterli, çünkü doğru klasördeyiz.
      final process = _shell!.run('$pythonExecutable agent.py');
      debugPrint('Agent process starting in directory: $scriptPath');

      process.whenComplete(() {
        debugPrint('Agent process exited.');
        if (!_jsonEventController.isClosed) {
          _jsonEventController.add({
            'type': 'status_update',
            'data': {
              'status': 'stopped',
              'message': 'Agent process stopped unexpectedly.',
            },
          });
        }
        dispose();
      });

      _stdoutSub = _stdoutController.stream.listen((line) {
        try {
          if (line.trim().isNotEmpty) {
            final jsonMap = json.decode(line) as Map<String, dynamic>;
            _jsonEventController.add(jsonMap);
          }
        } catch (e) {
          debugPrint('Agent STDOUT (non-JSON): $line');
        }
      });

      _stderrSub = _stderrController.stream.listen((line) {
        debugPrint('Agent STDERR: $line');
      });
    } catch (e) {
      debugPrint('Failed to start agent process: $e');
      if (!_jsonEventController.isClosed) {
        _jsonEventController.add({
          'type': 'error',
          'data': {'message': 'Failed to start Python agent: $e'},
        });
      }
    }
  }

  void sendCommand(String action, [Map<String, dynamic> data = const {}]) {
    if (!_stdinController.isClosed) {
      final command = json.encode({'action': action, 'data': data});
      _stdinController.sink.add(utf8.encode('$command\n'));
      debugPrint('Sent to Agent STDIN: $command');
    } else {
      debugPrint('Cannot send command: Agent stdin is closed.');
    }
  }

  void dispose() {
    if (_shell != null) {
      sendCommand('exit');
      _shell = null;
    }

    _stdoutSub?.cancel();
    _stderrSub?.cancel();

    if (!_stdinController.isClosed) _stdinController.close();
    if (!_stdoutController.isClosed) _stdoutController.close();
    if (!_stderrController.isClosed) _stderrController.close();
  }
}
