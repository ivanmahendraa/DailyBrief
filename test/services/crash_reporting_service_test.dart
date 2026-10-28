import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/services/crash_reporting_service.dart';

class _FakeCrashErrorReporter implements CrashErrorReporter {
  bool? collectionEnabled;
  final List<({Object error, StackTrace stackTrace, bool fatal})> errors = [];

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    errors.add((
      error: details.exception,
      stackTrace: details.stack ?? StackTrace.empty,
      fatal: true,
    ));
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    required bool fatal,
  }) async {
    errors.add((error: error, stackTrace: stackTrace, fatal: fatal));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrashReportingService', () {
    late FlutterExceptionHandler? previousFlutterErrorHandler;
    late bool Function(Object, StackTrace)? previousPlatformErrorHandler;

    setUp(() {
      previousFlutterErrorHandler = FlutterError.onError;
      previousPlatformErrorHandler = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = previousFlutterErrorHandler;
      PlatformDispatcher.instance.onError = previousPlatformErrorHandler;
    });

    test(
      'records framework exceptions as fatal errors without losing details',
      () async {
        final reporter = _FakeCrashErrorReporter();
        final presentedErrors = <FlutterErrorDetails>[];
        await CrashReportingService(
          reporter: reporter,
          presentFlutterError: presentedErrors.add,
        ).initialize(collectionEnabled: false);

        final stackTrace = StackTrace.current;
        FlutterError.onError!(
          FlutterErrorDetails(
            exception: StateError('private speech transcript'),
            stack: stackTrace,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(reporter.collectionEnabled, isFalse);
        expect(presentedErrors, hasLength(1));
        expect(reporter.errors, hasLength(1));
        expect(reporter.errors.single.error, isA<StateError>());
        expect(
          reporter.errors.single.error.toString(),
          contains('private speech transcript'),
        );
        expect(reporter.errors.single.stackTrace, stackTrace);
        expect(reporter.errors.single.fatal, isTrue);
      },
    );

    test('records original uncaught asynchronous errors as fatal', () async {
      final reporter = _FakeCrashErrorReporter();
      await CrashReportingService(
        reporter: reporter,
        presentFlutterError: (_) {},
      ).initialize(collectionEnabled: true);

      final stackTrace = StackTrace.current;
      final handled = PlatformDispatcher.instance.onError!(
        StateError('private location coordinates'),
        stackTrace,
      );
      await Future<void>.delayed(Duration.zero);

      expect(handled, isTrue);
      expect(reporter.collectionEnabled, isTrue);
      expect(reporter.errors, hasLength(1));
      expect(
        reporter.errors.single.error.toString(),
        contains('private location coordinates'),
      );
      expect(reporter.errors.single.stackTrace, stackTrace);
      expect(reporter.errors.single.fatal, isTrue);
    });
  });
}
