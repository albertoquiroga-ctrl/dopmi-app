import 'package:flutter/material.dart';

/// Irlanda: b9f6d5f, final warm-trust CSS (minimal clean), not its older palette notes.
/// Product rules remain in repositories/server; legacy names stay source-compatible.
abstract final class DopmiTokens {
  static const ink = Color(0xff46281d);
  static const muted = Color(0xff7a655c);
  static const surface = Color(0xffffffff);
  static const line = Color(0xffe8e8e8);
  static const yellow = Color(0xfffab919);
  static const yellowStrong = Color(0xffe5a800);
  static const yellowInk = ink;
  // The reference keeps --purple as an alias to café in warm-trust.
  static const purple = ink;
  static const orange = Color(0xffeb6425);
  static const orangeStrong = Color(0xffd25a1f);
  // White small-button text needs 4.5:1; reference orange is 3.29:1.
  static const orangeButton = Color(0xffc1511c); // 4.71:1 on white.
  static const cafeStrong = Color(0xff362017);
  static const sky = Color(0xffcbe8fa);
  static const saffronSoft = Color(0xfffef3d4);
  static const orangeSoft = Color(0x1feb6425);
  static const yellowSoft = Color(0x2efab919);
  static const canvasMuted = Color(0xfffafafa);
  static const navigationInactive = Color(0xff8a837c);
  static const tealInk = Color(0xff0b7a5d);
  static const danger = Color(0xffb51224);
  static const cardRadius = 18.0;
  static const fieldRadius = 12.0;
  static const horizontalPadding = 16.0;
  static const bodyFont = 'Inter';
  static const displayFont = bodyFont;
  static const legacyDisplayFont = 'Fraunces';
  // Legacy Fraunces axis aliases remain available to existing consumers.
  // The current theme uses Inter without these display-only variations.
  static const display20Variations = [
    FontVariation('opsz', 20),
    FontVariation('WONK', 0),
  ];
  static const display22Variations = [
    FontVariation('opsz', 22),
    FontVariation('WONK', 0),
  ];
  static const display24Variations = [
    FontVariation('opsz', 24),
    FontVariation('WONK', 0),
  ];
  static const display26Variations = [
    FontVariation('opsz', 26),
    FontVariation('WONK', 0),
  ];
  static const display28Variations = [
    FontVariation('opsz', 28),
    FontVariation('WONK', 0),
  ];
  static const display32Variations = [
    FontVariation('opsz', 32),
    FontVariation('WONK', 0),
  ];
  static const display36Variations = [
    FontVariation('opsz', 36),
    FontVariation('WONK', 0),
  ];
}
