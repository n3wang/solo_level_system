import 'package:flutter/material.dart';

class CameraButtonWidget extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasImage;

  const CameraButtonWidget({
    Key? key,
    required this.onTap,
    required this.hasImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: hasImage
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? Colors.green : Colors.orange,
            width: 2,
          ),
        ),
        child: Icon(
          hasImage ? Icons.camera_alt : Icons.camera_alt_outlined,
          size: 24,
          color: hasImage ? Colors.green : Colors.orange,
        ),
      ),
    );
  }
}