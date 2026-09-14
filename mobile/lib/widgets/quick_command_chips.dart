import 'package:flutter/material.dart';

class QuickCommandChips extends StatelessWidget {
  final String selectedCommand;
  final ValueChanged<String> onCommandSelected;

  const QuickCommandChips({
    super.key,
    required this.selectedCommand,
    required this.onCommandSelected,
  });

  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _textMain = Color(0xFF0F172A);

  static const List<Map<String, dynamic>> _commands = [
    {'label': 'Hari', 'icon': Icons.calendar_today_outlined},
    {'label': 'Tanggal', 'icon': Icons.calendar_month_outlined},
    {'label': 'Waktu', 'icon': Icons.access_time_rounded},
    {'label': 'Cuaca', 'icon': Icons.cloud_outlined},
    {'label': 'Lokasi', 'icon': Icons.navigation_outlined},
  ];

  @override
  Widget build(BuildContext context) {
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
          children: _commands.map((cmd) {
            final label = cmd['label'] as String;
            final icon = cmd['icon'] as IconData;
            final isSelected = selectedCommand == label;

            return GestureDetector(
              onTap: () => onCommandSelected(label),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFEFF6FF),
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
                        color:
                            isSelected ? Colors.white : const Color(0xFF1E40AF),
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
}
