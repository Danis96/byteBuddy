import 'package:flutter/material.dart';

import '../../../provider/companion_provider.dart';

class BuddyOrb extends StatelessWidget {
  const BuddyOrb({
    super.key,
    required this.color,
    required this.size,
    required this.mood,
  });

  final Color color;
  final double size;
  final CompanionMood mood;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFF304968), Color(0xFF273B56)],
            radius: 0.95,
          ),
          border: Border.all(
            color: const Color(0xFF45C9FF).withValues(alpha: 0.65),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OrbEyes(mood: mood, size: size),
            SizedBox(height: size * 0.12),
            OrbMouth(mood: mood, size: size),
          ],
        ),
      ),
    );
  }
}


class OrbEyes extends StatelessWidget {
  const OrbEyes({super.key, required this.mood, required this.size});

  final CompanionMood mood;
  final double size;

  static const _faceColor = Color(0xFF9BE9C4);

  @override
  Widget build(BuildContext context) {
    final eyeSize = size * 0.08;
    final eyeGap = size * 0.16;

    switch (mood) {
      case CompanionMood.sleepy:
        return _TextEyes(
          text: '-   -',
          color: _faceColor,
          fontSize: size * 0.12,
          letterSpacing: size * 0.02,
          fontWeight: FontWeight.w900,
        );

      case CompanionMood.bored:
        return _TextEyes(
          text: '-   -',
          color: _faceColor.withValues(alpha: 0.9),
          fontSize: size * 0.11,
          letterSpacing: size * 0.02,
          fontWeight: FontWeight.w700,
        );

      case CompanionMood.hungry:
      case CompanionMood.overheated:
        return _TextEyes(
          text: 'o   o',
          color: _faceColor,
          fontSize: size * 0.11,
          letterSpacing: size * 0.02,
          fontWeight: FontWeight.w900,
        );

      case CompanionMood.waiting:
        return _DotEyes(eyeSize: eyeSize * 0.75, eyeGap: eyeGap);

      case CompanionMood.busy:
        return _TiltedDotEyes(eyeSize: eyeSize, eyeGap: eyeGap);

      case CompanionMood.relieved:
      case CompanionMood.chill:
        return _DotEyes(eyeSize: eyeSize, eyeGap: eyeGap);
    }
  }
}

class _TextEyes extends StatelessWidget {
  const _TextEyes({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.letterSpacing,
    required this.fontWeight,
  });

  final String text;
  final Color color;
  final double fontSize;
  final double letterSpacing;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: fontWeight,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
      ),
    );
  }
}

class _DotEyes extends StatelessWidget {
  const _DotEyes({required this.eyeSize, required this.eyeGap});

  final double eyeSize;
  final double eyeGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FaceDot(size: eyeSize),
        SizedBox(width: eyeGap),
        FaceDot(size: eyeSize),
      ],
    );
  }
}

class _TiltedDotEyes extends StatelessWidget {
  const _TiltedDotEyes({required this.eyeSize, required this.eyeGap});

  final double eyeSize;
  final double eyeGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.rotate(angle: -0.15, child: FaceDot(size: eyeSize)),
        SizedBox(width: eyeGap),
        Transform.rotate(angle: 0.15, child: FaceDot(size: eyeSize)),
      ],
    );
  }
}

class OrbMouth extends StatelessWidget {
  const OrbMouth({super.key, required this.mood, required this.size});

  final CompanionMood mood;
  final double size;

  static const _faceColor = Color(0xFF9BE9C4);

  @override
  Widget build(BuildContext context) {
    final mouthWidth = size * 0.22;
    final mouthHeight = size * 0.09;

    switch (mood) {
      case CompanionMood.sleepy:
        return _FlatMouth(width: mouthWidth * 0.9, color: _faceColor.withValues(alpha: 0.9));

      case CompanionMood.bored:
        return _FlatMouth(width: mouthWidth * 0.8, color: _faceColor.withValues(alpha: 0.85));

      case CompanionMood.busy:
        return _BarMouth(width: mouthWidth, color: _faceColor);

      case CompanionMood.overheated:
        return _TextMouth(text: 'o', fontSize: size * 0.14, color: _faceColor);

      case CompanionMood.hungry:
        return _TextMouth(text: '⌂', fontSize: size * 0.12, color: _faceColor);

      case CompanionMood.relieved:
        return _SmileMouth(
          width: mouthWidth,
          height: mouthHeight,
          color: _faceColor,
          cheekDotSize: size * 0.04,
        );

      case CompanionMood.waiting:
        return _CircleMouth(size: mouthWidth * 0.45, color: _faceColor);

      case CompanionMood.chill:
        return _SmileMouth(
          width: mouthWidth,
          height: mouthHeight,
          color: _faceColor,
        );
    }
  }
}

class _FlatMouth extends StatelessWidget {
  const _FlatMouth({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: width, height: 2, color: color);
  }
}

class _BarMouth extends StatelessWidget {
  const _BarMouth({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _TextMouth extends StatelessWidget {
  const _TextMouth({
    required this.text,
    required this.fontSize,
    required this.color,
  });

  final String text;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: fontSize),
    );
  }
}

class _SmileMouth extends StatelessWidget {
  const _SmileMouth({
    required this.width,
    required this.height,
    required this.color,
    this.cheekDotSize,
  });

  final double width;
  final double height;
  final Color color;
  final double? cheekDotSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color, width: 3)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: cheekDotSize != null
          ? Align(
        alignment: Alignment.topRight,
        child: Container(
          width: cheekDotSize,
          height: cheekDotSize,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
        ),
      )
          : null,
    );
  }
}

class _CircleMouth extends StatelessWidget {
  const _CircleMouth({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class FaceDot extends StatelessWidget {
  const FaceDot({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF9BE9C4),
      ),
    );
  }
}