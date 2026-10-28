import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/features/voice/voice_controller.dart';
import 'package:daily_brief/features/voice/command_parser.dart';
import 'package:daily_brief/services/date_time_service.dart';
import 'package:daily_brief/services/geocoding_service.dart';
import 'package:daily_brief/services/location_service.dart';
import 'package:daily_brief/services/command_history_service.dart';
import 'package:daily_brief/features/voice/weather_response_generator.dart';
import 'package:daily_brief/services/speech_to_text_service.dart';
import 'package:daily_brief/services/tts_service.dart';
import 'package:daily_brief/services/weather_service.dart';

class _FakeSpeechToTextClient implements SpeechToTextClient {
  bool initializeAvailable = true;
  bool throwOnListen = false;
  int listenCallCount = 0;
  int cancelCallCount = 0;
  int stopCallCount = 0;
  String? localeId;

  void Function(String status)? onStatus;
  void Function(String message, bool isPermanent)? onError;
  SpeechResultCallback? onResult;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message, bool isPermanent) onError,
  }) async {
    this.onStatus = onStatus;
    this.onError = onError;
    return initializeAvailable;
  }

  @override
  Future<List<SpeechLocale>> locales() async => const [
    SpeechLocale(localeId: 'id-ID', name: 'Indonesian'),
  ];

  @override
  Future<void> listen({
    required String? localeId,
    required SpeechResultCallback onResult,
  }) async {
    listenCallCount++;
    this.localeId = localeId;
    this.onResult = onResult;
    if (throwOnListen) throw StateError('listen failed');
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCallCount++;
  }

  void emitStatus(String status) => onStatus?.call(status);

  void emitError(String message, {bool permanent = false}) =>
      onError?.call(message, permanent);

  void emitResult(String words, {required bool isFinal}) => onResult?.call(
    SpeechRecognitionResult(recognizedWords: words, isFinal: isFinal),
  );
}

class _FakeTtsService extends TtsService {
  bool initializeResult = true;
  bool throwOnSpeak = false;
  int initializeCallCount = 0;
  int speakCallCount = 0;
  int stopCallCount = 0;
  String? spokenText;
  final List<String> spokenTexts = [];
  TtsPlaybackResult playbackResult = TtsPlaybackResult.success();
  TtsPlaybackResult confirmationPlaybackResult = TtsPlaybackResult.success();
  Completer<TtsPlaybackResult>? pendingConfirmation;
  Completer<TtsPlaybackResult>? pendingPlayback;
  bool speaking = false;
  bool initialized = false;

  _FakeTtsService() : super();

  @override
  bool get isReady => initialized;

  @override
  bool get isSpeaking => speaking;

  int get confirmationCallCount =>
      spokenTexts.where((text) => text == AppStrings.voiceConfirmation).length;

  int get responseCallCount =>
      spokenTexts.where((text) => text != AppStrings.voiceConfirmation).length;

  @override
  Future<bool> initialize({
    String language = TtsService.defaultLanguage,
    double speechRate = TtsService.defaultSpeechRate,
    double volume = TtsService.defaultVolume,
    double pitch = TtsService.defaultPitch,
  }) async {
    initializeCallCount++;
    initialized = initializeResult;
    return initializeResult;
  }

  @override
  Future<TtsPlaybackResult> speak(String text) async {
    speakCallCount++;
    spokenText = text;
    spokenTexts.add(text);
    final isConfirmation = text == AppStrings.voiceConfirmation;
    if (throwOnSpeak && !isConfirmation) throw StateError('TTS failed');
    speaking = true;
    final pending = isConfirmation ? pendingConfirmation : pendingPlayback;
    final result = pending == null
        ? isConfirmation
              ? confirmationPlaybackResult
              : playbackResult
        : await pending.future;
    speaking = false;
    return result;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    speaking = false;
    if (pendingPlayback != null && !pendingPlayback!.isCompleted) {
      pendingPlayback!.complete(TtsPlaybackResult.cancelled());
    }
    if (pendingConfirmation != null && !pendingConfirmation!.isCompleted) {
      pendingConfirmation!.complete(TtsPlaybackResult.cancelled());
    }
  }
}

class _FakeLocationService extends LocationService {
  LocationResult resultToReturn = LocationResult.success(
    Position(
      latitude: 1.1301,
      longitude: 104.0529,
      timestamp: DateTime(2026, 10, 23),
      accuracy: 5.0,
      altitude: 10.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    ),
  );
  int callCount = 0;
  bool throwException = false;
  Completer<LocationResult>? pendingResult;

  _FakeLocationService() : super();

  @override
  Future<LocationResult> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
    LocationSettings? locationSettings,
  }) async {
    callCount++;
    if (throwException) throw StateError('LocationService crashed');
    if (pendingResult != null) return pendingResult!.future;
    return resultToReturn;
  }
}

class _FakeGeocodingService extends GeocodingService {
  GeocodingResult resultToReturn = GeocodingResult.success(
    const LocationAddress(
      placeName: 'Mega Mall Batam',
      city: 'Kota Batam',
      province: 'Kepulauan Riau',
      country: 'Indonesia',
    ),
  );
  int callCount = 0;
  double? lastLatitude;
  double? lastLongitude;
  bool throwException = false;

  _FakeGeocodingService() : super();

