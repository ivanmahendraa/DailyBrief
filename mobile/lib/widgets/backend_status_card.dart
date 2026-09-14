import 'package:flutter/material.dart';
import '../services/api/health_service.dart';

class BackendStatusCard extends StatelessWidget {
  final HealthStatus? status;
  final bool isLoading;
  final VoidCallback onRefresh;

  const BackendStatusCard({
    super.key,
    required this.status,
    required this.isLoading,
    required this.onRefresh,
  });

  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final isHealthy = status?.isHealthy == true;

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
              color: isLoading
                  ? const Color(0xFFF59E0B)
                  : (isHealthy
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444)),
            ),
          ),
          const SizedBox(width: 8),
          // Label Status
          Expanded(
            child: Text(
              isLoading
                  ? 'Memeriksa status backend...'
                  : 'Backend: ${isHealthy ? "Terhubung" : "Terputus"} • DB: ${status?.databaseStatus ?? "-"}',
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
            onTap: isLoading ? null : onRefresh,
            child: isLoading
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
}
