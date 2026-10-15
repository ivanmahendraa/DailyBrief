import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/speech_to_text_service.dart';
import '../../../services/tts_service.dart';
import '../../voice/voice_controller.dart';

/// Halaman Utama (Home Screen) DailyBrief dengan konsep Daily Horizon.
///
/// Menyediakan antarmuka yang tenang, bersih, kontras tinggi, dan ramah aksesibilitas:
/// - Header dengan simbol Daily Horizon dan nama aplikasi DailyBrief.
/// - Status interaksi awal ("Siap Digunakan").
/// - Area interaksi utama yang diperbesar dengan pengikatan event sentuh (onTap)
///   dan umpan balik getaran haptik (HapticFeedback, TASK-14, TASK-25).
/// - Petunjuk daftar perintah suara di bagian bawah.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onTouchAreaTap;
  final VoiceController? voiceController;
  final SpeechToTextService? speechToTextService;
  final TtsService? ttsService;

  const HomeScreen({
    super.key,
    this.onTouchAreaTap,
    this.voiceController,
    this.speechToTextService,
    this.ttsService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late VoiceController _voiceController;
  bool _handlingTouch = false;

  @override
  void initState() {
    super.initState();
    _voiceController = _createVoiceController();
    _voiceController.addListener(_handleControllerChange);
  }

  VoiceController _createVoiceController() =>
      widget.voiceController ??
      VoiceController(
        speechToTextService: widget.speechToTextService,
        ttsService: widget.ttsService,
      );

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceController == widget.voiceController &&
        oldWidget.speechToTextService == widget.speechToTextService &&
        oldWidget.ttsService == widget.ttsService) {
      return;
    }

    _voiceController
      ..removeListener(_handleControllerChange)
      ..dispose();
    _voiceController = _createVoiceController();
    _voiceController.addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (mounted) setState(() {});
  }

  Future<void> _handleTouchAreaTap() async {
    if (!mounted ||
        _handlingTouch ||
        _voiceController.state != VoiceInteractionState.idle ||
        _voiceController.hasActiveSession) {
      return;
    }
    _handlingTouch = true;
    try {
      try {
        await HapticFeedback.mediumImpact();
      } catch (error) {
        debugPrint('HomeScreen HapticFeedback error: $error');
      }
      if (!mounted) return;
      unawaited(_voiceController.handleUserTap());
      widget.onTouchAreaTap?.call();
    } finally {
      _handlingTouch = false;
    }
  }

  String get _statusLabel => switch (_voiceController.state) {
    VoiceInteractionState.idle => AppStrings.statusReady,
    VoiceInteractionState.confirming => AppStrings.statusConfirming,
    VoiceInteractionState.listening => 'Mendengarkan',
    VoiceInteractionState.processing => 'Memproses',
    VoiceInteractionState.speaking => 'Berbicara',
    VoiceInteractionState.error => 'Perlu perhatian',
  };

  @override
  void dispose() {
    _voiceController
      ..removeListener(_handleControllerChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/daily_horizon_icon.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              semanticLabel: 'Simbol Daily Horizon',
            ),
            const SizedBox(width: 10),
            Text(
              AppStrings.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Status Interaksi Awal: Siap Digunakan
              Center(
                child: Semantics(
                  liveRegion: true,
                  label: 'Status interaksi: $_statusLabel',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_voiceController.errorMessage case final errorMessage?) ...[
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ],

              // 2. Area Interaksi Utama yang Diperbesar (Visual Focus & Interaksi Sentuh)
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Area interaksi utama',
                  hint: AppStrings.touchAreaSubtitle,
                  child: Material(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                      key: const Key('touch_area_inkwell'),
                      borderRadius: BorderRadius.circular(28),
                      onTap: _handleTouchAreaTap,
                      splashColor: AppColors.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      highlightColor: AppColors.primaryContainer.withValues(
                        alpha: 0.2,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.border, width: 2),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 32,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Ikon Visual Utama Diperbesar
                                  Container(
                                    width: 124,
                                    height: 124,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.secondary,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.mic_none_rounded,
                                      size: 64,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Judul Area Diperbesar
                                  Text(
                                    AppStrings.touchAreaTitle,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Subtitle / Petunjuk
                                  Text(
                                    AppStrings.touchAreaSubtitle,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Petunjuk Contoh Perintah Suara
              Semantics(
                label: AppStrings.commandHints,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Text(
                    AppStrings.commandHints,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
