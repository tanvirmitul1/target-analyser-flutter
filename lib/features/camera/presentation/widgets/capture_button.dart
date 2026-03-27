import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shutter button with a scale-down animation on press and a spinner while
/// capturing.
class CaptureButton extends StatefulWidget {
  const CaptureButton({
    required this.isCapturing,
    required this.isReady,
    required this.onCapture,
    super.key,
  });

  final bool isCapturing;
  final bool isReady;
  final VoidCallback onCapture;

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canCapture => widget.isReady && !widget.isCapturing;

  void _onTapDown(TapDownDetails _) {
    if (!_canCapture) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (!_canCapture) return;
    _controller.reverse();
    HapticFeedback.mediumImpact();
    widget.onCapture();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: _ButtonFace(
          isCapturing: widget.isCapturing,
          isReady: _canCapture,
        ),
      ),
    );
  }
}

class _ButtonFace extends StatelessWidget {
  const _ButtonFace({required this.isCapturing, required this.isReady});
  final bool isCapturing;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isReady
                    ? Colors.white
                    : Colors.white38,
                width: 3,
              ),
            ),
          ),
          // Inner filled circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isReady ? Colors.white : Colors.white38,
            ),
            child: isCapturing
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      color: Colors.black87,
                      strokeWidth: 2.5,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
