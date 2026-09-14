import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'core/theme/app_theme.dart';
import 'services/api/health_service.dart';

void main() {
  runApp(const DailyBriefApp());
}

class DailyBriefApp extends StatelessWidget {
  const DailyBriefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DailyBrief',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const StartScreen(),
    );
  }
}

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
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
  static const Color _borderColor = Color(0xFFE2E8F0);

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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────
  // Tab Beranda / Dashboard Utama
  // ─────────────────────────────────────────────
  Widget _buildHomeDashboard() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Logo, Nama, LIVE Badge, Profil)
          _buildHeader(),

          const SizedBox(height: 16),

          // 2. Sapaan "Selamat datang di DailyBrief"
          _buildGreetingPill(),

          const SizedBox(height: 16),

          // 3. Bagian Utama Voice Assistant
          _buildVoiceSection(),

          const SizedBox(height: 24),

          // 4. Bagian Hasil Perintah
          _buildCommandResultSection(),

          const SizedBox(height: 20),

          // 5. Kartu Informasi Harian (Dummy Cuaca)
          _buildDailyInfoCard(),

          const SizedBox(height: 20),

          // 6. Perintah Cepat Tersedia
          _buildQuickCommandsSection(),

          const SizedBox(height: 24),

          // 8. Status Koneksi Backend (Sekunder)
          _buildBackendStatusCard(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 1. Header
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        // Logo SVG DailyBrief
        SvgPicture.asset(
          'assets/images/logo_dailybrief.svg',
          width: 42,
          height: 42,
        ),
        const SizedBox(width: 10),
        // Nama Aplikasi & Tagline
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'DailyBrief',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: _textMain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge LIVE
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _primaryBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Temukan Informasi dalam Satu Sentuhan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: _textMuted,
                ),
              ),
            ],
          ),
        ),
        // Ikon Profil / Pengaturan Bulat Biru
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF1D4ED8),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 2. Sapaan
  // ─────────────────────────────────────────────
  Widget _buildGreetingPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFBFDBFE).withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'Selamat datang di DailyBrief',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 3. Bagian Utama Voice Assistant
  // ─────────────────────────────────────────────
  Widget _buildVoiceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Judul Utama
        const Text(
          'Apa yang ingin kamu ketahui?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: _textMain,
          ),
        ),
        const SizedBox(height: 6),
        // Deskripsi
        const Text(
          'Tekan tombol mikrofon dan ucapkan pertanyaan atau perintah harian Anda secara langsung.',
          style: TextStyle(
            fontSize: 13,
            color: _textMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 26),

        // Tombol Mikrofon Besar dengan Aura Halo
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  // Tombol belum perlu memiliki fungsi nyata pada tahap ini
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fitur suara akan segera hadir!'),
                      duration: Duration(milliseconds: 1000),
                    ),
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFDBEAFE).withValues(alpha: 0.55),
                  ),
                  child: Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primaryBlue,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryBlue.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Teks Bawah Tombol
              const Text(
                'Tekan untuk berbicara',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textMain,
                ),
              ),
              const SizedBox(height: 8),
              // Status Kecil Mikrofon
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Status: Mikrofon siap digunakan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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

  // ─────────────────────────────────────────────
  // 4. Bagian Hasil Perintah
  // ─────────────────────────────────────────────
  Widget _buildCommandResultSection() {
    final currentExample = _commandExamples[_selectedCommand] ??
        {
          'query': 'Sekarang jam berapa?',
          'response': 'Sekarang pukul 06.00.',
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris Judul & Tombol Bersihkan
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: _primaryBlue,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Hasil Perintah',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textMain,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _hasDummyResult = !_hasDummyResult;
                });
              },
              child: Text(
                _hasDummyResult ? 'Bersihkan' : 'Tampilkan Contoh',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Area Percakapan Bubble
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Placeholder Text
              const Text(
                'Pertanyaan dan jawaban sistem akan ditampilkan di bagian ini.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: _textMuted,
                ),
              ),
              if (_hasDummyResult) ...[
                const SizedBox(height: 12),

                // Bubble Pertanyaan Pengguna (Kanan)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        currentExample['query']!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFCBD5E1),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bubble Jawaban DailyBrief Voice (Kiri)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primaryBlue,
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'DailyBrief Voice',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _primaryBlue,
                                  ),
                                ),
                                Text(
                                  'Baru saja',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '"${currentExample['response']!}"',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textMain,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Dummy Mini Audio Player & Waveform
                            Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _primaryBlue,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Dummy visual waveform bars
                                Row(
                                  children: [
                                    _buildWaveBar(6, _primaryBlue),
                                    _buildWaveBar(14, _primaryBlue),
                                    _buildWaveBar(18, _primaryBlue),
                                    _buildWaveBar(12, _primaryBlue),
                                    _buildWaveBar(8, const Color(0xFF93C5FD)),
                                    _buildWaveBar(14, const Color(0xFFBFDBFE)),
                                    _buildWaveBar(6, const Color(0xFFDBEAFE)),
                                  ],
                                ),
                                const Spacer(),
                                const Text(
                                  '0:02',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '* Contoh jawaban suara (data dummy)',
                              style: TextStyle(
                                fontSize: 9,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaveBar(double height, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 5. Kartu Informasi Harian (Dummy Cuaca)
  // ─────────────────────────────────────────────
  Widget _buildDailyInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A34),
            Color(0xFF2C4A42),
            Color(0xFF334155),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Label Sekilas Info
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Sekilas Info Hari Ini',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF86EFAC),
                  ),
                ),
              ),
              const Icon(
                Icons.wb_sunny_outlined,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Jakarta Barat • Cerah Berawan 28°C',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '* Data cuaca & lokasi dummy (belum terhubung ke API)',
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.white70,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 6. Perintah Cepat Tersedia
  // ─────────────────────────────────────────────
  Widget _buildQuickCommandsSection() {
    final commands = [
      {'label': 'Hari', 'icon': Icons.calendar_today_outlined},
      {'label': 'Tanggal', 'icon': Icons.calendar_month_outlined},
      {'label': 'Waktu', 'icon': Icons.access_time_rounded},
      {'label': 'Cuaca', 'icon': Icons.cloud_outlined},
      {'label': 'Lokasi', 'icon': Icons.navigation_outlined},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris Header
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Perintah Cepat Tersedia',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textMain,
              ),
            ),
            Text(
              'Contoh Suara',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Daftar Tombol Chip
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: commands.map((cmd) {
            final label = cmd['label'] as String;
            final icon = cmd['icon'] as IconData;
            final isSelected = _selectedCommand == label;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCommand = label;
                  _hasDummyResult = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: const Color(0xFFBFDBFE).withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: isSelected ? Colors.white : _primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 8. Status Koneksi Backend (Sekunder)
  // ─────────────────────────────────────────────
  Widget _buildBackendStatusCard() {
    final isHealthy = _status?.isHealthy == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Row(
        children: [
          // Status Dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isLoading
                  ? const Color(0xFFF59E0B)
                  : (isHealthy ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
            ),
          ),
          const SizedBox(width: 8),
          // Label Status
          Expanded(
            child: Text(
              _isLoading
                  ? 'Memeriksa status backend...'
                  : 'Backend: ${isHealthy ? "Terhubung" : "Terputus"} • DB: ${_status?.databaseStatus ?? "-"}',
              style: const TextStyle(
                fontSize: 11,
                color: _textMuted,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Tombol refresh kecil
          GestureDetector(
            onTap: _isLoading ? null : _checkConnection,
            child: _isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _textMuted,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: _textMuted,
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Navigasi Bawah
  // ─────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _borderColor, width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Pengaturan',
          ),
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
