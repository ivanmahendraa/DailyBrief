import 'package:flutter/material.dart';

class ResultSection extends StatelessWidget {
  final bool hasDummyResult;
  final String query;
  final String response;
  final VoidCallback onToggleResult;

  const ResultSection({
    super.key,
    required this.hasDummyResult,
    required this.query,
    required this.response,
    required this.onToggleResult,
  });

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
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
              onTap: onToggleResult,
              child: Text(
                hasDummyResult ? 'Bersihkan' : 'Tampilkan Contoh',
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
              if (hasDummyResult) ...[
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
                        query,
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
                              '"$response"',
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
}
