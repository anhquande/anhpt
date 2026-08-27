import 'package:flutter/material.dart';

import '../app/app_controller.dart';

class BucketSourcesScreen extends StatelessWidget {
  final AppController controller;

  const BucketSourcesScreen({super.key, required this.controller});

  Future<void> _addSource(BuildContext context) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add workout source'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Catalog URL',
                    hintText: 'https://example.com/bucket.json',
                  ),
                  validator: (value) {
                    final uri = Uri.tryParse(value?.trim() ?? '');
                    if (uri == null ||
                        uri.scheme != 'https' ||
                        !uri.hasAuthority) {
                      return 'Enter a public HTTPS URL.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final name = nameController.text.trim();
    final url = urlController.text.trim();
    nameController.dispose();
    urlController.dispose();
    if (submitted != true || !context.mounted) return;
    try {
      await controller.addBucketSource(name, url);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add source: $error')),
        );
      }
    }
  }

  Future<void> _removeSource(
      BuildContext context, String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove source?'),
        content: Text(
          'Remove $name from your sources? Workouts already installed remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.removeBucketSource(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout sources'),
        actions: [
          IconButton(
            tooltip: 'Refresh all enabled sources',
            onPressed: controller.bucketCatalogLoading
                ? null
                : controller.refreshAllBucketSources,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSource(context),
        icon: const Icon(Icons.add),
        label: const Text('Add source'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Text(
                  'Public HTTPS catalogs. Cached results stay available when a source is offline.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (controller.bucketCatalogLoading)
                  const LinearProgressIndicator(),
                if (controller.bucketSources.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No bucket sources yet. Add a catalog URL to discover workouts.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                for (final source in controller.bucketSources)
                  Card(
                    child: ListTile(
                      leading: Switch(
                        value: source.enabled,
                        onChanged: (value) => controller.setBucketSourceEnabled(
                          source.id,
                          value,
                        ),
                      ),
                      title: Text(source.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(source.catalogUrl),
                          if (source.lastError != null)
                            Text(
                              'Using last saved catalog · ${source.lastError}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            )
                          else if (source.lastRefreshedAt != null)
                            Text('Updated ${source.lastRefreshedAt}'),
                        ],
                      ),
                      isThreeLine: source.lastError != null ||
                          source.lastRefreshedAt != null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'refresh') {
                            controller.refreshBucketSource(source.id);
                          } else if (value == 'remove') {
                            _removeSource(context, source.id, source.name);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'refresh',
                            child: Text('Refresh'),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
