import 'dart:ui';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings_providers.dart';

class WalkthroughDialog extends ConsumerStatefulWidget {
  final bool isFirstStart;

  const WalkthroughDialog({super.key, required this.isFirstStart});

  static void show(BuildContext context, {required bool isFirstStart}) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return WalkthroughDialog(isFirstStart: isFirstStart);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 5.0 * anim1.value,
            sigmaY: 5.0 * anim1.value,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<WalkthroughDialog> createState() => _WalkthroughDialogState();
}

class _WalkthroughDialogState extends ConsumerState<WalkthroughDialog>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  bool _showWelcome = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _showWelcome = widget.isFirstStart;

    // Animation controller for custom illustrations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _completeTutorial() async {
    await ref.read(settingsProvider.notifier).updateTutorialStatus('completed');
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _dismissTutorial() async {
    await ref.read(settingsProvider.notifier).updateTutorialStatus('dismissed');
    if (mounted) Navigator.of(context).pop();
  }

  void _showLater() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Container(
            width: landscape ? 680 : 380,
            constraints: BoxConstraints(maxHeight: landscape ? 400 : 560),
            margin: EdgeInsets.all(landscape ? 12 : 20),
            decoration: BoxDecoration(
              color: context.palette.paper,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: context.palette.ink.withValues(alpha: 0.05),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _showWelcome
                ? _buildWelcomeView(landscape)
                : _buildWalkthroughView(landscape),
          ),
        ),
      ),
    );
  }

  // Welcome page that prompts the user on startup
  Widget _buildWelcomeView(bool landscape) {
    final intro = SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Stylized Logo Circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.palette.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.palette.ink.withValues(alpha: 0.06),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.mouse_outlined,
              size: 36,
              color: context.palette.ink.withValues(alpha: 0.87),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Welcome to CouchMouse",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.palette.ink,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Turn your phone into a mouse and keyboard for your computer over Bluetooth.\n\nWould you like a quick walkthrough of how to pair and control your device?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.palette.ink.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
    final actions = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Get Started (Start Walkthrough)
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showWelcome = false;
              });
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: context.palette.paper,
              backgroundColor: context.palette.ink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Get Started",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Show Later
              Expanded(
                child: OutlinedButton(
                  onPressed: _showLater,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.palette.ink.withValues(
                      alpha: 0.87,
                    ),
                    side: BorderSide(
                      color: context.palette.ink.withValues(alpha: 0.12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Show Later",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Don't Show Again
              Expanded(
                child: OutlinedButton(
                  onPressed: _dismissTutorial,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.palette.ink.withValues(
                      alpha: 0.54,
                    ),
                    side: BorderSide(
                      color: context.palette.ink.withValues(alpha: 0.12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Don't Show Again",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: landscape ? 16 : 28,
      ),
      child: landscape
          ? Row(
              children: [
                Expanded(flex: 3, child: intro),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: actions),
              ],
            )
          : Column(
              children: [
                Expanded(child: intro),
                const SizedBox(height: 20),
                actions,
              ],
            ),
    );
  }

  Widget _buildWalkthroughView(bool landscape) {
    final steps = [
      (
        title: '1. Bluetooth Connection',
        description:
            '• Unpair previous connections on both devices.\n'
            '• Tap the Bluetooth connection bar on the main screen.\n'
            '• Tap "Make Discoverable" on the app.\n'
            '• On your host computer, select your phone in the Bluetooth settings to pair.\n'
            '• After initial pairing, you can always connect/reconnect using the in-app connection menu.',
        illustration: _buildConnectionIllustration(),
      ),
      (
        title: '2. Mouse Controls & Gestures',
        description:
            '• Slide one finger on the trackpad to move mouse cursor.\n'
            '• Single tap with one finger to Left-Click.\n'
            '• Tap the tactile buttons at the bottom to Left/Right Click.\n'
            '• Swipe up below the trackpad area to bring up the keyboard.\n'
            '• Swipe right below the trackpad area to bring up the settings.',
        illustration: _buildTrackpadIllustration(),
      ),
      (
        title: '3. Scrolling & Settings Swipe',
        description:
            '• Scroll by dragging on the right-side Scroll Wheel, or swipe with two fingers anywhere on the trackpad.\n'
            '• Swipe from the left edge of the screen to open the settings drawer.\n'
            '• You can control mouse sensitivity, keyboard layout, and many other bits in the settings.',
        illustration: _buildScrollIllustration(),
      ),
      (
        title: '4. Virtual Keyboard',
        description:
            '• Swipe up from the bottom of the screen or tap the keyboard icon to toggle the keyboard.\n'
            '• Use the accessory toolbar to toggle Ctrl, Alt, Shift, and Lock modifier keys.\n'
            '• Turn on Rich Typing Mode in Advanced settings to write a message with autocorrect, then send it.\n'
            '• Flip to landscape mode to view a wider emulated keyboard.',
        illustration: _buildKeyboardIllustration(),
      ),
    ];

    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(20, landscape ? 4 : 16, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "TUTORIAL: STEP ${_currentPage + 1} OF ${steps.length}",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.palette.ink.withValues(alpha: 0.35),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark, size: 18),
                color: context.palette.ink.withValues(alpha: 0.54),
                onPressed: _completeTutorial,
                tooltip: "Close tutorial",
              ),
            ],
          ),
        ),

        // Page view content
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final illustration = _illustrationCard(step.illustration);
              final instructions = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.palette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: context.palette.ink.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              );

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: landscape
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 2, child: illustration),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 3,
                            child: SingleChildScrollView(
                              key: PageStorageKey(index),
                              primary: false,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: instructions,
                            ),
                          ),
                        ],
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              key: PageStorageKey(index),
                              primary: false,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 140,
                                        width: double.infinity,
                                        child: illustration,
                                      ),
                                      const SizedBox(height: 16),
                                      instructions,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      ),
              );
            },
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, landscape ? 10 : 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_currentPage < steps.length - 1) ...[
                Flexible(
                  child: TextButton(
                    onPressed: _completeTutorial,
                    style: TextButton.styleFrom(
                      foregroundColor: context.palette.ink.withValues(
                        alpha: 0.68,
                      ),
                    ),
                    child: const Text(
                      "Skip",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < steps.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _completeTutorial();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: context.palette.paper,
                    backgroundColor: context.palette.ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == steps.length - 1 ? "Finish" : "Next",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _illustrationCard(Widget illustration) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.ink.withValues(alpha: 0.04)),
      ),
      clipBehavior: Clip.antiAlias,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 220,
          height: 112,
          child: Center(child: illustration),
        ),
      ),
    );
  }

  // --- Beautiful Animated Illustration Builders ---

  // Slide 1: Pulsing Bluetooth signal between Phone and Laptop
  Widget _buildConnectionIllustration() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Value range [0.0, 1.0]
        final double pulse = _animationController.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Phone Icon
            Icon(
              CupertinoIcons.device_phone_portrait,
              size: 48,
              color: context.palette.ink.withValues(alpha: 0.87),
            ),
            const SizedBox(width: 8),
            // Pulsing dot signals
            SizedBox(
              width: 100,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children:
                    List.generate(3, (index) {
                      // Phase shift the waves
                      final double waveVal = (pulse + index / 3.0) % 1.0;
                      final double opacity = (1.0 - waveVal) * 0.8;
                      final double scale = 0.2 + waveVal * 0.8;
                      return Positioned(
                        left: 10.0 + (waveVal * 70.0),
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      );
                    })..add(
                      // Centered static blue tooth glyph outline overlay
                      const Icon(
                        CupertinoIcons.bluetooth,
                        color: Colors.blueAccent,
                        size: 24,
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            // Laptop Icon
            Icon(
              CupertinoIcons.device_laptop,
              size: 54,
              color: context.palette.ink.withValues(alpha: 0.87),
            ),
          ],
        );
      },
    );
  }

  // Slide 2: Trackpad and tap illustration
  Widget _buildTrackpadIllustration() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Animate a finger dot swiping in a small loop and tapping
        final double t = _animationController.value;

        // Loop phases
        // 0.0 - 0.5: finger moves around in loop
        // 0.5 - 0.7: finger lifts up
        // 0.7 - 0.8: tap down (creates ripple)
        // 0.8 - 1.0: finger lifts up again
        double xOffset = 0.0;
        double yOffset = 0.0;
        double fingerOpacity = 1.0;
        double rippleScale = 0.0;
        double rippleOpacity = 0.0;

        if (t < 0.5) {
          // Circular motion
          final double angle = t * 2.0 * 2.0 * 3.14159;
          xOffset = 30.0 * double.parse(MathExt.cos(angle).toStringAsFixed(4));
          yOffset = 18.0 * double.parse(MathExt.sin(angle).toStringAsFixed(4));
        } else if (t < 0.7) {
          // Fade/lift finger
          fingerOpacity = 1.0 - ((t - 0.5) / 0.2);
          xOffset = 0;
          yOffset = 0;
        } else if (t < 0.80) {
          // Tap down
          fingerOpacity = 1.0;
          final double tapProgress = (t - 0.7) / 0.1;
          rippleScale = tapProgress * 2.5;
          rippleOpacity = 1.0 - tapProgress;
        } else {
          // Lift up and fade
          fingerOpacity = 1.0 - ((t - 0.8) / 0.2);
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            // Simulated Trackpad Box
            Container(
              width: 160,
              height: 100,
              decoration: BoxDecoration(
                color: context.palette.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.palette.ink.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Dividing line for mouse buttons
                  Container(
                    height: 1,
                    color: context.palette.ink.withValues(alpha: 0.08),
                  ),
                  SizedBox(
                    height: 24,
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              "Left",
                              style: TextStyle(
                                fontSize: 9,
                                color: context.palette.ink.withValues(
                                  alpha: 0.38,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          color: context.palette.ink.withValues(alpha: 0.08),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              "Right",
                              style: TextStyle(
                                fontSize: 9,
                                color: context.palette.ink.withValues(
                                  alpha: 0.38,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Ripple tap animation
            if (rippleOpacity > 0)
              Transform.translate(
                offset: Offset(xOffset, yOffset - 10),
                child: Opacity(
                  opacity: rippleOpacity,
                  child: Container(
                    width: 24 * rippleScale,
                    height: 24 * rippleScale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.palette.ink.withValues(alpha: 0.54),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            // Finger cursor dot representation
            Opacity(
              opacity: fingerOpacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(xOffset, yOffset - 10),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: context.palette.ink.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Slide 3: Scroll Wheel and Edge swipe
  Widget _buildScrollIllustration() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double t = _animationController.value;
        // Scroll Wheel moves up/down
        final double scrollOffset =
            ((t < 0.5) ? t * 2.0 : (1.0 - (t - 0.5) * 2.0)) * 30.0 - 15.0;

        // Edge swipe opens drawer on left
        // Drawer opens during t = 0.5 to 1.0
        double drawerSlide = -40; // fully closed
        if (t > 0.5) {
          final double drawerProgress = (t - 0.5) / 0.5; // [0.0, 1.0]
          // Open then close
          if (drawerProgress < 0.6) {
            drawerSlide = -40.0 + (drawerProgress / 0.6) * 40.0;
          } else {
            drawerSlide = 0.0 - ((drawerProgress - 0.6) / 0.4) * 40.0;
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            // Screen Box representation
            Container(
              width: 180,
              height: 100,
              decoration: BoxDecoration(
                color: context.palette.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.palette.ink.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
            ),
            // Simulated side settings panel sliding out from left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Transform.translate(
                offset: Offset(drawerSlide, 0),
                child: Container(
                  width: 40,
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(11),
                      bottomLeft: Radius.circular(11),
                    ),
                    border: Border(
                      right: BorderSide(
                        color: context.palette.ink.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.settings,
                      size: 16,
                      color: context.palette.ink.withValues(alpha: 0.54),
                    ),
                  ),
                ),
              ),
            ),
            // Scroll Wheel representation on the right
            Positioned(
              right: 12,
              child: Container(
                width: 20,
                height: 70,
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: context.palette.ink.withValues(alpha: 0.08),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Moving scroll line
                    Positioned(
                      top: 35 + scrollOffset,
                      child: Container(
                        width: 16,
                        height: 3,
                        color: context.palette.ink.withValues(alpha: 0.38),
                      ),
                    ),
                    Positioned(
                      top: 35 + scrollOffset - 18,
                      child: Container(
                        width: 16,
                        height: 3,
                        color: context.palette.ink.withValues(alpha: 0.38),
                      ),
                    ),
                    Positioned(
                      top: 35 + scrollOffset + 18,
                      child: Container(
                        width: 16,
                        height: 3,
                        color: context.palette.ink.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Gestures hint labels
            Positioned(
              top: 8,
              left: 45,
              child: Opacity(
                opacity: t > 0.5 ? 0.9 : 0.2,
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_right,
                      size: 10,
                      color: Colors.blueAccent,
                    ),
                    SizedBox(width: 2),
                    Text(
                      "Swipe Drawer",
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: context.palette.ink.withValues(alpha: 0.87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 45,
              child: Opacity(
                opacity: t <= 0.5 ? 0.9 : 0.2,
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.up_arrow,
                      size: 8,
                      color: Colors.blueAccent,
                    ),
                    Icon(
                      CupertinoIcons.down_arrow,
                      size: 8,
                      color: Colors.blueAccent,
                    ),
                    SizedBox(width: 2),
                    Text(
                      "Scroll Wheel",
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: context.palette.ink.withValues(alpha: 0.87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Slide 4: Virtual Keyboard & Accessories
  Widget _buildKeyboardIllustration() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double t = _animationController.value;
        // Animate key taps: key indexes flash active
        final int activeKeyIndex = (t * 12).floor() % 12;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Keyboard Shell
            Container(
              width: 180,
              height: 100,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.palette.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.palette.ink.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Accessories bar
                  Container(
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: context.palette.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: context.palette.ink.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 24,
                          height: 10,
                          decoration: BoxDecoration(
                            color: activeKeyIndex < 4
                                ? context.palette.ink.withValues(alpha: 0.87)
                                : context.palette.ink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Ctrl",
                            style: TextStyle(
                              fontSize: 5,
                              color: context.palette.paper,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 10,
                          decoration: BoxDecoration(
                            color: activeKeyIndex >= 4 && activeKeyIndex < 8
                                ? context.palette.ink.withValues(alpha: 0.87)
                                : context.palette.ink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Shift",
                            style: TextStyle(
                              fontSize: 5,
                              color: context.palette.paper,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 10,
                          decoration: BoxDecoration(
                            color: context.palette.ink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Alt",
                            style: TextStyle(
                              fontSize: 5,
                              color: context.palette.ink.withValues(
                                alpha: 0.54,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Key Grid Representation
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            crossAxisSpacing: 3,
                            mainAxisSpacing: 3,
                            childAspectRatio: 1.5,
                          ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final bool isActive = index == activeKeyIndex;
                        return Container(
                          decoration: BoxDecoration(
                            color: isActive
                                ? context.palette.ink.withValues(alpha: 0.87)
                                : context.palette.surface,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: context.palette.ink.withValues(
                                alpha: isActive ? 0.0 : 0.06,
                              ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "A",
                            style: TextStyle(
                              fontSize: 8,
                              color: isActive
                                  ? context.palette.paper
                                  : context.palette.ink.withValues(alpha: 0.54),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Math extensions helper to bypass direct Math imports and dynamic compilation limitations if any
class MathExt {
  static double cos(double x) {
    // Simple Taylor series approximation for cosine around 0 for visual purposes
    x = x % (2 * 3.14159265);
    if (x < 0) x = -x;
    double t = 1.0;
    double sum = 1.0;
    for (int i = 1; i <= 6; i++) {
      t = -t * x * x / ((2 * i - 1) * (2 * i));
      sum += t;
    }
    return sum;
  }

  static double sin(double x) {
    // Simple Taylor series approximation for sine
    x = x % (2 * 3.14159265);
    double t = x;
    double sum = x;
    for (int i = 1; i <= 6; i++) {
      t = -t * x * x / ((2 * i) * (2 * i + 1));
      sum += t;
    }
    return sum;
  }
}
