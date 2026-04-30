import 'package:flutter/material.dart';

class VocalinLogo extends StatelessWidget {
  const VocalinLogo({
    super.key,
    this.size = 48,
    this.showText = true,
    this.textGradient,
  });

  final double size;
  final bool showText;
  final Gradient? textGradient;

  @override
  Widget build(BuildContext context) {
    const blueColor = Color(0xFF2B5D88);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return (textGradient ??
                      const LinearGradient(
                        colors: [blueColor, blueColor],
                      ))
                  .createShader(bounds);
            },
            child: Text(
              'Vocalin',
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: blueColor,
                height: 1,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
