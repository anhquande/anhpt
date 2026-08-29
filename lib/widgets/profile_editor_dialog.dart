import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/health.dart';

class ProfileEditResult {
  final String name;
  final HealthProfile health;
  final String? avatarBase64;

  const ProfileEditResult({
    required this.name,
    required this.health,
    this.avatarBase64,
  });
}

Future<ProfileEditResult?> showProfileEditorDialog(
  BuildContext context, {
  required String title,
  required String initialName,
  required HealthProfile initialHealth,
  String? initialAvatarBase64,
}) async {
  final nameController = TextEditingController(text: initialName);
  final heightController = TextEditingController(
    text: initialHealth.heightCm?.toStringAsFixed(0) ?? '',
  );
  final yearController = TextEditingController(
    text: initialHealth.birthYear?.toString() ?? '',
  );
  final picker = ImagePicker();
  Uint8List? avatarBytes;
  if (initialAvatarBase64 != null && initialAvatarBase64.isNotEmpty) {
    try {
      avatarBytes = base64Decode(initialAvatarBase64);
    } catch (_) {
      avatarBytes = null;
    }
  }
  var sex = initialHealth.sex;
  var units = initialHealth.unitSystem;

  final result = await showDialog<ProfileEditResult>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 46,
                backgroundImage:
                    avatarBytes == null ? null : MemoryImage(avatarBytes!),
                child: avatarBytes == null
                    ? const Icon(Icons.person_outline, size: 42)
                    : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 512,
                        maxHeight: 512,
                        imageQuality: 85,
                      );
                      if (picked == null) return;
                      final bytes = await picked.readAsBytes();
                      setDialogState(() => avatarBytes = bytes);
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      avatarBytes == null ? 'Choose photo' : 'Change photo',
                    ),
                  ),
                  if (avatarBytes != null)
                    TextButton.icon(
                      onPressed: () => setDialogState(() => avatarBytes = null),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                autofocus: initialName.isEmpty,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<HealthSex>(
                initialValue: sex,
                decoration: const InputDecoration(labelText: 'Sex'),
                items: HealthSex.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => sex = value ?? sex),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Birth year'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: heightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Height (cm)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<HealthUnitSystem>(
                initialValue: units,
                decoration: const InputDecoration(labelText: 'Display units'),
                items: const [
                  DropdownMenuItem(
                    value: HealthUnitSystem.metric,
                    child: Text('Metric (kg / cm)'),
                  ),
                  DropdownMenuItem(
                    value: HealthUnitSystem.imperial,
                    child: Text('Imperial (lb)'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => units = value ?? units),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final birthYear = int.tryParse(yearController.text.trim());
              final heightCm = double.tryParse(
                heightController.text.trim().replaceAll(',', '.'),
              );
              Navigator.pop(
                context,
                ProfileEditResult(
                  name: name,
                  avatarBase64:
                      avatarBytes == null ? null : base64Encode(avatarBytes!),
                  health: HealthProfile(
                    sex: sex,
                    birthYear: birthYear,
                    heightCm: heightCm,
                    unitSystem: units,
                  ),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  nameController.dispose();
  heightController.dispose();
  yearController.dispose();
  return result;
}
