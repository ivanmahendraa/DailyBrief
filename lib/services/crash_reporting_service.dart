import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

abstract interface class CrashErrorReporter {
  Future<void> setCollectionEnabled(bool enabled);

  Future<void> recordFlutterFatalError(FlutterErrorDetails details);

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    required bool fatal,
  });
}

class FirebaseCrashErrorReporter implements CrashErrorReporter {
  FirebaseCrashErrorReporter({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _crashlytics.setCrashlyticsCollectionEnabled(enabled);

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) =>
      _crashlytics.recordFlutterFatalError(details);

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    required bool fatal,
  }) => _crashlytics.recordError(error, stackTrace, fatal: fatal);
}

class CrashReportingService {
  CrashReportingService({
    required this.reporter,
    void Function(FlutterErrorDetails details)? presentFlutterError,
  }) : _presentFlutterError = presentFlutterError ?? FlutterError.presentError;

  final CrashErrorReporter reporter;
  final void Function(FlutterErrorDetails details) _presentFlutterError;

  Future<void> initialize({required bool collectionEnabled}) async {
    await reporter.setCollectionEnabled(collectionEnabled);

    FlutterError.onError = (details) {
      _presentFlutterError(details);
      unawaited(reporter.recordFlutterFatalError(details));
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(
        reporter.recordError(error, stackTrace, fatal: true),
      );
      return true;
    };
  }
}
