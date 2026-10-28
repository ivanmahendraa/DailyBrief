import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart' as stt_error;
import 'package:speech_to_text/speech_recognition_result.dart' as stt_result;
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum SpeechEngineStatus { listening, notListening, done, unknown }

enum SpeechToTextState {
  uninitialized,
  initializing,
  ready,
  unavailable,
  starting,
  listening,
  stopping,
  completed,
  cancelled,
  error,
}

enum SpeechInitializationStatus { ready, permissionDenied, unavailable, error }

enum SpeechStartResult {
  requested,
  alreadyActive,
  permissionDenied,
  unavailable,
  failed,
}

@immutable
class SpeechRecognitionResult {
  final String recognizedWords;
  final bool isFinal;

  const SpeechRecognitionResult({
    required this.recognizedWords,
    required this.isFinal,
  });
}

@immutable
class SpeechRecognitionError {
  final String message;
  final bool isPermanent;

  const SpeechRecognitionError({
    required this.message,
    required this.isPermanent,
  });
}

@immutable
class SpeechLocale {
  final String localeId;
  final String name;

  const SpeechLocale({required this.localeId, required this.name});
}

typedef SpeechResultCallback = void Function(SpeechRecognitionResult result);
typedef SpeechEngineStatusCallback = void Function(SpeechEngineStatus status);
typedef SpeechErrorCallback = void Function(SpeechRecognitionError error);

abstract interface class SpeechToTextClient {
  Future<bool> get hasPermission;

  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message, bool isPermanent) onError,
  });

  Future<List<SpeechLocale>> locales();

  Future<void> listen({
    required String? localeId,
    required SpeechResultCallback onResult,
  });

  Future<void> stop();

  Future<void> cancel();
}

class DefaultSpeechToTextClient implements SpeechToTextClient {
  final stt.SpeechToText _speechToText;

  DefaultSpeechToTextClient([stt.SpeechToText? speechToText])
    : _speechToText = speechToText ?? stt.SpeechToText();