  @override
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    callCount++;
    lastLatitude = latitude;
    lastLongitude = longitude;
    if (throwException) throw StateError('GeocodingService crashed');
    return resultToReturn;
  }
}

class _FakeWeatherService extends WeatherService {
  WeatherResult resultToReturn = WeatherResult.success(
    const WeatherData(
      description: 'cerah berawan',
      temperature: 28.4,
      cityName: 'Batam',
    ),
  );
  int callCount = 0;
  double? lastLatitude;
  double? lastLongitude;
  bool throwException = false;
  Completer<WeatherResult>? pendingResult;

  _FakeWeatherService() : super();

  @override
  Future<WeatherResult> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    callCount++;
    lastLatitude = latitude;
    lastLongitude = longitude;
    if (throwException) throw StateError('WeatherService crashed');
    if (pendingResult != null) return pendingResult!.future;
    return resultToReturn;
  }
}

class _FakeCommandHistoryWriter implements CommandHistoryWriter {
  final List<VoiceCommand> commands = [];
  bool throwOnRecord = false;

  @override
  Future<void> record(VoiceCommand command) async {
    if (throwOnRecord) throw StateError('history unavailable');
    commands.add(command);
  }
}

class _Harness {
  _Harness({
    DateTimeService? dateTimeService,
    LocationService? locationService,
    GeocodingService? geocodingService,
    WeatherService? weatherService,
    WeatherResponseGenerator? weatherResponseGenerator,
  }) : dateTimeService =
           dateTimeService ??
           DateTimeService(now: () => DateTime(2026, 10, 16)),
       locationService = locationService ?? _FakeLocationService(),
       geocodingService = geocodingService ?? _FakeGeocodingService(),
       weatherService = weatherService ?? _FakeWeatherService(),
       weatherResponseGenerator =
           weatherResponseGenerator ?? const WeatherResponseGenerator();

  final _FakeSpeechToTextClient speechClient = _FakeSpeechToTextClient();
  final _FakeTtsService ttsService = _FakeTtsService();
  final _FakeCommandHistoryWriter commandHistoryWriter =
      _FakeCommandHistoryWriter();
  final DateTimeService dateTimeService;
  final LocationService locationService;
  final GeocodingService geocodingService;
  final WeatherService weatherService;
  final WeatherResponseGenerator weatherResponseGenerator;
  late final SpeechToTextService speechService = SpeechToTextService(
    client: speechClient,
  );
  late final VoiceController controller = VoiceController(
    dateTimeService: dateTimeService,
    speechToTextService: speechService,
    ttsService: ttsService,
    locationService: locationService,
    geocodingService: geocodingService,
    weatherService: weatherService,
    commandHistoryWriter: commandHistoryWriter,
    weatherResponseGenerator: weatherResponseGenerator,
  );

  Future<void> start() async {
    await controller.startListening();
  }

  Future<void> startAndConfirmListening() async {
    final startFuture = controller.startListening();
    await waitForListenRequest();
    speechClient.emitStatus('listening');
    await startFuture;
  }

