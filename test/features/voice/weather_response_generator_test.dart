import 'package:flutter_test/flutter_test.dart';
import 'package:daily_brief/features/voice/weather_response_generator.dart';
import 'package:daily_brief/models/weather_data.dart';

void main() {
  group('WeatherResponseGenerator (TASK-53)', () {
    const generator = WeatherResponseGenerator();

    test('1. Menghasilkan kalimat normal dengan kota, cuaca, dan suhu bulat', () {
      const weather = WeatherData(
        description: 'cerah',
        temperature: 30.0,
        cityName: 'Batam',
      );

      final response = generator.generate(weather);

      expect(
        response,
        equals('Cuaca di Batam saat ini cerah dengan suhu 30 derajat Celsius.'),
      );
    });

    test('2. Melakukan pembulatan suhu desimal ke atas dan ke bawah dengan benar', () {
      // Pembulatan ke bawah (30.2 -> 30)
      const weatherRoundDown = WeatherData(
        description: 'berawan',
        temperature: 30.2,
        cityName: 'Batam',
      );
      expect(
        generator.generate(weatherRoundDown),
        equals('Cuaca di Batam saat ini berawan dengan suhu 30 derajat Celsius.'),
      );

      // Pembulatan ke atas (29.8 -> 30)
      const weatherRoundUp = WeatherData(
        description: 'berawan',
        temperature: 29.8,
        cityName: 'Batam',
      );
      expect(
        generator.generate(weatherRoundUp),
        equals('Cuaca di Batam saat ini berawan dengan suhu 30 derajat Celsius.'),
      );

      // Pembulatan half-up (25.5 -> 26)
      const weatherHalf = WeatherData(
        description: 'hujan',
        temperature: 25.5,
        cityName: 'Bandung',
      );
      expect(
        generator.generate(weatherHalf),
        equals('Cuaca di Bandung saat ini hujan dengan suhu 26 derajat Celsius.'),
      );
    });

    test('3. Menangani berbagai variasi deskripsi kondisi cuaca Bahasa Indonesia', () {
      const descriptions = [
        'cerah berawan',
        'hujan ringan',
        'hujan lebat disertai petir',
        'kabut tebal',
      ];

      for (final desc in descriptions) {
        final weather = WeatherData(
          description: desc,
          temperature: 28.0,
          cityName: 'Jakarta',
        );

        final response = generator.generate(weather);
        expect(
          response,
          equals('Cuaca di Jakarta saat ini $desc dengan suhu 28 derajat Celsius.'),
        );
      }
    });

    test('4. Mengubah deskripsi cuaca menjadi huruf kecil secara natural dalam kalimat', () {
      const weather = WeatherData(
        description: 'Hujan Deras',
        temperature: 27.0,
        cityName: 'Medan',
      );

      final response = generator.generate(weather);
      expect(
        response,
        equals('Cuaca di Medan saat ini hujan deras dengan suhu 27 derajat Celsius.'),
      );
    });

    test('5. Menghasilkan jawaban yang natural ketika cityName null', () {
      const weather = WeatherData(
        description: 'cerah',
        temperature: 31.0,
        cityName: null,
      );

      final response = generator.generate(weather);

      expect(
        response,
        equals('Cuaca saat ini cerah dengan suhu 31 derajat Celsius.'),
      );
    });

    test('6. Menghasilkan jawaban yang natural ketika cityName berupa string kosong atau spasi', () {
      const weatherEmpty = WeatherData(
        description: 'berawan',
        temperature: 29.0,
        cityName: '',
      );
      expect(
        generator.generate(weatherEmpty),
        equals('Cuaca saat ini berawan dengan suhu 29 derajat Celsius.'),
      );

      const weatherBlank = WeatherData(
        description: 'berawan',
        temperature: 29.0,
        cityName: '   ',
      );
      expect(
        generator.generate(weatherBlank),
        equals('Cuaca saat ini berawan dengan suhu 29 derajat Celsius.'),
      );
    });

    test('7. Menangani data cuaca dengan suhu negatif', () {
      const weatherCold = WeatherData(
        description: 'salju ringan',
        temperature: -3.8,
        cityName: 'Sapporo',
      );

      final response = generator.generate(weatherCold);

      expect(
        response,
        equals('Cuaca di Sapporo saat ini salju ringan dengan suhu -4 derajat Celsius.'),
      );
    });

    test('8. Memastikan output generator tidak pernah kosong dan selalu berakhiran format Celsius', () {
      const weather = WeatherData(
        description: 'angin kencang',
        temperature: 24.0,
        cityName: 'Surabaya',
      );

      final response = generator.generate(weather);

      expect(response.trim().isNotEmpty, isTrue);
      expect(response, contains('derajat Celsius'));
      expect(response.endsWith('derajat Celsius.'), isTrue);
    });

    test('9. Menangani whitespace berlebih pada cityName dan description', () {
      const weather = WeatherData(
        description: '  hujan rintik-rintik  ',
        temperature: 26.0,
        cityName: '  Kota Batam  ',
      );

      final response = generator.generate(weather);

      expect(
        response,
        equals('Cuaca di Kota Batam saat ini hujan rintik-rintik dengan suhu 26 derajat Celsius.'),
      );
    });

    test('10. Menangani deskripsi yang kosong dengan fallback aman', () {
      const weather = WeatherData(
        description: '   ',
        temperature: 30.0,
        cityName: 'Batam',
      );

      final response = generator.generate(weather);

      expect(
        response,
        equals('Cuaca di Batam saat ini tidak diketahui dengan suhu 30 derajat Celsius.'),
      );
    });

    test('11. Memastikan alias method generateResponse dan static format menghasilkan kalimat identik', () {
      const weather = WeatherData(
        description: 'cerah berawan',
        temperature: 32.4,
        cityName: 'Denpasar',
      );

      final resp1 = generator.generate(weather);
      final resp2 = generator.generateResponse(weather);
      final resp3 = WeatherResponseGenerator.format(weather);

      expect(resp1, equals(resp2));
      expect(resp1, equals(resp3));
      expect(
        resp1,
        equals('Cuaca di Denpasar saat ini cerah berawan dengan suhu 32 derajat Celsius.'),
      );
    });

    test('12. Memastikan seluruh data WeatherData digunakan sesuai kontrak TASK-52', () {
      const weather = WeatherData(
        description: 'berawan tebal',
        temperature: 28.6,
        cityName: 'Yogyakarta',
        latitude: -7.7970,
        longitude: 110.3705,
      );

      final response = generator.generate(weather);

      expect(response, contains('Yogyakarta'));
      expect(response, contains('berawan tebal'));
      expect(response, contains('${weather.roundedTemperature}'));
      expect(response, contains('derajat Celsius'));
    });
  });
}
