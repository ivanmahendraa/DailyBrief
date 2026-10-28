import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:daily_brief/core/constants/app_strings.dart';
import 'package:daily_brief/features/voice/command_parser.dart';
import 'package:daily_brief/features/voice/voice_controller.dart';
import 'package:daily_brief/services/command_history_service.dart';
import 'package:daily_brief/services/geocoding_service.dart';
import 'package:daily_brief/services/location_service.dart';
import 'package:daily_brief/services/speech_to_text_service.dart';
import 'package:daily_brief/services/tts_service.dart';

Position _createPosition({
  double latitude = 1.1301,
  double longitude = 104.0529,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 10, 23, 20, 0),
    accuracy: 5.0,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

class _NoOpCommandHistoryWriter implements CommandHistoryWriter {
  @override
  Future<void> record(VoiceCommand command) async {}
}

class _StubTtsClient implements TtsClient {
  const _StubTtsClient();

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> isLanguageAvailable(String language) async => 1;

  @override
  void setCancelHandler(void Function() callback) {}

  @override
  void setCompletionHandler(void Function() callback) {}

  @override
  void setErrorHandler(void Function(dynamic message) callback) {}

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  void setStartHandler(void Function() callback) {}

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> speak(String text) async => 1;

  @override
  Future<dynamic> stop() async => 1;
}

class _IntegrationSpeechClient implements SpeechToTextClient {
  void Function(String status)? onStatus;
  void Function(String message, bool isPermanent)? onError;
  SpeechResultCallback? onResult;
  int listenCallCount = 0;
  int cancelCallCount = 0;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message, bool isPermanent) onError,
  }) async {
    this.onStatus = onStatus;
    this.onError = onError;
    return true;
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
    this.onResult = onResult;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {
    cancelCallCount++;
  }

  void emitStatus(String status) => onStatus?.call(status);

  void emitResult(String words) => onResult?.call(
    SpeechRecognitionResult(recognizedWords: words, isFinal: true),
  );
}

class _IntegrationTtsService extends TtsService {
  final List<String> spokenTexts = [];
  Completer<TtsPlaybackResult>? pendingResponse;
  bool speaking = false;

  _IntegrationTtsService() : super(client: const _StubTtsClient());

  @override
  bool get isReady => true;

  @override
  bool get isSpeaking => speaking;

  String? get lastSpokenResponse {
    final nonConfirmation = spokenTexts
        .where((t) => t != AppStrings.voiceConfirmation)
        .toList();
    return nonConfirmation.isNotEmpty ? nonConfirmation.last : null;
  }

  @override
  Future<bool> initialize({
    String language = TtsService.defaultLanguage,
    double speechRate = TtsService.defaultSpeechRate,
    double volume = TtsService.defaultVolume,
    double pitch = TtsService.defaultPitch,
  }) async => true;

  @override
  Future<TtsPlaybackResult> speak(String text) async {
    spokenTexts.add(text);
    speaking = true;

    if (text != AppStrings.voiceConfirmation && pendingResponse != null) {
      final res = await pendingResponse!.future;
      speaking = false;
      return res;
    }

    speaking = false;
    return TtsPlaybackResult.success();
  }

  @override
  Future<void> stop() async {
    speaking = false;
    if (pendingResponse != null && !pendingResponse!.isCompleted) {
      pendingResponse!.complete(TtsPlaybackResult.cancelled());
    }
  }
}

class _IntegrationLocationClient implements LocationClient {
  bool serviceEnabled = true;
  LocationPermission checkPermissionValue = LocationPermission.whileInUse;
  LocationPermission requestPermissionValue = LocationPermission.whileInUse;
  Position mockPosition = _createPosition();
  Duration? delay;
  bool throwOnGetPosition = false;
  bool throwTimeout = false;

  int checkCallCount = 0;
  int requestCallCount = 0;
  int getPositionCallCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    checkCallCount++;
    return checkPermissionValue;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestCallCount++;
    return requestPermissionValue;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    getPositionCallCount++;
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (throwTimeout) {
      throw TimeoutException('Coordinate fetch timed out');
    }
    if (throwOnGetPosition) {
      throw StateError('Position retrieval failed');
    }
    return mockPosition;
  }
}

class _IntegrationGeocodingClient implements GeocodingClient {
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

  @override
  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    callCount++;
    lastLatitude = latitude;
    lastLongitude = longitude;
    if (throwException) {
      throw StateError('Geocoding service network crash');
    }
    return resultToReturn;
  }
}

class _LocationTestFixture {
  final speechClient = _IntegrationSpeechClient();
  final ttsService = _IntegrationTtsService();
  final locationClient = _IntegrationLocationClient();
  final geocodingClient = _IntegrationGeocodingClient();

  late final LocationService locationService = LocationService(locationClient);
  late final GeocodingService geocodingService = GeocodingService(
    geocodingClient,
  );
  late final SpeechToTextService speechService = SpeechToTextService(
    client: speechClient,
  );

