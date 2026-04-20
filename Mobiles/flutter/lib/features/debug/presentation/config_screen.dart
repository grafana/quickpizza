import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config_screen_view_model.dart';
import 'restart_required_banner.dart';

/// Sub-view of the Debug tab for changing the backend and Faro collector
/// URLs. Changes are persisted on "Save" and only take effect after an
/// app restart (see `RuntimeConfig`).
class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final _backendController = TextEditingController();
  final _faroController = TextEditingController();
  bool _controllersSeeded = false;

  @override
  void dispose() {
    _backendController.dispose();
    _faroController.dispose();
    super.dispose();
  }

  /// Seed the text controllers once from the saved overrides. We can't do
  /// this in initState because it needs access to the ViewModel state.
  void _seedControllersOnce(ConfigScreenUiState uiState) {
    if (_controllersSeeded) return;
    _backendController.text = uiState.savedBackendOverride ?? '';
    _faroController.text = uiState.savedFaroCollectorOverride ?? '';
    _controllersSeeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(configScreenUiStateProvider);
    final actions = ref.watch(configScreenActionsProvider);

    _seedControllersOnce(uiState);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Config'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const RestartRequiredBanner(),
          Text(
            'Override the URLs used by this app. Changes only take effect '
            'after you kill and restart the app — this keeps traces, logs '
            'and metrics correlated within a single session.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _UrlField(
            label: 'Backend URL',
            controller: _backendController,
            inUseValue: uiState.backendInUse,
            defaultValue: uiState.defaultBackend,
            hintText: 'http://192.168.1.100:3333',
          ),
          const SizedBox(height: 24),
          _UrlField(
            label: 'Faro collector URL',
            controller: _faroController,
            inUseValue: uiState.faroCollectorInUse,
            inUseDisplay: uiState.faroCollectorInUseDisplay,
            defaultValue: uiState.defaultFaroCollector,
            defaultDisplay: uiState.defaultFaroCollectorDisplay,
            hintText: 'https://faro-collector.../collect/<api-key>',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: uiState.saving
                  ? null
                  : () => actions.save(
                      backendUrl: _backendController.text,
                      faroCollectorUrl: _faroController.text,
                    ),
              icon: uiState.saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: uiState.saving
                  ? null
                  : () async {
                      await actions.clear();
                      _backendController.clear();
                      _faroController.clear();
                    },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Use defaults (clear overrides)'),
            ),
          ),
          if (uiState.statusMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        uiState.statusMessage!,
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _UrlField extends StatelessWidget {
  const _UrlField({
    required this.label,
    required this.controller,
    required this.inUseValue,
    required this.defaultValue,
    required this.hintText,
    this.inUseDisplay,
    this.defaultDisplay,
  });

  final String label;
  final TextEditingController controller;
  final String inUseValue;
  final String? defaultValue;
  final String hintText;
  final String? inUseDisplay;
  final String? defaultDisplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final monoStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Text('Currently in use', style: labelStyle),
            const SizedBox(height: 2),
            Text(inUseDisplay ?? inUseValue, style: monoStyle),
            if (defaultValue != null && defaultValue != inUseValue) ...[
              const SizedBox(height: 8),
              Text('Default', style: labelStyle),
              const SizedBox(height: 2),
              Text(defaultDisplay ?? defaultValue!, style: monoStyle),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                labelText: 'Override (empty = use default)',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ],
        ),
      ),
    );
  }
}
