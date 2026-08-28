import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';

Future<DemoMediaSource?> chooseDemoMediaSource(BuildContext context) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return DemoMediaSource.device;
  }

  return showModalBottomSheet<DemoMediaSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Add demonstration',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () =>
                Navigator.pop(context, DemoMediaSource.cameraPhoto),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Record video'),
            onTap: () =>
                Navigator.pop(context, DemoMediaSource.cameraVideo),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Choose from device'),
            onTap: () => Navigator.pop(context, DemoMediaSource.device),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