  late final VoiceController controller = VoiceController(
    speechToTextService: speechService,
    ttsService: ttsService,
    locationService: locationService,
    geocodingService: geocodingService,
    commandHistoryWriter: _NoOpCommandHistoryWriter(),
  );

  Future<void> startAndConfirmListening() async {
    final startFuture = controller.startListening();
    while (speechClient.listenCallCount == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    speechClient.emitStatus('listening');
    await startFuture;
  }

  Future<void> emitCommandAndComplete(String utterance) async {
    speechClient.emitResult(utterance);
    speechClient.emitStatus('done');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  void dispose() {
    controller.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK-49: Integrated Location Feature Tests', () {
    late _LocationTestFixture fixture;

    setUp(() {
      fixture = _LocationTestFixture();
    });

    tearDown(() {
      fixture.dispose();
    });

    group('Alur Sukses (End-to-End Success Flow)', () {
      test('Perintah suara lokasi -> CommandParser -> VoiceController -> LocationService -> GeocodingService -> TTS -> idle', () async {
        await fixture.startAndConfirmListening();
        expect(fixture.controller.state, VoiceInteractionState.listening);

        await fixture.emitCommandAndComplete('saya di mana sekarang');

        expect(fixture.locationClient.getPositionCallCount, 1);
        expect(fixture.geocodingClient.callCount, 1);
        expect(fixture.geocodingClient.lastLatitude, 1.1301);
        expect(fixture.geocodingClient.lastLongitude, 104.0529);

        expect(
          fixture.ttsService.lastSpokenResponse,
          'Anda berada di Kota Batam, Kepulauan Riau, Indonesia.',
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
        expect(fixture.controller.hasActiveSession, isFalse);
      });

      test(
        'Alur sukses lokasi umum (hanya kota dan provinsi tanpa placeName)',
        () async {
          fixture.geocodingClient.resultToReturn = GeocodingResult.success(
            const LocationAddress(city: 'Batam', province: 'Kepulauan Riau'),
          );

          await fixture.startAndConfirmListening();
          await fixture.emitCommandAndComplete('posisi saya');

          expect(
            fixture.ttsService.lastSpokenResponse,
            'Anda berada di Batam, Kepulauan Riau.',
          );
          expect(fixture.controller.state, VoiceInteractionState.idle);
        },
      );

      test(
        'respons lokasi hanya memakai komponen administratif yang diizinkan',
        () async {
          fixture.geocodingClient.resultToReturn = GeocodingResult.success(
            const LocationAddress(
              street: '22C4+R39',
              streetNumber: '22C4+R39',
              subLocality: 'Tembesi',
              district: 'Sagulung',
              city: 'Kota Batam',
              province: 'Kepulauan Riau',
              country: 'Indonesia',
              formattedAddress: '22C4+R39, Tembesi, Kec. Sagulung, Kota Batam, Kepulauan Riau 29472, Indonesia',
            ),
          );

          await fixture.startAndConfirmListening();
          await fixture.emitCommandAndComplete('lokasi saya');

          expect(
            fixture.ttsService.lastSpokenResponse,
            'Anda berada di Tembesi, Kecamatan Sagulung, Kota Batam, Kepulauan Riau, Indonesia.',
          );
          expect(
            fixture.ttsService.lastSpokenResponse,
            isNot(contains('22C4+R39')),
          );
          expect(
            fixture.ttsService.lastSpokenResponse,
            isNot(contains('29472')),
          );
          expect(
            fixture.ttsService.lastSpokenResponse,
            isNot(contains('Jalan')),
          );
        },
      );

      test(
        'alamat sukses tanpa komponen alamat memakai fallback aman',
        () async {
          fixture.geocodingClient.resultToReturn = GeocodingResult.success(
            const LocationAddress(),
          );

          await fixture.startAndConfirmListening();
          await fixture.emitCommandAndComplete('lokasi saya');

          expect(
            fixture.ttsService.lastSpokenResponse,
            'Maaf, nama lokasi belum berhasil diketahui.',
          );
          expect(fixture.controller.state, VoiceInteractionState.idle);
        },
      );

      test('Verifikasi transisi state lengkap: listening -> processing -> speaking -> idle', () async {
        final ttsCompleter = Completer<TtsPlaybackResult>();
        fixture.ttsService.pendingResponse = ttsCompleter;

        await fixture.startAndConfirmListening();
        expect(fixture.controller.state, VoiceInteractionState.listening);

        fixture.speechClient.emitResult('lokasi saya');
        fixture.speechClient.emitStatus('done');

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(fixture.controller.state, VoiceInteractionState.speaking);

        ttsCompleter.complete(TtsPlaybackResult.success());
        await Future<void>.delayed(Duration.zero);

        expect(fixture.controller.state, VoiceInteractionState.idle);
      });
    });

    group('Uji Kegagalan Layanan Lokasi (Location Failure Scenarios)', () {
      test('1. Izin lokasi ditolak (permission denied)', () async {
        fixture.locationClient.checkPermissionValue = LocationPermission.denied;
        fixture.locationClient.requestPermissionValue =
            LocationPermission.denied;

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('lokasi');

        expect(fixture.locationClient.getPositionCallCount, 0);
        expect(fixture.geocodingClient.callCount, 0);
        expect(
          fixture.ttsService.lastSpokenResponse,
          LocationPermissionMessages.denied,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('2. Izin lokasi ditolak permanen (deniedForever)', () async {
        fixture.locationClient.checkPermissionValue =
            LocationPermission.deniedForever;

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('lokasi saya');

        expect(fixture.locationClient.requestCallCount, 0);
        expect(fixture.locationClient.getPositionCallCount, 0);
        expect(fixture.geocodingClient.callCount, 0);
        expect(
          fixture.ttsService.lastSpokenResponse,
          LocationPermissionMessages.deniedForever,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('3. Layanan GPS / lokasi nonaktif (serviceDisabled)', () async {
        fixture.locationClient.serviceEnabled = false;

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('dimana saya');

        expect(fixture.locationClient.getPositionCallCount, 0);
        expect(fixture.geocodingClient.callCount, 0);
        expect(
          fixture.ttsService.lastSpokenResponse,
          LocationPermissionMessages.serviceDisabled,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('4. Batas waktu pengambilan koordinat habis (timeout)', () async {
        fixture.locationClient.throwTimeout = true;

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('lokasi');

        expect(fixture.geocodingClient.callCount, 0);
        expect(fixture.ttsService.lastSpokenResponse, LocationMessages.timeout);
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test(
        '5. Kegagalan pengambilan posisi dari platform geolocator',
        () async {
          fixture.locationClient.throwOnGetPosition = true;

          await fixture.startAndConfirmListening();
          await fixture.emitCommandAndComplete('saya berada di mana');

          expect(fixture.geocodingClient.callCount, 0);
          expect(
            fixture.ttsService.lastSpokenResponse,
            contains(LocationMessages.failure),
          );
          expect(fixture.controller.state, VoiceInteractionState.idle);
        },
      );

      test('6. Reverse geocoding mengembalikan notFound', () async {
        fixture.geocodingClient.resultToReturn = GeocodingResult.notFound();

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('di mana saya');

        expect(fixture.locationClient.getPositionCallCount, 1);
        expect(fixture.geocodingClient.callCount, 1);
        expect(
          fixture.ttsService.lastSpokenResponse,
          GeocodingMessages.notFound,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('7. Reverse geocoding mengalami networkError', () async {
        fixture.geocodingClient.resultToReturn = GeocodingResult.networkError();

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('lokasi saya');

        expect(
          fixture.ttsService.lastSpokenResponse,
          GeocodingMessages.networkError,
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test('8. Reverse geocoding mengalami apiError', () async {
        fixture.geocodingClient.resultToReturn = GeocodingResult.apiError(
          'Layanan geocoding ditolak: OVER_QUERY_LIMIT',
        );

        await fixture.startAndConfirmListening();
        await fixture.emitCommandAndComplete('saya di mana');

        expect(
          fixture.ttsService.lastSpokenResponse,
          contains('OVER_QUERY_LIMIT'),
        );
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });

      test(
        '9. Geocoding belum dikonfigurasi dengan API key (unconfigured)',
        () async {
          fixture.geocodingClient.resultToReturn =
              GeocodingResult.unconfigured();

          await fixture.startAndConfirmListening();
          await fixture.emitCommandAndComplete('posisi saya');

          expect(
            fixture.ttsService.lastSpokenResponse,
            GeocodingMessages.unconfigured,
          );
          expect(fixture.controller.state, VoiceInteractionState.idle);
        },
      );

      test(
        '10. Exception tak terduga pada GeocodingService ditangani dengan aman',
        () async {
          fixture.geocodingClient.throwException = true;

          await fixture.startAndConfirmListening();
          await fixture.emitCommandAndComplete('lokasi');

          expect(
            fixture.ttsService.lastSpokenResponse,
            contains(GeocodingMessages.failure),
          );
          expect(fixture.controller.state, VoiceInteractionState.idle);
        },
      );

      test('11. Pembatalan sesi di tengah pengambilan lokasi menghentikan respons suara', () async {
        fixture.locationClient.delay = const Duration(milliseconds: 100);

        await fixture.startAndConfirmListening();
        fixture.speechClient.emitResult('lokasi');
        fixture.speechClient.emitStatus('done');

        await Future<void>.delayed(const Duration(milliseconds: 20));
        await fixture.controller.cancel();

        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(fixture.ttsService.lastSpokenResponse, isNull);
        expect(fixture.controller.state, VoiceInteractionState.idle);
      });
    });
  });
}
