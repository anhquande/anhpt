import 'package:flutter/material.dart';

import '../models/health.dart';

class ProfileEditResult {
  final String name;
  final HealthProfile health;

  const ProfileEditResult({required this.name, required this.health});
}

Future<ProfileEditResult?> showProfileEditorDialog(
  BuildContext context, {
  required String title,
  required String initialName,
  required HealthProfile initialHealth,
}) async {
  final nameController = TextEditingController(text: initialName);
  final heightController = TextEditingController(
    text: initialHealth.heightCm?.toStringAsFixed(0) ?? '',
  );
  final yearController = TextEditingController(
    text: initialHealth.birthYear?.toString() ?? '',
  );
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
              TextField(
                controller: nameController,
                autofocus: true,
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
