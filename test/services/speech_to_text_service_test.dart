import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/services/speech_to_text_service.dart';

class _FakeSpeechToTextClient implements SpeechToTextClient {
  bool initializationAvailable = true;
  bool permissionGranted = true;
  bool throwOnInitialize = false;
  bool throwOnListen = false;
  int initializeCallCount = 0;
  int listenCallCount = 0;
  int stopCallCount = 0;
  int cancelCallCount = 0;
  String? lastLocaleId;
  List<SpeechLocale> availableLocales = const [
    SpeechLocale(localeId: 'id-ID', name: 'Indonesian'),
  ];

  void Function(String status)? statusListener;
  void Function(String message, bool isPermanent)? errorListener;
  SpeechResultCallback? resultListener;

  @override
  Future<bool> get hasPermission async => permissionGranted;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String message, bool isPermanent) onError,
  }) async {
    initializeCallCount++;
    statusListener = onStatus;
    errorListener = onError;
    if (throwOnInitialize) throw StateError('initialize failed');
    return initializationAvailable;
  }

  @override
  Future<List<SpeechLocale>> locales() async => availableLocales;

  @override
  Future<void> listen({
    required String? localeId,
    required SpeechResultCallback onResult,
  }) async {
    listenCallCount++;
    lastLocaleId = localeId;
    resultListener = onResult;
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

  void emitStatus(String status) => statusListener?.call(status);

  void emitError(String message, {bool permanent = false}) =>
      errorListener?.call(message, permanent);

  void emitResult(String words, {required bool isFinal}) => resultListener
      ?.call(SpeechRecognitionResult(recognizedWords: words, isFinal: isFinal));
}