  @override
  Future<bool> get hasPermission => _speechToText.hasPermission;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message, bool isPermanent) onError,
  }) {
    return _speechToText.initialize(
      onStatus: onStatus,
      onError: (stt_error.SpeechRecognitionError error) {
        onError(error.errorMsg, error.permanent);
      },
      options: [stt.SpeechToText.androidNoBluetooth],
    );
  }

  @override
  Future<List<SpeechLocale>> locales() async {
    final locales = await _speechToText.locales();
    return locales
        .map(
          (locale) =>
              SpeechLocale(localeId: locale.localeId, name: locale.name),
        )
        .toList(growable: false);
  }

  @override
  Future<void> listen({
    required String? localeId,
    required SpeechResultCallback onResult,
  }) async {
    await _speechToText.listen(
      onResult: (stt_result.SpeechRecognitionResult result) {
        onResult(
          SpeechRecognitionResult(
            recognizedWords: result.recognizedWords,
            isFinal: result.finalResult,
          ),
        );
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }

  @override
  Future<void> stop() => _speechToText.stop();

  @override
  Future<void> cancel() => _speechToText.cancel();
}

/// Minimal session wrapper for one-shot voice input.
///
/// Constructing this service does not initialize the recognizer or request
/// permission. Call [startListening] only in response to a user action.
class SpeechToTextService {
  final SpeechToTextClient _client;

  SpeechToTextState _state = SpeechToTextState.uninitialized;
  SpeechEngineStatus _engineStatus = SpeechEngineStatus.unknown;
  SpeechRecognitionError? _lastError;
  Future<SpeechInitializationStatus>? _initializationFuture;
  Future<void>? _errorCleanupFuture;
  SpeechResultCallback? _onResult;
  SpeechEngineStatusCallback? _onStatus;
  SpeechErrorCallback? _onError;
  bool _initialized = false;
  bool _startInProgress = false;
  bool _sessionActive = false;
  bool _cancelRequested = false;
  int _diagnosticDoneCount = 0;

  SpeechToTextService({SpeechToTextClient? client})
    : _client = client ?? DefaultSpeechToTextClient();

  SpeechToTextState get state => _state;

  SpeechEngineStatus get engineStatus => _engineStatus;

  SpeechRecognitionError? get lastError => _lastError;

  bool get isListening => _state == SpeechToTextState.listening;

  bool get hasActiveSession =>
      _startInProgress || _sessionActive || _errorCleanupFuture != null;

  Future<bool> get hasPermission => _client.hasPermission;

  Future<SpeechInitializationStatus> initialize() {
    if (_initialized) {
      return Future.value(SpeechInitializationStatus.ready);
    }
    final pendingInitialization = _initializationFuture;
    if (pendingInitialization != null) return pendingInitialization;

    final initialization = _initializeClient();
    _initializationFuture = initialization;
    return initialization.whenComplete(() {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    });
  }

  Future<SpeechInitializationStatus> _initializeClient() async {
    _state = SpeechToTextState.initializing;
    _lastError = null;

    try {
      final available = await _client.initialize(
        onStatus: _handleEngineStatus,
        onError: _handleEngineError,
      );

      if (_lastError != null) {
        _state = SpeechToTextState.error;
        if (_isPermissionError(_lastError!.message)) {
          return SpeechInitializationStatus.permissionDenied;
        }
        return SpeechInitializationStatus.error;
      }

      if (available) {
        _initialized = true;
        _state = SpeechToTextState.ready;
        return SpeechInitializationStatus.ready;
      }

      _state = SpeechToTextState.unavailable;
      final hasPermission = await _client.hasPermission;
      return hasPermission
          ? SpeechInitializationStatus.unavailable
          : SpeechInitializationStatus.permissionDenied;
    } catch (error, stackTrace) {
      debugPrint('SpeechToTextService.initialize error: $error\n$stackTrace');
      _lastError = SpeechRecognitionError(
        message: error.toString(),
        isPermanent: false,
      );
      _state = SpeechToTextState.error;
      return SpeechInitializationStatus.error;
    }
  }

  /// Requests one listen session. The result means the request was accepted;
  /// [isListening] becomes true only after the engine reports `listening`.
  Future<SpeechStartResult> startListening({
    required SpeechResultCallback onResult,
    SpeechEngineStatusCallback? onStatus,
    SpeechErrorCallback? onError,
  }) async {
    if (_startInProgress || _sessionActive || _errorCleanupFuture != null) {
      return SpeechStartResult.alreadyActive;
    }

    _startInProgress = true;
    _lastError = null;
    _onResult = onResult;
    _onStatus = onStatus;
    _onError = onError;

    try {
      final initialization = await initialize();
      switch (initialization) {
        case SpeechInitializationStatus.ready:
          break;
        case SpeechInitializationStatus.permissionDenied:
          _clearSessionCallbacks();
          return SpeechStartResult.permissionDenied;
        case SpeechInitializationStatus.unavailable:
          _clearSessionCallbacks();
          return SpeechStartResult.unavailable;
        case SpeechInitializationStatus.error:
          _clearSessionCallbacks();
          return SpeechStartResult.failed;
      }

      final localeId = await _indonesianLocaleId();
      _sessionActive = true;
      _state = SpeechToTextState.starting;
      await _client.listen(localeId: localeId, onResult: _handleResult);
      return SpeechStartResult.requested;
    } catch (error, stackTrace) {
      debugPrint(
        'SpeechToTextService.startListening error: $error\n$stackTrace',
      );
      await _failSession(
        SpeechRecognitionError(message: error.toString(), isPermanent: false),
      );
      return SpeechStartResult.failed;
    } finally {
      _startInProgress = false;
    }
  }

  Future<void> stopListening() async {
    if (!_sessionActive) return;
    _state = SpeechToTextState.stopping;

    try {
      await _client.stop();
    } catch (error, stackTrace) {
      debugPrint(
        'SpeechToTextService.stopListening error: $error\n$stackTrace',
      );
      await _failSession(
        SpeechRecognitionError(message: error.toString(), isPermanent: false),
      );
    }
  }

  Future<void> cancelListening() async {
    if (!_sessionActive) return;
    _cancelRequested = true;
    _state = SpeechToTextState.stopping;

    try {
      await _client.cancel();
      _state = SpeechToTextState.cancelled;
    } catch (error, stackTrace) {
      debugPrint(
        'SpeechToTextService.cancelListening error: $error\n$stackTrace',
      );
      _lastError = SpeechRecognitionError(
        message: error.toString(),
        isPermanent: false,
      );
      _state = SpeechToTextState.error;
      _notifyError(_lastError!);
    } finally {
      _sessionActive = false;
      _cancelRequested = false;
      _clearSessionCallbacks();
    }
  }

  Future<String?> _indonesianLocaleId() async {
    try {
      final availableLocales = await _client.locales();
      for (final locale in availableLocales) {
        final normalizedLocale = locale.localeId
            .replaceAll('_', '-')
            .toLowerCase();
        if (normalizedLocale == 'id' || normalizedLocale.startsWith('id-')) {
          return locale.localeId;
        }
      }
    } catch (error) {
      debugPrint('SpeechToTextService.locales error: $error');
    }
    return null;
  }

  bool _isPermissionError(String message) {
    final normalizedMessage = message.toLowerCase();
    return normalizedMessage.contains('permission') ||
        normalizedMessage.contains('not_authorized') ||
        normalizedMessage.contains('not authorized');
  }

  void _handleEngineStatus(String status) {
    if (status == stt.SpeechToText.doneStatus) {
      _diagnosticDoneCount++;
      debugPrint(
        '[DIAGNOSTIC][STT_DONE] count=$_diagnosticDoneCount '
        'sessionActive=$_sessionActive state=$_state',
      );
    }

    if (!_sessionActive) return;

    final engineStatus = switch (status) {
      stt.SpeechToText.listeningStatus => SpeechEngineStatus.listening,
      stt.SpeechToText.notListeningStatus => SpeechEngineStatus.notListening,
      stt.SpeechToText.doneStatus => SpeechEngineStatus.done,
      _ => SpeechEngineStatus.unknown,
    };
    _engineStatus = engineStatus;

    if (!_cancelRequested && _state != SpeechToTextState.error) {
      switch (engineStatus) {
        case SpeechEngineStatus.listening:
          _state = SpeechToTextState.listening;
        case SpeechEngineStatus.notListening:
          _state = SpeechToTextState.stopping;
        case SpeechEngineStatus.done:
          _state = SpeechToTextState.completed;
          _sessionActive = false;
        case SpeechEngineStatus.unknown:
          break;
      }
    }

    _notifyStatus(engineStatus);
    if (engineStatus == SpeechEngineStatus.done) {
      _clearSessionCallbacks();
    }
  }

  void _handleEngineError(String message, bool isPermanent) {
    if (!_sessionActive &&
        !_startInProgress &&
        _state != SpeechToTextState.initializing) {
      return;
    }

    final error = SpeechRecognitionError(
      message: message,
      isPermanent: isPermanent,
    );
    _lastError = error;
    _state = SpeechToTextState.error;
    final wasSessionActive = _sessionActive;
    _sessionActive = false;
    _notifyError(error);
    _clearSessionCallbacks();

    if (wasSessionActive) {
      _errorCleanupFuture ??= _cancelAfterError();
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (!_sessionActive) return;
    try {
      _onResult?.call(result);
    } catch (error, stackTrace) {
      debugPrint(
        'SpeechToTextService result callback error: $error\n$stackTrace',
      );
    }
  }

  Future<void> _failSession(SpeechRecognitionError error) async {
    _lastError = error;
    _state = SpeechToTextState.error;
    final shouldCancel = _sessionActive;
    _sessionActive = false;
    _notifyError(error);
    _clearSessionCallbacks();

    if (shouldCancel) await _cancelClientQuietly();
  }

  Future<void> _cancelAfterError() async {
    await _cancelClientQuietly();
    _errorCleanupFuture = null;
  }

  Future<void> _cancelClientQuietly() async {
    try {
      await _client.cancel();
    } catch (error) {
      debugPrint('SpeechToTextService cleanup cancel error: $error');
    }
  }

  void _notifyStatus(SpeechEngineStatus status) {
    try {
      _onStatus?.call(status);
    } catch (error, stackTrace) {
      debugPrint(
        'SpeechToTextService status callback error: $error\n$stackTrace',
      );
    }
  }

  void _notifyError(SpeechRecognitionError error) {
    try {
      _onError?.call(error);
    } catch (callbackError, stackTrace) {
      debugPrint(
        'SpeechToTextService error callback error: $callbackError\n$stackTrace',
      );
    }
  }

  void _clearSessionCallbacks() {
    _onResult = null;
    _onStatus = null;
    _onError = null;
  }
}
