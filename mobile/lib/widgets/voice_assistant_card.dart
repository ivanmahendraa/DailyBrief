import 'package:flutter/material.dart';

class VoiceAssistantCard extends StatelessWidget {
  final VoidCallback? onMicTap;

  const VoiceAssistantCard({
    super.key,
    this.onMicTap,
  });

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
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
                onTap: onMicTap ??
                    () {
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
}
