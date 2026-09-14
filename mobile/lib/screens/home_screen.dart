import 'package:flutter/material.dart';
import '../services/api/health_service.dart';
import '../widgets/app_header.dart';
import '../widgets/backend_status_card.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/daily_info_card.dart';
import '../widgets/quick_command_chips.dart';
import '../widgets/result_section.dart';
import '../widgets/voice_assistant_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Backward compatibility alias for StartScreen
typedef StartScreen = HomeScreen;

class _HomeScreenState extends State<HomeScreen> {
  final HealthService _healthService = HealthService();
  bool _isLoading = false;
  HealthStatus? _status;
  int _currentTabIndex = 0;

  // Selected quick command chip untuk demonstrasi interaktif
  String _selectedCommand = 'Waktu';

  // State percakapan dummy
  bool _hasDummyResult = true;

  // Palet warna utama
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _bgSoft = Color(0xFFF8FAFC);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  // Map data interaktif untuk contoh respons cepat dummy
  final Map<String, Map<String, String>> _commandExamples = {
    'Hari': {
      'query': 'Hari apa hari ini?',
      'response': 'Hari ini adalah hari Senin.',
    },
    'Tanggal': {
      'query': 'Tanggal berapa hari ini?',
      'response': 'Hari ini tanggal 14 September 2026.',
    },
    'Waktu': {
      'query': 'Sekarang jam berapa?',
      'response': 'Sekarang pukul 06.00.',
    },
    'Cuaca': {
      'query': 'Bagaimana cuaca hari ini?',
      'response': 'Jakarta Barat cerah berawan dengan suhu 28°C.',
    },
    'Lokasi': {
      'query': 'Di mana lokasi saya?',
      'response': 'Lokasi Anda terdeteksi di Jakarta Barat.',
    },
  };

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() => _isLoading = true);
    final result = await _healthService.checkHealth();
    if (!mounted) return;
    setState(() {
      _status = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSoft,
      body: SafeArea(
        child: _currentTabIndex == 0
            ? _buildHomeDashboard()
            : _buildSettingsPlaceholder(),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Tab Beranda / Dashboard Utama
  // ─────────────────────────────────────────────
  Widget _buildHomeDashboard() {
    final currentExample = _commandExamples[_selectedCommand] ??
        {
          'query': 'Sekarang jam berapa?',
          'response': 'Sekarang pukul 06.00.',
        };

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Logo, Nama, LIVE Badge, Profil)
          const AppHeader(),

          const SizedBox(height: 16),

          // 2. Sapaan "Selamat datang di DailyBrief"
          const GreetingPill(),

          const SizedBox(height: 16),

          // 3. Bagian Utama Voice Assistant
          const VoiceAssistantCard(),

          const SizedBox(height: 24),

          // 4. Bagian Hasil Perintah
          ResultSection(
            hasDummyResult: _hasDummyResult,
            query: currentExample['query']!,
            response: currentExample['response']!,
            onToggleResult: () {
              setState(() {
                _hasDummyResult = !_hasDummyResult;
              });
            },
          ),

          const SizedBox(height: 20),

          // 5. Kartu Informasi Harian (Dummy Cuaca)
          const DailyInfoCard(),

          const SizedBox(height: 20),

          // 6. Perintah Cepat Tersedia
          QuickCommandChips(
            selectedCommand: _selectedCommand,
            onCommandSelected: (cmd) {
              setState(() {
                _selectedCommand = cmd;
                _hasDummyResult = true;
              });
            },
          ),

          const SizedBox(height: 24),

          // 8. Status Koneksi Backend (Sekunder)
          BackendStatusCard(
            status: _status,
            isLoading: _isLoading,
            onRefresh: _checkConnection,
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Placeholder Layar Pengaturan (Belum Perlu Dibuat Penuh)
  // ─────────────────────────────────────────────
  Widget _buildSettingsPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEFF6FF),
              ),
              child: const Icon(
                Icons.settings_outlined,
                size: 40,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pengaturan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textMain,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Halaman pengaturan akan tersedia pada tahap pengembangan berikutnya.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() => _currentTabIndex = 0);
              },
              child: const Text('Kembali ke Beranda'),
            ),
          ],
        ),
      ),
    );
  }
}
