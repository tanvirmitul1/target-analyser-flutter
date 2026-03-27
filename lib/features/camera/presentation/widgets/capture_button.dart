import 'package:flutter/material.dart';

class CaptureButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isReady && !isCapturing ? onCapture : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white38, width: 4),
        ),
        child: isCapturing
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.camera, color: Colors.black, size: 32),
      ),
    );
  }
}