  Future<void> waitForListenRequest() async {
    while (speechClient.listenCallCount == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> emitFinalAndComplete(String words) async {
    speechClient.emitResult(words, isFinal: true);
    speechClient.emitStatus('done');
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceController', () {
    test(
      'starts from idle and waits for the engine listening confirmation',
      () async {
        final harness = _Harness();
        final observedStates = <VoiceInteractionState>[];
        harness.controller.addListener(() {
          observedStates.add(harness.controller.state);
        });
        harness.ttsService.pendingConfirmation = Completer<TtsPlaybackResult>();

        final startFuture = harness.start();
        await Future<void>.delayed(Duration.zero);

        expect(harness.controller.state, VoiceInteractionState.confirming);
        expect(harness.ttsService.spokenText, AppStrings.voiceConfirmation);
        expect(harness.speechClient.listenCallCount, 0);

        harness.ttsService.pendingConfirmation!.complete(
          TtsPlaybackResult.success(),
        );
        await harness.waitForListenRequest();
        expect(harness.controller.state, VoiceInteractionState.confirming);
        expect(harness.speechClient.listenCallCount, 1);
        expect(harness.speechClient.localeId, 'id-ID');

        harness.speechClient.emitStatus('listening');
        await startFuture;

        expect(harness.controller.state, VoiceInteractionState.listening);
        expect(observedStates, contains(VoiceInteractionState.listening));
        harness.controller.dispose();
      },
    );

    test('does not start STT if voice confirmation fails', () async {
      final harness = _Harness()
        ..ttsService.confirmationPlaybackResult = TtsPlaybackResult.failure(
          'confirmation failed',
        );

      await harness.start();

      expect(harness.ttsService.spokenTexts, [AppStrings.voiceConfirmation]);
      expect(harness.controller.state, VoiceInteractionState.idle);
      expect(
        harness.controller.errorMessage,
        VoiceController.confirmationFailureMessage,
      );
      expect(harness.speechClient.listenCallCount, 0);
      harness.controller.dispose();
    });

    test('cancel during confirmation does not start STT', () async {
      final harness = _Harness();
      harness.ttsService.pendingConfirmation = Completer<TtsPlaybackResult>();
      final startFuture = harness.controller.startListening();
      await Future<void>.delayed(Duration.zero);

      expect(harness.controller.state, VoiceInteractionState.confirming);
      expect(harness.ttsService.confirmationCallCount, 1);
      expect(harness.speechClient.listenCallCount, 0);

      await harness.controller.cancel();
      await startFuture;

      expect(harness.ttsService.stopCallCount, 1);
      expect(harness.speechClient.listenCallCount, 0);
      expect(harness.controller.state, VoiceInteractionState.idle);
      expect(harness.controller.hasActiveSession, isFalse);
      harness.controller.dispose();
    });

    test('does not start overlapping sessions', () async {
      final harness = _Harness();
      await harness.start();
      await harness.controller.startListening();

      expect(harness.speechClient.listenCallCount, 1);
      expect(harness.controller.hasActiveSession, isTrue);
      harness.controller.dispose();
    });

    test(
      'ignores duplicate final results and speaks one honest fallback',
      () async {
        final harness = _Harness();
        await harness.startAndConfirmListening();

        harness.speechClient.emitResult('ucapan tidak dikenal', isFinal: false);
        expect(harness.controller.state, VoiceInteractionState.listening);
        expect(harness.controller.recognizedText, 'ucapan tidak dikenal');

        harness.speechClient.emitResult('ucapan tidak dikenal', isFinal: true);
        harness.speechClient.emitResult('ucapan tidak dikenal', isFinal: true);
        expect(harness.controller.state, VoiceInteractionState.processing);
        expect(harness.ttsService.responseCallCount, 0);

        harness.speechClient.emitStatus('done');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(harness.ttsService.responseCallCount, 1);
        expect(
          harness.ttsService.spokenText,
          VoiceController.unsupportedCommandResponse,
        );
        expect(harness.controller.state, VoiceInteractionState.idle);
        expect(harness.controller.hasActiveSession, isFalse);
        expect(harness.commandHistoryWriter.commands, isEmpty);
        harness.controller.dispose();
      },
    );

    test(
      'empty final result speaks the unsupported-command response',
      () async {
        final harness = _Harness();
        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('   ');

        expect(harness.ttsService.responseCallCount, 1);
        expect(
          harness.ttsService.spokenText,
          VoiceController.unsupportedCommandResponse,
        );
        expect(harness.controller.state, VoiceInteractionState.idle);
        expect(harness.controller.errorMessage, isNull);
        harness.controller.dispose();
      },
    );

    test(
      'speaks the unsupported-command response when no result is received',
      () async {
        final harness = _Harness();
        await harness.startAndConfirmListening();

        harness.speechClient.emitStatus('done');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(harness.ttsService.responseCallCount, 1);
        expect(
          harness.ttsService.spokenText,
          VoiceController.unsupportedCommandResponse,
        );
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      },
    );

    test('day command speaks the current day in Indonesian', () async {
      final harness = _Harness(
        dateTimeService: DateTimeService(now: () => DateTime(2026, 10, 16)),
      );
      await harness.startAndConfirmListening();
      await harness.emitFinalAndComplete('hari ini');

      expect(harness.ttsService.responseCallCount, 1);
      expect(harness.ttsService.spokenText, 'Hari ini hari Jumat.');
      expect(harness.controller.state, VoiceInteractionState.idle);
      expect(harness.controller.hasActiveSession, isFalse);
      expect(harness.commandHistoryWriter.commands, [VoiceCommand.day]);
      harness.controller.dispose();
    });

    test(
      'history write failure does not interrupt the voice response',
      () async {
        final harness = _Harness()..commandHistoryWriter.throwOnRecord = true;
        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('hari ini');

        expect(harness.ttsService.spokenText, 'Hari ini hari Jumat.');
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      },
    );

    test('date command speaks the current date in Indonesian', () async {
      final harness = _Harness(
        dateTimeService: DateTimeService(now: () => DateTime(2026, 10, 16)),
      );
      await harness.startAndConfirmListening();
      await harness.emitFinalAndComplete('tanggal berapa');

      expect(harness.ttsService.responseCallCount, 1);
      expect(
        harness.ttsService.spokenText,
        'Hari ini tanggal 16 Oktober 2026.',
      );
      expect(harness.controller.state, VoiceInteractionState.idle);
      expect(harness.controller.hasActiveSession, isFalse);
      harness.controller.dispose();
    });

    test('time command speaks the current local time in Indonesian', () async {
      final harness = _Harness(
        dateTimeService: DateTimeService(
          now: () => DateTime(2026, 10, 16, 13, 5),
        ),
      );
      await harness.startAndConfirmListening();
      await harness.emitFinalAndComplete('jam berapa');

      expect(harness.ttsService.responseCallCount, 1);
      expect(
        harness.ttsService.spokenText,
        'Sekarang pukul 1 siang lewat 5 menit.',
      );
      expect(harness.controller.state, VoiceInteractionState.idle);
      expect(harness.controller.hasActiveSession, isFalse);
      harness.controller.dispose();
    });

    test('cancel clears the active session without speaking', () async {
      final harness = _Harness();
      await harness.startAndConfirmListening();

      await harness.controller.cancel();

      expect(harness.speechClient.cancelCallCount, 1);
      expect(harness.controller.state, VoiceInteractionState.idle);
      expect(harness.controller.hasActiveSession, isFalse);
      expect(harness.ttsService.responseCallCount, 0);
      harness.controller.dispose();
    });

    test(
      'initialization unavailable returns to idle and retains an error message',
      () async {
        final harness = _Harness()..speechClient.initializeAvailable = false;
        await harness.start();

        expect(harness.controller.state, VoiceInteractionState.idle);
        expect(harness.controller.errorMessage, isNotEmpty);
        expect(harness.ttsService.responseCallCount, 0);

        harness.controller.resetError();
        expect(harness.controller.state, VoiceInteractionState.idle);
        expect(harness.controller.errorMessage, isNull);
        harness.controller.dispose();
      },
    );

    test(
      'permission and engine errors use safe user-facing messages',
      () async {
        final permissionHarness = _Harness();
        await permissionHarness.start();
        permissionHarness.speechClient.emitError(
          'error_permission',
          permanent: true,
        );

        expect(permissionHarness.controller.state, VoiceInteractionState.idle);
        expect(
          permissionHarness.controller.errorMessage,
          VoiceController.permissionDeniedMessage,
        );
        permissionHarness.controller.dispose();

        final errorHarness = _Harness();
        await errorHarness.startAndConfirmListening();
        errorHarness.speechClient.emitError('error_network');
        await Future<void>.delayed(Duration.zero);

        expect(errorHarness.controller.state, VoiceInteractionState.idle);
        expect(
          errorHarness.controller.errorMessage,
          VoiceController.sessionFailureMessage,
        );
        expect(errorHarness.speechClient.cancelCallCount, 1);
        errorHarness.controller.dispose();
      },
    );

    test('listen failure cleans up and exposes a retryable error', () async {
      final harness = _Harness()..speechClient.throwOnListen = true;
      await harness.start();

      expect(harness.controller.state, VoiceInteractionState.idle);
      expect(
        harness.controller.errorMessage,
        VoiceController.startFailureMessage,
      );
      expect(harness.controller.hasActiveSession, isFalse);
      expect(harness.speechClient.cancelCallCount, 1);
      harness.controller.dispose();
    });

    test(
      'fallback playback enters speaking then returns to idle on success',
      () async {
        final harness = _Harness();
        harness.ttsService.pendingPlayback = Completer<TtsPlaybackResult>();
        await harness.startAndConfirmListening();
        harness.speechClient.emitResult(
          'tolong lakukan sesuatu',
          isFinal: true,
        );
        harness.speechClient.emitStatus('done');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(harness.controller.state, VoiceInteractionState.speaking);
        expect(harness.ttsService.responseCallCount, 1);

        harness.ttsService.pendingPlayback!.complete(
          TtsPlaybackResult.success(),
        );
        await Future<void>.delayed(Duration.zero);

        expect(harness.controller.state, VoiceInteractionState.idle);
        expect(
          harness.controller.lastPlaybackStatus,
          TtsPlaybackStatus.success,
        );
        harness.controller.dispose();
      },
    );

    test(
      'TTS failure sets a safe error and TTS cancellation returns to idle',
      () async {
        final failedHarness = _Harness()..ttsService.throwOnSpeak = true;
        await failedHarness.startAndConfirmListening();
        await failedHarness.emitFinalAndComplete('tolong lakukan sesuatu');

        expect(failedHarness.controller.state, VoiceInteractionState.idle);
        expect(
          failedHarness.controller.errorMessage,
          VoiceController.playbackFailureMessage,
        );
        failedHarness.controller.dispose();

        final cancelledHarness = _Harness()
          ..ttsService.playbackResult = TtsPlaybackResult.cancelled();
        await cancelledHarness.startAndConfirmListening();
        await cancelledHarness.emitFinalAndComplete('tolong lakukan sesuatu');

        expect(cancelledHarness.controller.state, VoiceInteractionState.idle);
        expect(
          cancelledHarness.controller.lastPlaybackStatus,
          TtsPlaybackStatus.cancelled,
        );
        cancelledHarness.controller.dispose();
      },
    );

    test('cancel during speaking stops TTS and returns to idle', () async {
      final harness = _Harness();
      harness.ttsService.pendingPlayback = Completer<TtsPlaybackResult>();
      await harness.startAndConfirmListening();
      harness.speechClient.emitResult('perintah', isFinal: true);
      harness.speechClient.emitStatus('done');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(harness.controller.state, VoiceInteractionState.speaking);
      await harness.controller.cancel();

      expect(harness.ttsService.stopCallCount, 1);
      expect(harness.controller.state, VoiceInteractionState.idle);
      expect(harness.controller.hasActiveSession, isFalse);
      harness.controller.dispose();
    });

    test(
      'TTS initialization failure reports an error and dispose stops playback',
      () async {
        final initializeFailure = _Harness()
          ..ttsService.initializeResult = false;
        await initializeFailure.start();

        expect(initializeFailure.ttsService.initializeCallCount, 1);
        expect(initializeFailure.ttsService.speakCallCount, 0);
        expect(initializeFailure.speechClient.listenCallCount, 0);
        expect(initializeFailure.controller.state, VoiceInteractionState.idle);
        expect(
          initializeFailure.controller.errorMessage,
          VoiceController.confirmationFailureMessage,
        );
        initializeFailure.controller.dispose();

        final activePlayback = _Harness();
        activePlayback.ttsService.pendingPlayback =
            Completer<TtsPlaybackResult>();
        await activePlayback.startAndConfirmListening();
        activePlayback.speechClient.emitResult('perintah', isFinal: true);
        activePlayback.speechClient.emitStatus('done');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(activePlayback.controller.state, VoiceInteractionState.speaking);

        activePlayback.controller.dispose();

        expect(activePlayback.ttsService.stopCallCount, 1);
        expect(activePlayback.controller.hasActiveSession, isFalse);
      },
    );

    test(
      'dispose during listening cancels STT and ignores late callbacks',
      () async {
        final harness = _Harness();
        await harness.startAndConfirmListening();
        expect(harness.controller.state, VoiceInteractionState.listening);

        harness.controller.dispose();
        harness.speechClient.emitResult('late', isFinal: true);
        harness.speechClient.emitStatus('done');

        expect(harness.speechClient.cancelCallCount, 1);
        expect(harness.ttsService.responseCallCount, 0);
      },
    );

    group('location command (TASK-48)', () {
      test('1. location command fetches coords, calls geocoding, and speaks formatted response with placeName', () async {
        final fakeLocation = _FakeLocationService();
        final fakeGeocoding = _FakeGeocodingService();
        final harness = _Harness(
          locationService: fakeLocation,
          geocodingService: fakeGeocoding,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('lokasi saya');

        expect(fakeLocation.callCount, 1);
        expect(fakeGeocoding.callCount, 1);
        expect(fakeGeocoding.lastLatitude, 1.1301);
        expect(fakeGeocoding.lastLongitude, 104.0529);
        expect(harness.ttsService.responseCallCount, 1);
        expect(
          harness.ttsService.spokenText,
          'Anda berada di Kota Batam, Kepulauan Riau, Indonesia.',
        );
        expect(harness.controller.state, VoiceInteractionState.idle);
        expect(harness.controller.hasActiveSession, isFalse);
        harness.controller.dispose();
      });

      test('2. location command speaks response without placeName when only city is available', () async {
        final fakeLocation = _FakeLocationService();
        final fakeGeocoding = _FakeGeocodingService()
          ..resultToReturn = GeocodingResult.success(
            const LocationAddress(city: 'Batam', province: 'Kepulauan Riau'),
          );
        final harness = _Harness(
          locationService: fakeLocation,
          geocodingService: fakeGeocoding,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('di mana saya');

        expect(
          harness.ttsService.spokenText,
          'Anda berada di Batam, Kepulauan Riau.',
        );
        harness.controller.dispose();
      });

      test(
        '3. location command speaks error when permission is denied',
        () async {
          final fakeLocation = _FakeLocationService()
            ..resultToReturn = LocationResult.permissionDenied();
          final fakeGeocoding = _FakeGeocodingService();
          final harness = _Harness(
            locationService: fakeLocation,
            geocodingService: fakeGeocoding,
          );

          await harness.startAndConfirmListening();
          await harness.emitFinalAndComplete('posisi saya');

          expect(fakeLocation.callCount, 1);
          expect(fakeGeocoding.callCount, 0);
          expect(harness.ttsService.responseCallCount, 1);
          expect(
            harness.ttsService.spokenText,
            LocationPermissionMessages.denied,
          );
          expect(harness.controller.state, VoiceInteractionState.idle);
          harness.controller.dispose();
        },
      );

      test(
        '4. location command speaks error when permission is denied forever',
        () async {
          final fakeLocation = _FakeLocationService()
            ..resultToReturn = LocationResult.permissionDeniedForever();
          final fakeGeocoding = _FakeGeocodingService();
          final harness = _Harness(
            locationService: fakeLocation,
            geocodingService: fakeGeocoding,
          );

          await harness.startAndConfirmListening();
          await harness.emitFinalAndComplete('lokasi');

          expect(fakeLocation.callCount, 1);
          expect(fakeGeocoding.callCount, 0);
          expect(
            harness.ttsService.spokenText,
            LocationPermissionMessages.deniedForever,
          );
          harness.controller.dispose();
        },
      );

      test('5. location command speaks error when location service/GPS is disabled', () async {
        final fakeLocation = _FakeLocationService()
          ..resultToReturn = LocationResult.serviceDisabled();
        final fakeGeocoding = _FakeGeocodingService();
        final harness = _Harness(
          locationService: fakeLocation,
          geocodingService: fakeGeocoding,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('saya dimana');

        expect(fakeLocation.callCount, 1);
        expect(fakeGeocoding.callCount, 0);
        expect(
          harness.ttsService.spokenText,
          LocationPermissionMessages.serviceDisabled,
        );
        harness.controller.dispose();
      });

      test('6. location command speaks timeout error when coordinate fetch times out', () async {
        final fakeLocation = _FakeLocationService()
          ..resultToReturn = LocationResult.timeout();
        final fakeGeocoding = _FakeGeocodingService();
        final harness = _Harness(
          locationService: fakeLocation,
          geocodingService: fakeGeocoding,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('lokasi saya');

        expect(fakeLocation.callCount, 1);
        expect(fakeGeocoding.callCount, 0);
        expect(harness.ttsService.spokenText, LocationMessages.timeout);
        harness.controller.dispose();
      });

      test(
        '7. location command speaks failure error when coordinate fetch fails',
        () async {
          final fakeLocation = _FakeLocationService()
            ..resultToReturn = LocationResult.failure(
              'Gagal mengambil koordinat lokasi pengguna.',
            );
          final fakeGeocoding = _FakeGeocodingService();
          final harness = _Harness(
            locationService: fakeLocation,
            geocodingService: fakeGeocoding,
          );

          await harness.startAndConfirmListening();
          await harness.emitFinalAndComplete('posisi saya');

          expect(fakeLocation.callCount, 1);
          expect(fakeGeocoding.callCount, 0);
          expect(
            harness.ttsService.spokenText,
            contains('Gagal mengambil koordinat lokasi pengguna.'),
          );
          harness.controller.dispose();
        },
      );

      test('8. location command speaks error when reverse geocoding returns not found', () async {
        final fakeLocation = _FakeLocationService();
        final fakeGeocoding = _FakeGeocodingService()
          ..resultToReturn = GeocodingResult.notFound();
        final harness = _Harness(
          locationService: fakeLocation,
          geocodingService: fakeGeocoding,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('saya berada di mana');

        expect(fakeLocation.callCount, 1);
        expect(fakeGeocoding.callCount, 1);
        expect(harness.ttsService.spokenText, GeocodingMessages.notFound);
        harness.controller.dispose();
      });

      test('9. location command speaks network error when reverse geocoding network fails', () async {
        final fakeLocation = _FakeLocationService();
        final fakeGeocoding = _FakeGeocodingService()
          ..resultToReturn = GeocodingResult.networkError();
        final harness = _Harness(
          locationService: fakeLocation,
          geocodingService: fakeGeocoding,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('lokasi');

        expect(harness.ttsService.spokenText, GeocodingMessages.networkError);
        harness.controller.dispose();
      });

      test('10. location command speaks unconfigured message without crashing when API is not configured', () async {
        final fakeLocation = _FakeLocationService();
        final fakeGeocoding = _FakeGeocodingService()
          ..resultToReturn = GeocodingResult.unconfigured();
        final harness = _Harness(
          locationService: fakeLocation,
          geocodingService: fakeGeocoding,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('lokasi saya');

        expect(harness.ttsService.spokenText, GeocodingMessages.unconfigured);
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test(
        '11. location command handles exceptions from location service safely',
        () async {
          final fakeLocation = _FakeLocationService()..throwException = true;
          final fakeGeocoding = _FakeGeocodingService();
          final harness = _Harness(
            locationService: fakeLocation,
            geocodingService: fakeGeocoding,
          );

          await harness.startAndConfirmListening();
          await harness.emitFinalAndComplete('lokasi saya');

          expect(
            harness.ttsService.spokenText,
            'Terjadi kesalahan saat memproses informasi lokasi.',
          );
          expect(harness.controller.state, VoiceInteractionState.idle);
          harness.controller.dispose();
        },
      );
    });

    group('weather command (TASK-54)', () {
      test('1. weather command succeeds from parser through VoiceController, gets location & weather, speaks formatted sentence, and transitions processing -> speaking -> idle', () async {
        final fakeLocation = _FakeLocationService();
        final fakeGeocoding = _FakeGeocodingService()
          ..resultToReturn = GeocodingResult.success(
            const LocationAddress(
              subLocality: 'Tembesi',
              district: 'Sagulung',
              city: 'Kota Batam',
              province: 'Kepulauan Riau',
              country: 'Indonesia',
            ),
          );
        final fakeWeather = _FakeWeatherService()
          ..resultToReturn = WeatherResult.success(
            const WeatherData(
              description: 'cerah berawan',
              temperature: 28.4,
              cityName: 'Kangboi',
            ),
          );
        final harness = _Harness(
          locationService: fakeLocation,
          geocodingService: fakeGeocoding,
          weatherService: fakeWeather,
        );

        final observedStates = <VoiceInteractionState>[];
        harness.controller.addListener(() {
          observedStates.add(harness.controller.state);
        });

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeLocation.callCount, 1);
        expect(fakeGeocoding.callCount, 1);
        expect(fakeGeocoding.lastLatitude, 1.1301);
        expect(fakeGeocoding.lastLongitude, 104.0529);
        expect(fakeWeather.callCount, 1);
        expect(fakeWeather.lastLatitude, 1.1301);
        expect(fakeWeather.lastLongitude, 104.0529);

        expect(harness.ttsService.responseCallCount, 1);
        expect(
          harness.ttsService.spokenText,
          'Cuaca di Tembesi, Kecamatan Sagulung, Kota Batam, Kepulauan Riau, Indonesia saat ini cerah berawan dengan suhu 28 derajat Celsius.',
        );
        expect(harness.ttsService.spokenText, isNot(contains('Kangboi')));
        expect(
          observedStates,
          containsAllInOrder([
            VoiceInteractionState.processing,
            VoiceInteractionState.speaking,
            VoiceInteractionState.idle,
          ]),
        );
        expect(harness.controller.state, VoiceInteractionState.idle);
        expect(harness.controller.hasActiveSession, isFalse);
        harness.controller.dispose();
      });

      test('weather command omits location instead of using OpenWeather city when reverse geocoding is unavailable', () async {
        final fakeWeather = _FakeWeatherService()
          ..resultToReturn = WeatherResult.success(
            const WeatherData(
              description: 'awan mendung',
              temperature: 25.0,
              cityName: 'Kangboi',
            ),
          );
        final fakeGeocoding = _FakeGeocodingService()
          ..resultToReturn = GeocodingResult.notFound();
        final harness = _Harness(
          weatherService: fakeWeather,
          geocodingService: fakeGeocoding,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(
          harness.ttsService.spokenText,
          'Cuaca saat ini awan mendung dengan suhu 25 derajat Celsius.',
        );
        expect(harness.ttsService.spokenText, isNot(contains('Kangboi')));
        harness.controller.dispose();
      });

      test('2. weather command works with other weather phrasing like "bagaimana cuaca hari ini" and "ramalan cuaca"', () async {
        final fakeWeather = _FakeWeatherService();
        final harness = _Harness(weatherService: fakeWeather);

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('bagaimana cuaca hari ini');

        expect(fakeWeather.callCount, 1);
        expect(
          harness.ttsService.spokenText,
          'Cuaca di Kota Batam, Kepulauan Riau, Indonesia saat ini cerah berawan dengan suhu 28 derajat Celsius.',
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('ramalan cuaca');

        expect(fakeWeather.callCount, 2);
        harness.controller.dispose();
      });

      test(
        '3. weather command speaks error when location permission is denied',
        () async {
          final fakeLocation = _FakeLocationService()
            ..resultToReturn = LocationResult.permissionDenied();
          final fakeWeather = _FakeWeatherService();
          final harness = _Harness(
            locationService: fakeLocation,
            weatherService: fakeWeather,
          );

          await harness.startAndConfirmListening();
          await harness.emitFinalAndComplete('cuaca');

          expect(fakeLocation.callCount, 1);
          expect(fakeWeather.callCount, 0);
          expect(
            harness.ttsService.spokenText,
            LocationPermissionMessages.denied,
          );
          expect(harness.controller.state, VoiceInteractionState.idle);
          harness.controller.dispose();
        },
      );

      test('4. weather command speaks error when location permission is denied forever', () async {
        final fakeLocation = _FakeLocationService()
          ..resultToReturn = LocationResult.permissionDeniedForever();
        final fakeWeather = _FakeWeatherService();
        final harness = _Harness(
          locationService: fakeLocation,
          weatherService: fakeWeather,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeLocation.callCount, 1);
        expect(fakeWeather.callCount, 0);
        expect(
          harness.ttsService.spokenText,
          LocationPermissionMessages.deniedForever,
        );
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test(
        '5. weather command speaks error when location service is disabled',
        () async {
          final fakeLocation = _FakeLocationService()
            ..resultToReturn = LocationResult.serviceDisabled();
          final fakeWeather = _FakeWeatherService();
          final harness = _Harness(
            locationService: fakeLocation,
            weatherService: fakeWeather,
          );

          await harness.startAndConfirmListening();
          await harness.emitFinalAndComplete('cuaca');

          expect(fakeLocation.callCount, 1);
          expect(fakeWeather.callCount, 0);
          expect(
            harness.ttsService.spokenText,
            LocationPermissionMessages.serviceDisabled,
          );
          expect(harness.controller.state, VoiceInteractionState.idle);
          harness.controller.dispose();
        },
      );

      test(
        '6. weather command speaks error when location request times out',
        () async {
          final fakeLocation = _FakeLocationService()
            ..resultToReturn = LocationResult.timeout();
          final fakeWeather = _FakeWeatherService();
          final harness = _Harness(
            locationService: fakeLocation,
            weatherService: fakeWeather,
          );

          await harness.startAndConfirmListening();
          await harness.emitFinalAndComplete('cuaca');

          expect(fakeLocation.callCount, 1);
          expect(fakeWeather.callCount, 0);
          expect(harness.ttsService.spokenText, LocationMessages.timeout);
          expect(harness.controller.state, VoiceInteractionState.idle);
          harness.controller.dispose();
        },
      );

      test('7. weather command speaks error when location fails', () async {
        final fakeLocation = _FakeLocationService()
          ..resultToReturn = LocationResult.failure(LocationMessages.failure);
        final fakeWeather = _FakeWeatherService();
        final harness = _Harness(
          locationService: fakeLocation,
          weatherService: fakeWeather,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeLocation.callCount, 1);
        expect(fakeWeather.callCount, 0);
        expect(harness.ttsService.spokenText, LocationMessages.failure);
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test('8. weather command speaks unconfigured message when API key is missing', () async {
        final fakeWeather = _FakeWeatherService()
          ..resultToReturn = WeatherResult.unconfigured();
        final harness = _Harness(weatherService: fakeWeather);

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeWeather.callCount, 1);
        expect(harness.ttsService.spokenText, WeatherMessages.unconfigured);
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test('9. weather command speaks unauthorized message when API key is invalid', () async {
        final fakeWeather = _FakeWeatherService()
          ..resultToReturn = WeatherResult.unauthorized();
        final harness = _Harness(weatherService: fakeWeather);

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeWeather.callCount, 1);
        expect(harness.ttsService.spokenText, WeatherMessages.unauthorized);
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test(
        '10. weather command speaks rate limited message when quota exceeded',
        () async {
          final fakeWeather = _FakeWeatherService()
            ..resultToReturn = WeatherResult.rateLimited();
          final harness = _Harness(weatherService: fakeWeather);

          await harness.startAndConfirmListening();
          await harness.emitFinalAndComplete('cuaca');

          expect(fakeWeather.callCount, 1);
          expect(harness.ttsService.spokenText, WeatherMessages.rateLimited);
          expect(harness.controller.state, VoiceInteractionState.idle);
          harness.controller.dispose();
        },
      );

      test('11. weather command speaks not found message when location weather is not found', () async {
        final fakeWeather = _FakeWeatherService()
          ..resultToReturn = WeatherResult.notFound();
        final harness = _Harness(weatherService: fakeWeather);

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeWeather.callCount, 1);
        expect(harness.ttsService.spokenText, WeatherMessages.notFound);
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test('12. weather command speaks timeout message when weather request times out', () async {
        final fakeWeather = _FakeWeatherService()
          ..resultToReturn = WeatherResult.timeout();
        final harness = _Harness(weatherService: fakeWeather);

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeWeather.callCount, 1);
        expect(harness.ttsService.spokenText, WeatherMessages.timeout);
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test('13. weather command speaks network error when weather connection fails', () async {
        final fakeWeather = _FakeWeatherService()
          ..resultToReturn = WeatherResult.networkError();
        final harness = _Harness(weatherService: fakeWeather);

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeWeather.callCount, 1);
        expect(harness.ttsService.spokenText, WeatherMessages.networkError);
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test('14. weather command speaks API error when weather service returns api error', () async {
        final fakeWeather = _FakeWeatherService()
          ..resultToReturn = WeatherResult.apiError();
        final harness = _Harness(weatherService: fakeWeather);

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeWeather.callCount, 1);
        expect(harness.ttsService.spokenText, WeatherMessages.apiError);
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test('15. weather command speaks failure message when weather service reports generic failure', () async {
        final fakeWeather = _FakeWeatherService()
          ..resultToReturn = WeatherResult.failure(WeatherMessages.failure);
        final harness = _Harness(weatherService: fakeWeather);

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeWeather.callCount, 1);
        expect(harness.ttsService.spokenText, WeatherMessages.failure);
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test('16. weather command handles unexpected exceptions from LocationService safely', () async {
        final fakeLocation = _FakeLocationService()..throwException = true;
        final fakeWeather = _FakeWeatherService();
        final harness = _Harness(
          locationService: fakeLocation,
          weatherService: fakeWeather,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeWeather.callCount, 0);
        expect(
          harness.ttsService.spokenText,
          'Terjadi kesalahan saat memproses informasi cuaca.',
        );
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test('17. weather command handles unexpected exceptions from WeatherService safely', () async {
        final fakeWeather = _FakeWeatherService()..throwException = true;
        final harness = _Harness(weatherService: fakeWeather);

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeWeather.callCount, 1);
        expect(
          harness.ttsService.spokenText,
          'Terjadi kesalahan saat memproses informasi cuaca.',
        );
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test('18. cancel during weather processing aborts speaking and returns to idle', () async {
        final fakeWeather = _FakeWeatherService()
          ..pendingResult = Completer<WeatherResult>();
        final harness = _Harness(weatherService: fakeWeather);

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('cuaca');

        expect(fakeWeather.callCount, 1);
        expect(harness.controller.state, VoiceInteractionState.processing);

        await harness.controller.cancel();
        expect(harness.controller.state, VoiceInteractionState.idle);

        fakeWeather.pendingResult!.complete(fakeWeather.resultToReturn);
        await Future<void>.delayed(Duration.zero);

        expect(harness.ttsService.spokenTexts, [AppStrings.voiceConfirmation]);
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test(
        '19. cancel during location retrieval aborts weather call and TTS',
        () async {
          final fakeLocation = _FakeLocationService()
            ..pendingResult = Completer<LocationResult>();
          final fakeWeather = _FakeWeatherService();
          final harness = _Harness(
            locationService: fakeLocation,
            weatherService: fakeWeather,
          );

          await harness.startAndConfirmListening();
          await harness.emitFinalAndComplete('cuaca');

          expect(fakeLocation.callCount, 1);
          expect(harness.controller.state, VoiceInteractionState.processing);

          await harness.controller.cancel();
          expect(harness.controller.state, VoiceInteractionState.idle);

          fakeLocation.pendingResult!.complete(fakeLocation.resultToReturn);
          await Future<void>.delayed(Duration.zero);

          expect(fakeWeather.callCount, 0);
          expect(harness.ttsService.spokenTexts, [
            AppStrings.voiceConfirmation,
          ]);
          expect(harness.controller.state, VoiceInteractionState.idle);
          harness.controller.dispose();
        },
      );

      test('20. non-weather commands (day, date, time, location, unknown) continue working without interference', () async {
        final harness = _Harness();

        // 1. day
        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('hari ini');
        expect(harness.ttsService.spokenText, 'Hari ini hari Jumat.');

        // 2. date
        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('tanggal berapa');
        expect(
          harness.ttsService.spokenText,
          'Hari ini tanggal 16 Oktober 2026.',
        );

        // 3. time
        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('jam berapa');
        expect(harness.ttsService.spokenText, contains('pukul'));

        // 4. location
        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('lokasi');
        expect(
          harness.ttsService.spokenText,
          'Anda berada di Kota Batam, Kepulauan Riau, Indonesia.',
        );

        // 5. unknown
        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('buka youtube dong');
        expect(
          harness.ttsService.spokenText,
          VoiceController.unsupportedCommandResponse,
        );

        harness.controller.dispose();
      });
    });
  });
}
