import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/account_provider.dart';
import '../services/qr_parser_service.dart';
import '../theme.dart';
import '../widgets/scan_confirm_sheet.dart';
import '../widgets/scan_overlay.dart';
import 'add_account_screen.dart';

/// Full-screen QR code scanner screen powered by mobile_scanner.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isProcessing) {
          _controller.start();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _controller.stop();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resumeScanning() async {
    try {
      await _controller.start();
    } catch (_) {}
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  void _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final account = QrParserService.parseOtpauthUri(raw);

      // Trigger tactile haptic confirmation
      HapticFeedback.mediumImpact();

      // Pause camera stream while user confirms
      await _controller.stop();

      if (!mounted) return;

      final action = await ScanConfirmSheet.show(context, account);

      if (!mounted) return;

      if (action == ScanConfirmAction.save) {
        await context.read<AccountProvider>().addAccount(account);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.accountSavedMessage(account.name)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      } else if (action == ScanConfirmAction.edit) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AddAccountScreen(initialAccount: account),
          ),
        );
        if (!mounted) return;
        if (result == true) {
          Navigator.pop(context, true);
        } else {
          _resumeScanning();
        }
      } else {
        // User dismissed sheet: resume camera
        _resumeScanning();
      }
    } on QrParseException catch (e) {
      HapticFeedback.lightImpact();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${e.message}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Re-enable scanning after brief debounce
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.accentRed,
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Viewfinder
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.videocam_off_outlined,
                        size: 64,
                        color: AppTheme.accentRed,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.cameraAccessDenied,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? l10n.cameraPermissionPrompt
                            : 'Camera error: ${error.errorDetails?.message ?? error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddAccountScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.keyboard, color: Colors.white),
                        label: Text(
                          l10n.enterManualFallback,
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. HUD Cutout & Laser Scan Overlay
          const ScanOverlay(scanWindowSize: 260.0),

          // 3. Top Action Controls Bar
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button
                    _buildGlassCircleButton(
                      icon: Icons.close,
                      tooltip: l10n.close,
                      onPressed: () => Navigator.pop(context),
                    ),

                    Row(
                      children: [
                        // Torch toggle
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (context, state, _) {
                            final isOn = state.torchState == TorchState.on;
                            return _buildGlassCircleButton(
                              icon: isOn ? Icons.flash_on : Icons.flash_off,
                              tooltip: l10n.flashTooltip,
                              color: isOn ? Colors.amber : Colors.white,
                              onPressed: () => _controller.toggleTorch(),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        // Switch camera toggle
                        _buildGlassCircleButton(
                          icon: Icons.flip_camera_ios_outlined,
                          tooltip: l10n.cameraSwitchTooltip,
                          onPressed: () => _controller.switchCamera(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom manual entry shortcut
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddAccountScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.keyboard_outlined, color: Colors.white),
                  label: Text(
                    l10n.enterManualFallback,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Color color = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
