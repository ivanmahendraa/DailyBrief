import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_strings.dart';
import '../../services/date_time_service.dart';
import '../../services/speech_to_text_service.dart';
import '../../services/tts_service.dart';
import 'command_parser.dart';

enum VoiceInteractionState {
  idle,
  confirming,
  listening,
  processing,
  speaking,
  error,
}

class VoiceController extends ChangeNotifier {
  static const String confirmationFailureMessage =
      'Maaf, saya tidak dapat memberikan konfirmasi suara. Coba lagi.';
  static const String unsupportedCommandResponse =
      'Maaf, perintah tersebut belum tersedia.';
  static const String permissionDeniedMessage =
      'Izin mikrofon belum diberikan. Periksa pengaturan aplikasi.';
  static const String unavailableMessage =
      'Pengenalan suara tidak tersedia di perangkat ini.';
  static const String startFailureMessage =
      'Maaf, saya tidak dapat memulai sesi suara. Coba lagi.';
  static const String sessionFailureMessage =
      'Maaf, sesi suara mengalami kendala. Coba lagi.';
  static const String playbackFailureMessage =
      'Maaf, respons suara tidak dapat diputar. Coba lagi.';

  final SpeechToTextService _speechToTextService;
  final DateTimeService _dateTimeService;
  final TtsService _ttsService;
  final CommandParser _commandParser = const CommandParser();

  VoiceInteractionState _state = VoiceInteractionState.idle;
  String? _errorMessage;
  String _recognizedText = '';
  int _sessionId = 0;
  bool _startInProgress = false;
  bool _sessionActive = false;
  bool _finalResultHandled = false;
  bool _cancelRequested = false;
  bool _disposed = false;
  TtsPlaybackStatus? _lastPlaybackStatus;

  VoiceController({
    DateTimeService? dateTimeService,
    SpeechToTextService? speechToTextService,
    TtsService? ttsService,
  }) : _dateTimeService = dateTimeService ?? DateTimeService(),
       _speechToTextService = speechToTextService ?? SpeechToTextService(),
       _ttsService = ttsService ?? TtsService();

  VoiceInteractionState get state => _state;

  String? get errorMessage => _errorMessage;

  String get recognizedText => _recognizedText;

  TtsPlaybackStatus? get lastPlaybackStatus => _lastPlaybackStatus;

  bool get hasActiveSession => _startInProgress || _sessionActive;

  Future<void> startListening() async {
    if (_disposed || _state != VoiceInteractionState.idle || hasActiveSession) {
      return;
    }

    final currentSessionId = ++_sessionId;
    _startInProgress = true;
    _sessionActive = true;
    _finalResultHandled = false;
    _cancelRequested = false;
    _recognizedText = '';
    _errorMessage = null;
    _lastPlaybackStatus = null;
    _setState(VoiceInteractionState.confirming);

    TtsPlaybackResult confirmationResult;
    try {
      if (!_ttsService.isReady && !await _ttsService.initialize()) {
        if (_isCurrentSession(currentSessionId)) {
          _setError(confirmationFailureMessage);
        }
        return;
      }
      if (!_isCurrentSession(currentSessionId)) return;

      confirmationResult = await _ttsService.speak(
        AppStrings.voiceConfirmation,
      );
    } catch (error, stackTrace) {
      debugPrint('VoiceController confirmation error: $error\n$stackTrace');
      if (_isCurrentSession(currentSessionId)) {
        _setError(confirmationFailureMessage);
      }
      return;
    }

    if (!_isCurrentSession(currentSessionId)) return;

    _lastPlaybackStatus = confirmationResult.status;
    if (!confirmationResult.isSuccess) {
      if (confirmationResult.isCancelled) {
        _finishSession();
      } else {
        _setError(confirmationFailureMessage);
      }
      return;
    }

    try {
      await _startSpeechRecognition(currentSessionId);
    } catch (error, stackTrace) {
      debugPrint('VoiceController STT start error: $error\n$stackTrace');
      if (_isCurrentSession(currentSessionId)) {
        _setError(startFailureMessage);
      }
    }
  }

  Future<void> _startSpeechRecognition(int currentSessionId) async {
    final result = await _speechToTextService.startListening(
      onResult: (recognizedResult) =>
          _handleResult(currentSessionId, recognizedResult),
      onStatus: (engineStatus) =>
          _handleEngineStatus(currentSessionId, engineStatus),
      onError: (speechError) =>
          _handleSpeechError(currentSessionId, speechError),
    );

    _startInProgress = false;
    if (_disposed || currentSessionId != _sessionId) {
      if (result == SpeechStartResult.requested) {
        await _speechToTextService.cancelListening();
      }
      return;
    }

    if (result != SpeechStartResult.requested) {
      _sessionActive = false;
      switch (result) {
        case SpeechStartResult.permissionDenied:
          _setError(permissionDeniedMessage);
        case SpeechStartResult.unavailable:
          _setError(unavailableMessage);
        case SpeechStartResult.failed:
          _setError(startFailureMessage);
        case SpeechStartResult.alreadyActive:
          _setError(startFailureMessage);
        case SpeechStartResult.requested:
          break;
      }
      return;
    }

    if (_cancelRequested) {
      await _speechToTextService.cancelListening();
      _finishSession();
    }
  }

