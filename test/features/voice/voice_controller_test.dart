import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/features/voice/voice_controller.dart';
import 'package:daily_brief/services/date_time_service.dart';
import 'package:daily_brief/services/geocoding_service.dart';
import 'package:daily_brief/services/location_service.dart';
import 'package:daily_brief/services/speech_to_text_service.dart';
import 'package:daily_brief/services/tts_service.dart';

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

  _FakeLocationService() : super();

  @override
  Future<LocationResult> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
    LocationSettings? locationSettings,
  }) async {
    callCount++;
    if (throwException) throw StateError('LocationService crashed');
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
      formattedAddress: 'Jl. Engku Putri, Batam',
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

class _Harness {
  _Harness({
    DateTimeService? dateTimeService,
    LocationService? locationService,
    GeocodingService? geocodingService,
  }) : dateTimeService =
           dateTimeService ?? DateTimeService(now: () => DateTime(2026, 10, 16)),
       locationService = locationService ?? _FakeLocationService(),
       geocodingService = geocodingService ?? _FakeGeocodingService();

  final _FakeSpeechToTextClient speechClient = _FakeSpeechToTextClient();
  final _FakeTtsService ttsService = _FakeTtsService();
  final DateTimeService dateTimeService;
  final LocationService locationService;
  final GeocodingService geocodingService;
  late final SpeechToTextService speechService = SpeechToTextService(
    client: speechClient,
  );
  late final VoiceController controller = VoiceController(
    dateTimeService: dateTimeService,
    speechToTextService: speechService,
    ttsService: ttsService,
    locationService: locationService,
    geocodingService: geocodingService,
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
      harness.controller.dispose();
    });

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
          'Lokasi Anda berada di sekitar Mega Mall Batam, Kota Batam.',
        );
        expect(harness.controller.state, VoiceInteractionState.idle);
        expect(harness.controller.hasActiveSession, isFalse);
        harness.controller.dispose();
      });

      test('2. location command speaks response without placeName when only city is available', () async {
        final fakeLocation = _FakeLocationService();
        final fakeGeocoding = _FakeGeocodingService()
          ..resultToReturn = GeocodingResult.success(
            const LocationAddress(
              city: 'Batam',
              province: 'Kepulauan Riau',
            ),
          );
        final harness = _Harness(
          locationService: fakeLocation,
          geocodingService: fakeGeocoding,
        );

        await harness.startAndConfirmListening();
        await harness.emitFinalAndComplete('di mana saya');

        expect(
          harness.ttsService.spokenText,
          'Lokasi Anda berada di Batam, Kepulauan Riau.',
        );
        harness.controller.dispose();
      });

      test('3. location command speaks error when permission is denied', () async {
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
      });

      test('4. location command speaks error when permission is denied forever', () async {
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
      });

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
        expect(
          harness.ttsService.spokenText,
          LocationMessages.timeout,
        );
        harness.controller.dispose();
      });

      test('7. location command speaks failure error when coordinate fetch fails', () async {
        final fakeLocation = _FakeLocationService()
          ..resultToReturn = LocationResult.failure('Gagal mengambil koordinat lokasi pengguna.');
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
      });

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
        expect(
          harness.ttsService.spokenText,
          GeocodingMessages.notFound,
        );
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

        expect(
          harness.ttsService.spokenText,
          GeocodingMessages.networkError,
        );
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

        expect(
          harness.ttsService.spokenText,
          GeocodingMessages.unconfigured,
        );
        expect(harness.controller.state, VoiceInteractionState.idle);
        harness.controller.dispose();
      });

      test('11. location command handles exceptions from location service safely', () async {
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
      });
    });
  });
}
