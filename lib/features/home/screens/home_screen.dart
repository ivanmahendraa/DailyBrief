import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/accessibility_shortcut_service.dart';
import '../../../services/speech_to_text_service.dart';
import '../../../services/tts_service.dart';
import '../../voice/voice_controller.dart';

/// Menyediakan halaman utama untuk memulai interaksi suara dengan DailyBrief.
///
/// Menampilkan elemen utama berikut:
/// - Menyertakan simbol aplikasi dan status interaksi.
/// - Menyediakan area sentuh untuk memulai pengenalan suara dengan umpan balik haptik.
/// - Menampilkan petunjuk perintah dan dialog atribusi sumber data.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onTouchAreaTap;
  final VoiceController? voiceController;
  final SpeechToTextService? speechToTextService;
  final TtsService? ttsService;
  final AccessibilityShortcutClient? accessibilityShortcutClient;

  const HomeScreen({
    super.key,
    this.onTouchAreaTap,
    this.voiceController,
    this.speechToTextService,
    this.ttsService,
    this.accessibilityShortcutClient,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late VoiceController _voiceController;
  late TtsService _ttsService;
  late AccessibilityShortcutClient _shortcutClient;
  bool _handlingTouch = false;
  bool _handlingActivation = false;
  bool _homeReady = false;
  bool _shortcutRequestPending = false;
  Future<void>? _welcomeGreetingFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ttsService = widget.ttsService ?? TtsService();
    _shortcutClient =
        widget.accessibilityShortcutClient ??
        MethodChannelAccessibilityShortcutClient();
    _voiceController = _createVoiceController();
    _voiceController.addListener(_handleControllerChange);
    if (_supportsAccessibilityShortcut) {
      _shortcutClient.setShortcutRequestHandler(_onShortcutRequested);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _homeReady = true;
      unawaited(_initializeAccessibilityShortcut());
    });
  }

  bool get _supportsAccessibilityShortcut =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _isResumed =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  Future<void> _playWelcomeGreeting() async {
    if (MediaQuery.of(context).accessibleNavigation) return;

    try {
      final result = await _ttsService.speak(AppStrings.welcomeGreeting);
      if (result.isFailure) {
        debugPrint(
          'HomeScreen welcome greeting playback error: '
          '${result.errorMessage}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'HomeScreen welcome greeting playback error: $error\n$stackTrace',
      );
    }
  }

  Future<void> _initializeAccessibilityShortcut() async {
    if (!_supportsAccessibilityShortcut) {
      _startWelcomeGreeting();
      return;
    }

    try {
      if (await _shortcutClient.consumePendingShortcut()) {
        _shortcutRequestPending = true;
      }
    } on MissingPluginException {
      debugPrint('Accessibility shortcut channel is unavailable.');
    } on PlatformException catch (error) {
      debugPrint(
        'Accessibility shortcut initialization failed: ${error.message}',
      );
    }

    if (!mounted) return;
    if (_shortcutRequestPending) {
      unawaited(_tryStartShortcutListening());
    } else {
      _startWelcomeGreeting();
    }
  }

  void _startWelcomeGreeting() {
    if (!mounted || _welcomeGreetingFuture != null) return;
    final greeting = _playWelcomeGreeting();
    _welcomeGreetingFuture = greeting;
    unawaited(
      greeting.whenComplete(() {
        if (!mounted) return;
        _welcomeGreetingFuture = null;
        unawaited(_tryStartShortcutListening());
      }),
    );
  }

  void _onShortcutRequested() {
    _shortcutRequestPending = true;
    unawaited(_acknowledgeShortcutRequest());
  }

  Future<void> _acknowledgeShortcutRequest() async {
    try {
      await _shortcutClient.consumePendingShortcut();
    } on MissingPluginException {
      debugPrint('Accessibility shortcut channel is unavailable.');
    } on PlatformException catch (error) {
      debugPrint(
        'Accessibility shortcut acknowledgement failed: ${error.message}',
      );
    }

    if (mounted && _homeReady) {
      await _tryStartShortcutListening();
    }
  }

  Future<void> _tryStartShortcutListening() async {
    if (!mounted ||
        !_homeReady ||
        !_shortcutRequestPending ||
        !_isResumed ||
        _welcomeGreetingFuture != null) {
      return;
    }

    if (_voiceController.state != VoiceInteractionState.idle ||
        _voiceController.hasActiveSession ||
        _handlingActivation) {
      _shortcutRequestPending = false;
      return;
    }

    _shortcutRequestPending = false;
    await _activateListening(requireResumed: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_tryStartShortcutListening());
    }
  }

  VoiceController _createVoiceController() =>
      widget.voiceController ??
      VoiceController(
        speechToTextService: widget.speechToTextService,
        ttsService: _ttsService,
      );

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ttsService != widget.ttsService) {
      _ttsService = widget.ttsService ?? TtsService();
    }
    if (oldWidget.accessibilityShortcutClient !=
        widget.accessibilityShortcutClient) {
      _shortcutClient.setShortcutRequestHandler(null);
      _shortcutClient =
          widget.accessibilityShortcutClient ??
          MethodChannelAccessibilityShortcutClient();
      if (_supportsAccessibilityShortcut) {
        _shortcutClient.setShortcutRequestHandler(_onShortcutRequested);
      }
    }
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
      unawaited(_activateListening());
      widget.onTouchAreaTap?.call();
    } finally {
      _handlingTouch = false;
    }
  }

  Future<void> _activateListening({bool requireResumed = false}) async {
    if (!mounted ||
        (requireResumed && !_isResumed) ||
        _handlingActivation ||
        _voiceController.state != VoiceInteractionState.idle ||
        _voiceController.hasActiveSession) {
      return;
    }

    _handlingActivation = true;
    try {
      await _voiceController.handleUserTap();
    } finally {
      _handlingActivation = false;
    }
  }

  Future<void> _openAccessibilitySettings() async {
    Navigator.of(context).pop();
    try {
      await _shortcutClient.openAccessibilitySettings();
    } on PlatformException catch (error) {
      _showSettingsError(error.message);
    } on MissingPluginException {
      _showSettingsError(null);
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await _shortcutClient.openAppSettings();
    } on PlatformException catch (error) {
      _showSettingsError(error.message);
    } on MissingPluginException {
      _showSettingsError(null);
    }
  }

  void _showSettingsError(String? message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message == null || message.isEmpty
              ? 'Pengaturan Android tidak dapat dibuka.'
              : 'Pengaturan Android tidak dapat dibuka: $message',
        ),
      ),
    );
  }

  void _showAccessibilityShortcutHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('DailyBrief Accessibility Shortcut'),
        content: const SingleChildScrollView(
          child: Text(
            'Layanan ini hanya membuka DailyBrief saat tombol Aksesibilitas '
            'ditekan. Layanan tidak membaca isi layar aplikasi lain dan tidak '
            'mengaktifkan mikrofon saat layanan dinyalakan.\n\n'
            'Untuk mengaktifkan: buka Pengaturan Aksesibilitas Android, pilih '
            'DailyBrief Accessibility Shortcut, lalu nyalakan dengan '
            'persetujuan Anda. Untuk menonaktifkan, matikan layanan di '
            'halaman yang sama.\n\n'
            'Untuk menggunakan: tekan tombol Aksesibilitas di navigasi layar '
            'atau gestur pintasan yang disediakan perangkat. Ketersediaan dan '
            'letak tombol berbeda menurut versi Android dan produsen.\n\n'
            'Kombinasi Volume Naik + Volume Turun adalah pintasan sistem untuk '
            'mengubah status layanan pada perangkat yang mendukungnya; '
            'kombinasi itu bukan perintah tombol yang diterima aplikasi. '
            'Tombol Power tidak dapat diambil alih aplikasi biasa. Android '
            'juga dapat membatasi pembukaan aplikasi dari latar belakang atau '
            'ketika layar terkunci.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
          TextButton(
            onPressed: _openAccessibilitySettings,
            child: const Text('Buka pengaturan'),
          ),
        ],
      ),
    );
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
    WidgetsBinding.instance.removeObserver(this);
    _shortcutClient.setShortcutRequestHandler(null);
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
            const SizedBox(width: 4),
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
        actions: [
          IconButton(
            tooltip: AppStrings.dataSourcesTooltip,
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: AppStrings.appName,
                children: [
                  const Text(AppStrings.dataSourcesAttribution),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showAccessibilityShortcutHelp();
                    },
                    icon: const Icon(Icons.accessibility_new),
                    label: const Text('Panduan pintasan aksesibilitas'),
                  ),
                ],
              );
            },
          ),
        ],
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
                if (errorMessage == VoiceController.permissionDeniedMessage)
                  TextButton.icon(
                    onPressed: _openAppSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Buka pengaturan izin mikrofon'),
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
              const SizedBox(height: 6),
              if (kDebugMode &&
                  defaultTargetPlatform == TargetPlatform.iOS) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        unawaited(
                          FirebaseCrashlytics.instance.recordError(
                            StateError('Crashlytics debug non-fatal test'),
                            StackTrace.current,
                            reason: 'Temporary iOS debug test',
                          ),
                        );
                      },
                      icon: const Icon(Icons.bug_report_outlined),
                      label: const Text('Uji error non-fatal'),
                    ),
                    TextButton.icon(
                      onPressed: FirebaseCrashlytics.instance.crash,
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Uji crash'),
                    ),
                  ],
                ),
                // TODO: Remove temporary Crashlytics test controls after iOS verification.
              ],
            ],
          ),
        ),
      ),
    );
  }
}
