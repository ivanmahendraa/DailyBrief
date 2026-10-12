import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_brief/services/preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferenceService Tests (TASK-22)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Awalnya isFirstVisit mengembalikan true bila belum ada data tersimpan', () async {
      final service = PreferenceService();
      final isFirst = await service.isFirstVisit();
      expect(isFirst, isTrue);
    });

    test('2. markFirstVisitCompleted menyimpan status dan isFirstVisit mengembalikan false', () async {
      final service = PreferenceService();
      
      final marked = await service.markFirstVisitCompleted();
      expect(marked, isTrue);

      final isFirst = await service.isFirstVisit();
      expect(isFirst, isFalse);
    });

    test('3. resetFirstVisit menghapus status dan mengembalikan isFirstVisit ke true', () async {
      final service = PreferenceService();
      await service.markFirstVisitCompleted();
      expect(await service.isFirstVisit(), isFalse);

      final reset = await service.resetFirstVisit();
      expect(reset, isTrue);
      expect(await service.isFirstVisit(), isTrue);
    });
  });
}
