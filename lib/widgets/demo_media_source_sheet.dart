import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_controller.dart';
import '../models/media_asset.dart';

enum DemoMediaSource {
  cameraPhoto,
  cameraVideo,
  device,
}

Future<MediaAsset?> pickDemoMedia(
  BuildContext context,
  AppController controller,
) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return controller.importDemoMedia();
  }

  final source = await showModalBottomSheet<DemoMediaSource>(
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
  if (source == null) return null;

  final picker = ImagePicker();
  switch (source) {
    case DemoMediaSource.cameraPhoto:
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (picked == null) return null;
      return _importFile(controller, File(picked.path), type: 'image');
    case DemoMediaSource.cameraVideo:
      final picked = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked == null) return null;
      return _importFile(controller, File(picked.path), type: 'video');
    case DemoMediaSource.device:
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choose exercise demonstration media',
        type: FileType.custom,
        allowedExtensions: const [
          'mp4',
          'mov',
          'webm',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
        ],
      );
      if (result == null) return null;
      final picked = result.files.single;
      if (picked.path == null) {
        throw StateError('Could not read the selected media file.');
      }
      final extension = picked.extension?.toLowerCase() ?? '';
      final type = extension == 'gif'
          ? 'animation'
          : {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
              ? 'image'
              : 'video';
      return _importFile(controller, File(picked.path!), type: type);
  }
}

Future<MediaAsset> _importFile(
  AppController controller,
  File file, {
  required String type,
}) async {
  if (await file.length() > 20 * 1024 * 1024) {
    throw StateError('Demonstration media must be 20 MB or smaller.');
  }
  return controller.mediaLibrary.importFile(file, type: type);
}