void main() {
  group('SpeechToTextService', () {
    test(
      'construction and permission inspection do not initialize or prompt',
      () async {
        final client = _FakeSpeechToTextClient();
        final service = SpeechToTextService(client: client);

        expect(client.initializeCallCount, 0);
        expect(await service.hasPermission, isTrue);
        expect(client.initializeCallCount, 0);
        expect(service.state, SpeechToTextState.uninitialized);
      },
    );

    test(
      'initializes once and reports ready when recognition is available',
      () async {
        final client = _FakeSpeechToTextClient();
        final service = SpeechToTextService(client: client);

        final first = await service.initialize();
        final second = await service.initialize();

        expect(first, SpeechInitializationStatus.ready);
        expect(second, SpeechInitializationStatus.ready);
        expect(client.initializeCallCount, 1);
        expect(service.state, SpeechToTextState.ready);
      },
    );

    test(
      'reports unavailable when the platform recognizer is not available',
      () async {
        final client = _FakeSpeechToTextClient()
          ..initializationAvailable = false;
        final service = SpeechToTextService(client: client);

        final result = await service.initialize();

        expect(result, SpeechInitializationStatus.unavailable);
        expect(service.state, SpeechToTextState.unavailable);
      },
    );

    test('reports permission denied after initialization is refused', () async {
      final client = _FakeSpeechToTextClient()
        ..initializationAvailable = false
        ..permissionGranted = false;
      final service = SpeechToTextService(client: client);

      final result = await service.initialize();

      expect(result, SpeechInitializationStatus.permissionDenied);
      expect(service.state, SpeechToTextState.unavailable);
    });

    test('maps the recognizer permission error to permissionDenied', () async {
      final client = _FakeSpeechToTextClient();
      final service = SpeechToTextService(client: client);

      final initialization = service.initialize();
      client.emitError('error_permission', permanent: true);
      final result = await initialization;

      expect(result, SpeechInitializationStatus.permissionDenied);
      expect(service.state, SpeechToTextState.error);
      expect(service.lastError?.message, 'error_permission');
    });

    test('reports an initialization exception as a typed error', () async {
      final client = _FakeSpeechToTextClient()..throwOnInitialize = true;
      final service = SpeechToTextService(client: client);

      final result = await service.initialize();

      expect(result, SpeechInitializationStatus.error);
      expect(service.state, SpeechToTextState.error);
      expect(service.lastError?.message, contains('initialize failed'));
    });

    test(
      'requests listening with Indonesian locale but waits for engine status',
      () async {
        final client = _FakeSpeechToTextClient()
          ..availableLocales = const [
            SpeechLocale(localeId: 'en-US', name: 'English'),
            SpeechLocale(localeId: 'id_ID', name: 'Indonesian'),
          ];
        final service = SpeechToTextService(client: client);

        final result = await service.startListening(onResult: (_) {});

        expect(result, SpeechStartResult.requested);
        expect(client.initializeCallCount, 1);
        expect(client.listenCallCount, 1);
        expect(client.lastLocaleId, 'id_ID');
        expect(service.state, SpeechToTextState.starting);
        expect(service.isListening, isFalse);

        client.emitStatus('listening');
        expect(service.engineStatus, SpeechEngineStatus.listening);
        expect(service.state, SpeechToTextState.listening);
        expect(service.isListening, isTrue);
      },
    );

    test('uses device default locale when Indonesian is unavailable', () async {
      final client = _FakeSpeechToTextClient()
        ..availableLocales = const [
          SpeechLocale(localeId: 'en-US', name: 'English'),
        ];
      final service = SpeechToTextService(client: client);

      final result = await service.startListening(onResult: (_) {});

      expect(result, SpeechStartResult.requested);
      expect(client.lastLocaleId, isNull);
    });

    test('forwards partial and final recognized results distinctly', () async {
      final client = _FakeSpeechToTextClient();
      final service = SpeechToTextService(client: client);
      final results = <SpeechRecognitionResult>[];

      await service.startListening(onResult: results.add);
      client.emitStatus('listening');
      client.emitResult('cuac', isFinal: false);
      client.emitResult('cuaca', isFinal: true);

      expect(results, hasLength(2));
      expect(results[0].recognizedWords, 'cuac');
      expect(results[0].isFinal, isFalse);
      expect(results[1].recognizedWords, 'cuaca');
      expect(results[1].isFinal, isTrue);
    });

    test('stop waits for engine statuses and cleans up on done', () async {
      final client = _FakeSpeechToTextClient();
      final service = SpeechToTextService(client: client);
      final statuses = <SpeechEngineStatus>[];

      await service.startListening(onResult: (_) {}, onStatus: statuses.add);
      client.emitStatus('listening');
      await service.stopListening();

      expect(client.stopCallCount, 1);
      expect(service.state, SpeechToTextState.stopping);
      client.emitStatus('notListening');
      expect(service.engineStatus, SpeechEngineStatus.notListening);
      client.emitStatus('done');

      expect(statuses, [
        SpeechEngineStatus.listening,
        SpeechEngineStatus.notListening,
        SpeechEngineStatus.done,
      ]);
      expect(service.state, SpeechToTextState.completed);
      expect(service.hasActiveSession, isFalse);

      client.emitResult('late result', isFinal: true);
      expect(statuses.length, 3);
    });

    test('cancel ends the session and clears active state', () async {
      final client = _FakeSpeechToTextClient();
      final service = SpeechToTextService(client: client);

      await service.startListening(onResult: (_) {});
      client.emitStatus('listening');
      await service.cancelListening();

      expect(client.cancelCallCount, 1);
      expect(service.state, SpeechToTextState.cancelled);
      expect(service.hasActiveSession, isFalse);
      expect(service.isListening, isFalse);
    });

    test('engine error is typed and triggers session cleanup', () async {
      final client = _FakeSpeechToTextClient();
      final service = SpeechToTextService(client: client);
      SpeechRecognitionError? receivedError;

      await service.startListening(
        onResult: (_) {},
        onError: (error) => receivedError = error,
      );
      client.emitStatus('listening');
      client.emitError('error_network', permanent: true);
      await Future<void>.delayed(Duration.zero);

      expect(receivedError?.message, 'error_network');
      expect(receivedError?.isPermanent, isTrue);
      expect(service.state, SpeechToTextState.error);
      expect(service.lastError, receivedError);
      expect(client.cancelCallCount, 1);
      expect(service.hasActiveSession, isFalse);
    });

    test(
      'a listen exception fails the request and cleans up the partial session',
      () async {
        final client = _FakeSpeechToTextClient()..throwOnListen = true;
        final service = SpeechToTextService(client: client);
        SpeechRecognitionError? receivedError;

        final result = await service.startListening(
          onResult: (_) {},
          onError: (error) => receivedError = error,
        );

        expect(result, SpeechStartResult.failed);
        expect(receivedError?.message, contains('listen failed'));
        expect(service.state, SpeechToTextState.error);
        expect(client.cancelCallCount, 1);
        expect(service.hasActiveSession, isFalse);
      },
    );

    test('overlapping start requests do not start a second session', () async {
      final client = _FakeSpeechToTextClient();
      final service = SpeechToTextService(client: client);

      final first = await service.startListening(onResult: (_) {});
      final second = await service.startListening(onResult: (_) {});

      expect(first, SpeechStartResult.requested);
      expect(second, SpeechStartResult.alreadyActive);
      expect(client.initializeCallCount, 1);
      expect(client.listenCallCount, 1);
      expect(service.hasActiveSession, isTrue);
    });
  });
}
