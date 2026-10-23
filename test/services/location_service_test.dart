import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:daily_brief/services/location_service.dart';

class _FakeLocationClient implements LocationClient {
  bool serviceEnabled = true;
  LocationPermission currentPermission = LocationPermission.denied;
  LocationPermission requestResult = LocationPermission.whileInUse;
  bool openAppSettingsResult = true;
  bool openLocationSettingsResult = true;

  bool throwOnServiceCheck = false;
  bool throwOnCheckPermission = false;
  bool throwOnRequestPermission = false;
  bool throwOnOpenAppSettings = false;
  bool throwOnOpenLocationSettings = false;

  int serviceCheckCallCount = 0;
  int checkPermissionCallCount = 0;
  int requestPermissionCallCount = 0;
  int openAppSettingsCallCount = 0;
  int openLocationSettingsCallCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async {
    serviceCheckCallCount++;
    if (throwOnServiceCheck) {
      throw StateError('Service check failed');
    }
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    checkPermissionCallCount++;
    if (throwOnCheckPermission) {
      throw StateError('Check permission failed');
    }
    return currentPermission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCallCount++;
    if (throwOnRequestPermission) {
      throw StateError('Request permission failed');
    }
    return requestResult;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCallCount++;
    if (throwOnOpenAppSettings) {
      throw StateError('Open app settings failed');
    }
    return openAppSettingsResult;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCallCount++;
    if (throwOnOpenLocationSettings) {
      throw StateError('Open location settings failed');
    }
    return openLocationSettingsResult;
  }
}

