import 'package:flutter/material.dart';

/// Maps a companion mood key to the accent colour used throughout the UI
/// (status banner glow, orb shadow, metric card tints, etc.).
Color statusColorForMood(String moodKey) {
  switch (moodKey) {
    case 'sleepy':
      return const Color(0xFFFFB133);
    case 'overheated':
      return const Color(0xFFFF5D73);
    case 'hungry':
      return const Color(0xFFFF8C42);
    case 'busy':
      return const Color(0xFFB05BFF);
    case 'relieved':
      return const Color(0xFF58D68D);
    case 'bored':
      return const Color(0xFF8899AA);
    case 'waiting':
      return const Color(0xFF7E8CA3);
    case 'chill':
    default:
      return const Color(0xFF58D7FF);
  }
}