  Future<void> handleUserTap() async {
    if (_disposed) return;
    await startListening();
  }

  /// Clears the visible error message without starting another session.
  void resetError() {
    if (_disposed || _errorMessage == null) return;
    _errorMessage = null;
    _recognizedText = '';
    notifyListeners();
  }

  Future<void> cancel() async {
    if (_disposed ||
        (!hasActiveSession && _state != VoiceInteractionState.speaking)) {
      return;
    }
    _cancelRequested = true;
    _sessionId++;

    if (_speechToTextService.hasActiveSession || _startInProgress) {
      try {
        await _speechToTextService.cancelListening();
      } catch (error, stackTrace) {
        debugPrint('VoiceController.cancel STT error: $error\n$stackTrace');
      }
    }

    if (_ttsService.isSpeaking) {
      try {
        await _ttsService.stop();
      } catch (error, stackTrace) {
        debugPrint('VoiceController.cancel TTS error: $error\n$stackTrace');
      }
    }
    _finishSession();
  }

  void _handleEngineStatus(int sessionId, SpeechEngineStatus status) {
    if (!_isCurrentSession(sessionId) || _cancelRequested) return;

    if (status == SpeechEngineStatus.listening) {
      _setState(VoiceInteractionState.listening);
      return;
    }

    if (status != SpeechEngineStatus.done) return;

    _sessionActive = false;
    final command = _finalResultHandled
        ? _commandParser.parse(_recognizedText)
        : VoiceCommand.unknown;
    switch (command) {
      case VoiceCommand.day:
        unawaited(_speakResponse(sessionId, _dateTimeService.currentDayResponse));
      case VoiceCommand.date:
        unawaited(_speakResponse(sessionId, _dateTimeService.currentDateResponse));
      case VoiceCommand.time:
        unawaited(_speakResponse(sessionId, _dateTimeService.currentTimeResponse));
      case VoiceCommand.unknown:
        unawaited(_speakResponse(sessionId, unsupportedCommandResponse));
      case VoiceCommand.weather:
      case VoiceCommand.location:
        _finishSession();
    }
  }

  void _handleResult(int sessionId, SpeechRecognitionResult result) {
    if (!_isCurrentSession(sessionId) || _finalResultHandled) return;

    _recognizedText = result.recognizedWords;
    if (!result.isFinal) {
      notifyListeners();
      return;
    }

    _finalResultHandled = true;
    if (_recognizedText.trim().isNotEmpty) {
      _setState(VoiceInteractionState.processing);
    } else {
      notifyListeners();
    }
  }

  void _handleSpeechError(int sessionId, SpeechRecognitionError error) {
    if (!_isCurrentSession(sessionId)) return;
    _sessionActive = false;
    _startInProgress = false;
    _setError(_safeSpeechErrorMessage(error));
  }

  String _safeSpeechErrorMessage(SpeechRecognitionError error) {
    final normalizedMessage = error.message.toLowerCase();
    if (normalizedMessage.contains('permission') ||
        normalizedMessage.contains('not_authorized') ||
        normalizedMessage.contains('not authorized')) {
      return permissionDeniedMessage;
    }
    return sessionFailureMessage;
  }

  Future<void> _speakResponse(int sessionId, String response) async {
    if (!_isCurrentSession(sessionId) || _disposed) return;

    try {
      if (!_ttsService.isReady && !await _ttsService.initialize()) {
        if (_isCurrentSession(sessionId)) _setError(playbackFailureMessage);
        return;
      }
      if (!_isCurrentSession(sessionId) || _disposed) return;

      _setState(VoiceInteractionState.speaking);
      final playbackResult = await _ttsService.speak(response);
      if (!_isCurrentSession(sessionId) || _disposed) return;

      _lastPlaybackStatus = playbackResult.status;
      if (playbackResult.isFailure) {
        _setError(playbackFailureMessage);
      } else {
        _finishSession();
      }
    } catch (error, stackTrace) {
      debugPrint('VoiceController TTS playback error: $error\n$stackTrace');
      if (_isCurrentSession(sessionId) && !_disposed) {
        _setError(playbackFailureMessage);
      }
    }
  }

  bool _isCurrentSession(int sessionId) =>
      !_disposed && sessionId == _sessionId;

  void _finishSession() {
    if (_disposed) return;
    _sessionActive = false;
    _startInProgress = false;
    _cancelRequested = false;
    _recognizedText = '';
    _setState(VoiceInteractionState.idle);
  }

  void _setError(String message) {
    if (_disposed) return;
    _sessionActive = false;
    _startInProgress = false;
    _cancelRequested = false;
    _errorMessage = message;
    _setState(VoiceInteractionState.idle);
  }

  void _setState(VoiceInteractionState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sessionId++;

    if (_speechToTextService.hasActiveSession || _startInProgress) {
      unawaited(_speechToTextService.cancelListening());
    }
    if (_ttsService.isSpeaking) {
      unawaited(_ttsService.stop());
    }
    super.dispose();
  }
}