void main() {
  group('LocationService Permission Tests (TASK-45)', () {
    late _FakeLocationClient fakeClient;
    late LocationService locationService;

    setUp(() {
      fakeClient = _FakeLocationClient();
      locationService = LocationService(fakeClient);
    });

    group('Helper permission classifiers', () {
      test(
        'isPermissionGranted returns true only for whileInUse and always',
        () {
          expect(
            LocationService.isPermissionGranted(LocationPermission.whileInUse),
            isTrue,
          );
          expect(
            LocationService.isPermissionGranted(LocationPermission.always),
            isTrue,
          );
          expect(
            LocationService.isPermissionGranted(LocationPermission.denied),
            isFalse,
          );
          expect(
            LocationService.isPermissionGranted(
              LocationPermission.deniedForever,
            ),
            isFalse,
          );
          expect(
            LocationService.isPermissionGranted(
              LocationPermission.unableToDetermine,
            ),
            isFalse,
          );
        },
      );

      test('isPermissionDenied returns true only for denied', () {
        expect(
          LocationService.isPermissionDenied(LocationPermission.denied),
          isTrue,
        );
        expect(
          LocationService.isPermissionDenied(LocationPermission.deniedForever),
          isFalse,
        );
        expect(
          LocationService.isPermissionDenied(LocationPermission.whileInUse),
          isFalse,
        );
        expect(
          LocationService.isPermissionDenied(LocationPermission.always),
          isFalse,
        );
      });

      test(
        'isPermissionPermanentlyDenied returns true only for deniedForever',
        () {
          expect(
            LocationService.isPermissionPermanentlyDenied(
              LocationPermission.deniedForever,
            ),
            isTrue,
          );
          expect(
            LocationService.isPermissionPermanentlyDenied(
              LocationPermission.denied,
            ),
            isFalse,
          );
          expect(
            LocationService.isPermissionPermanentlyDenied(
              LocationPermission.whileInUse,
            ),
            isFalse,
          );
          expect(
            LocationService.isPermissionPermanentlyDenied(
              LocationPermission.always,
            ),
            isFalse,
          );
        },
      );
    });

    group('Direct client delegations and error handling', () {
      test(
        'isLocationServiceEnabled delegates and handles errors gracefully',
        () async {
          fakeClient.serviceEnabled = true;
          expect(await locationService.isLocationServiceEnabled(), isTrue);
          expect(fakeClient.serviceCheckCallCount, 1);

          fakeClient.serviceEnabled = false;
          expect(await locationService.isLocationServiceEnabled(), isFalse);

          fakeClient.throwOnServiceCheck = true;
          expect(await locationService.isLocationServiceEnabled(), isFalse);
        },
      );

      test('checkPermission delegates directly to client', () async {
        fakeClient.currentPermission = LocationPermission.whileInUse;
        final result = await locationService.checkPermission();
        expect(result, LocationPermission.whileInUse);
        expect(fakeClient.checkPermissionCallCount, 1);
      });

      test('requestPermission delegates directly to client', () async {
        fakeClient.requestResult = LocationPermission.always;
        final result = await locationService.requestPermission();
        expect(result, LocationPermission.always);
        expect(fakeClient.requestPermissionCallCount, 1);
      });

      test('openAppSettings delegates and handles exceptions', () async {
        fakeClient.openAppSettingsResult = true;
        expect(await locationService.openAppSettings(), isTrue);
        expect(fakeClient.openAppSettingsCallCount, 1);

        fakeClient.throwOnOpenAppSettings = true;
        expect(await locationService.openAppSettings(), isFalse);
      });

      test('openLocationSettings delegates and handles exceptions', () async {
        fakeClient.openLocationSettingsResult = true;
        expect(await locationService.openLocationSettings(), isTrue);
        expect(fakeClient.openLocationSettingsCallCount, 1);

        fakeClient.throwOnOpenLocationSettings = true;
        expect(await locationService.openLocationSettings(), isFalse);
      });
    });

    group('checkPermissionStatus', () {
      test('returns granted when permission is whileInUse', () async {
        fakeClient.currentPermission = LocationPermission.whileInUse;
        final result = await locationService.checkPermissionStatus();

        expect(result.status, LocationPermissionStatus.granted);
        expect(result.isGranted, isTrue);
        expect(result.message, LocationPermissionMessages.granted);
        expect(result.rawPermission, LocationPermission.whileInUse);
      });

      test('returns granted when permission is always', () async {
        fakeClient.currentPermission = LocationPermission.always;
        final result = await locationService.checkPermissionStatus();

        expect(result.status, LocationPermissionStatus.granted);
        expect(result.isGranted, isTrue);
        expect(result.rawPermission, LocationPermission.always);
      });

      test('returns denied when permission is denied', () async {
        fakeClient.currentPermission = LocationPermission.denied;
        final result = await locationService.checkPermissionStatus();

        expect(result.status, LocationPermissionStatus.denied);
        expect(result.isDenied, isTrue);
        expect(result.message, LocationPermissionMessages.denied);
        expect(result.rawPermission, LocationPermission.denied);
      });

      test('returns deniedForever when permission is deniedForever', () async {
        fakeClient.currentPermission = LocationPermission.deniedForever;
        final result = await locationService.checkPermissionStatus();

        expect(result.status, LocationPermissionStatus.deniedForever);
        expect(result.isDeniedForever, isTrue);
        expect(result.message, LocationPermissionMessages.deniedForever);
        expect(result.rawPermission, LocationPermission.deniedForever);
      });

      test(
        'returns unableToDetermine when permission is unableToDetermine',
        () async {
          fakeClient.currentPermission = LocationPermission.unableToDetermine;
          final result = await locationService.checkPermissionStatus();

          expect(result.status, LocationPermissionStatus.unableToDetermine);
          expect(result.message, LocationPermissionMessages.unableToDetermine);
        },
      );

      test('returns error when checkPermission throws', () async {
        fakeClient.throwOnCheckPermission = true;
        final result = await locationService.checkPermissionStatus();

        expect(result.status, LocationPermissionStatus.error);
        expect(result.isError, isTrue);
        expect(result.message, LocationPermissionMessages.error);
      });
    });

    group('requestLocationPermission', () {
      test(
        'returns serviceDisabled when location service is disabled and check is enabled',
        () async {
          fakeClient.serviceEnabled = false;

          final result = await locationService.requestLocationPermission(
            checkServiceEnabled: true,
          );

          expect(result.status, LocationPermissionStatus.serviceDisabled);
          expect(result.isServiceDisabled, isTrue);
          expect(result.message, LocationPermissionMessages.serviceDisabled);
          expect(fakeClient.checkPermissionCallCount, 0);
          expect(fakeClient.requestPermissionCallCount, 0);
        },
      );

      test(
        'proceeds without service check when checkServiceEnabled is false',
        () async {
          fakeClient.serviceEnabled = false;
          fakeClient.currentPermission = LocationPermission.whileInUse;

          final result = await locationService.requestLocationPermission(
            checkServiceEnabled: false,
          );

          expect(result.status, LocationPermissionStatus.granted);
          expect(fakeClient.serviceCheckCallCount, 0);
          expect(fakeClient.checkPermissionCallCount, 1);
        },
      );

      test(
        'returns granted immediately if current permission is already granted',
        () async {
          fakeClient.serviceEnabled = true;
          fakeClient.currentPermission = LocationPermission.whileInUse;

          final result = await locationService.requestLocationPermission();

          expect(result.status, LocationPermissionStatus.granted);
          expect(result.isGranted, isTrue);
          expect(result.rawPermission, LocationPermission.whileInUse);
          expect(fakeClient.checkPermissionCallCount, 1);
          expect(fakeClient.requestPermissionCallCount, 0);
        },
      );

      test(
        'returns deniedForever without requesting if current permission is already deniedForever',
        () async {
          fakeClient.serviceEnabled = true;
          fakeClient.currentPermission = LocationPermission.deniedForever;

          final result = await locationService.requestLocationPermission();

          expect(result.status, LocationPermissionStatus.deniedForever);
          expect(result.isDeniedForever, isTrue);
          expect(result.message, LocationPermissionMessages.deniedForever);
          expect(result.rawPermission, LocationPermission.deniedForever);
          expect(fakeClient.checkPermissionCallCount, 1);
          expect(fakeClient.requestPermissionCallCount, 0);
        },
      );

      test(
        'requests permission and returns granted when user accepts whileInUse',
        () async {
          fakeClient.serviceEnabled = true;
          fakeClient.currentPermission = LocationPermission.denied;
          fakeClient.requestResult = LocationPermission.whileInUse;

          final result = await locationService.requestLocationPermission();

          expect(result.status, LocationPermissionStatus.granted);
          expect(result.isGranted, isTrue);
          expect(result.rawPermission, LocationPermission.whileInUse);
          expect(fakeClient.checkPermissionCallCount, 1);
          expect(fakeClient.requestPermissionCallCount, 1);
        },
      );

      test(
        'requests permission and returns granted when user accepts always',
        () async {
          fakeClient.serviceEnabled = true;
          fakeClient.currentPermission = LocationPermission.denied;
          fakeClient.requestResult = LocationPermission.always;

          final result = await locationService.requestLocationPermission();

          expect(result.status, LocationPermissionStatus.granted);
          expect(result.isGranted, isTrue);
          expect(result.rawPermission, LocationPermission.always);
          expect(fakeClient.requestPermissionCallCount, 1);
        },
      );

      test('requests permission and returns denied when user denies', () async {
        fakeClient.serviceEnabled = true;
        fakeClient.currentPermission = LocationPermission.denied;
        fakeClient.requestResult = LocationPermission.denied;

        final result = await locationService.requestLocationPermission();

        expect(result.status, LocationPermissionStatus.denied);
        expect(result.isDenied, isTrue);
        expect(result.message, LocationPermissionMessages.denied);
        expect(result.rawPermission, LocationPermission.denied);
        expect(fakeClient.requestPermissionCallCount, 1);
      });

      test(
        'requests permission and returns deniedForever when user denies permanently',
        () async {
          fakeClient.serviceEnabled = true;
          fakeClient.currentPermission = LocationPermission.denied;
          fakeClient.requestResult = LocationPermission.deniedForever;

          final result = await locationService.requestLocationPermission();

          expect(result.status, LocationPermissionStatus.deniedForever);
          expect(result.isDeniedForever, isTrue);
          expect(result.message, LocationPermissionMessages.deniedForever);
          expect(result.rawPermission, LocationPermission.deniedForever);
          expect(fakeClient.requestPermissionCallCount, 1);
        },
      );

      test(
        'requests permission when current permission is unableToDetermine',
        () async {
          fakeClient.serviceEnabled = true;
          fakeClient.currentPermission = LocationPermission.unableToDetermine;
          fakeClient.requestResult = LocationPermission.whileInUse;

          final result = await locationService.requestLocationPermission();

          expect(result.status, LocationPermissionStatus.granted);
          expect(fakeClient.requestPermissionCallCount, 1);
        },
      );

      test(
        'returns error when requestPermission throws an exception',
        () async {
          fakeClient.serviceEnabled = true;
          fakeClient.currentPermission = LocationPermission.denied;
          fakeClient.throwOnRequestPermission = true;

          final result = await locationService.requestLocationPermission();

          expect(result.status, LocationPermissionStatus.error);
          expect(result.isError, isTrue);
          expect(result.message, LocationPermissionMessages.error);
        },
      );
    });

    group('LocationPermissionResult value equality and toString', () {
      test('equality and hashCode match for identical properties', () {
        const resultA = LocationPermissionResult(
          status: LocationPermissionStatus.granted,
          message: 'OK',
          rawPermission: LocationPermission.whileInUse,
        );
        const resultB = LocationPermissionResult(
          status: LocationPermissionStatus.granted,
          message: 'OK',
          rawPermission: LocationPermission.whileInUse,
        );
        const resultC = LocationPermissionResult(
          status: LocationPermissionStatus.denied,
          message: 'NO',
        );

        expect(resultA, equals(resultB));
        expect(resultA.hashCode, equals(resultB.hashCode));
        expect(resultA == resultC, isFalse);
        expect(resultA.toString(), contains('LocationPermissionStatus.granted'));
      });
    });
  });
}
