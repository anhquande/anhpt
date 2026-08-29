import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/local_profile.dart';

class ProfileAvatar extends StatelessWidget {
  final LocalProfile profile;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.profile,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    MemoryImage? image;
    final encoded = profile.avatarBase64;
    if (encoded != null && encoded.isNotEmpty) {
      try {
        image = MemoryImage(base64Decode(encoded));
      } catch (_) {
        image = null;
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: image,
      child: image == null
          ? Text(
              profile.name.trim().isEmpty
                  ? '?'
                  : profile.name.trim()[0].toUpperCase(),
            )
          : null,
    );
  }
}
