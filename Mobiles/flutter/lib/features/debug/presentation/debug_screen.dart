import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/debug_settings.dart';
import '../../../core/o11y/errors/o11y_errors.dart';
import '../../../core/o11y/events/o11y_events.dart';
import '../../../core/o11y/loggers/o11y_logger.dart';
import '../../../core/router/app_router.dart';
import '../domain/native_crash_service.dart';
import 'restart_required_banner.dart';

class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  String? _lastActionMessage;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(debugSettingsProvider);
    final notifier = ref.read(debugSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug'),
        actions: [
          if (settings.hasActiveOverrides)
            TextButton(
              onPressed: () {
                notifier.resetAll();
                _showAction('All debug settings reset');
              },
              child: const Text('Reset All'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const RestartRequiredBanner(),

          // Config entrypoint
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Config'),
              subtitle: const Text(
                'Change backend and Faro collector URLs (requires restart)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.debugConfig),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Use these tools to simulate issues and exercise the '
            'observability instrumentation during demos.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Error Simulation
          _SectionHeader(title: 'Error Simulation'),
          const SizedBox(height: 8),
          Text(
            'Toggle these to simulate backend issues, client-side faults, '
            'and version drift. Takes effect immediately — no restart needed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Slow Recommendations'),
                  subtitle: const Text('Adds delay to pizza recommendations'),
                  value: settings.slowRecommendations,
                  onChanged: notifier.setSlowRecommendations,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Slow Ingredients'),
                  subtitle: const Text('Adds delay to ingredient loading'),
                  value: settings.slowIngredients,
                  onChanged: notifier.setSlowIngredients,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Error on Recommendations'),
                  subtitle: const Text(
                    'Forces server errors on recommendations',
                  ),
                  value: settings.errorOnRecommendations,
                  onChanged: notifier.setErrorOnRecommendations,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Error on Ingredients'),
                  subtitle: const Text(
                    'Forces server errors on ingredient loading',
                  ),
                  value: settings.errorOnIngredients,
                  onChanged: notifier.setErrorOnIngredients,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Use v2 pizza response schema'),
                  subtitle: const Text(
                    'Experimental — simulates a client/backend schema drift',
                  ),
                  value: settings.useV2PizzaSchema,
                  onChanged: notifier.setUseV2PizzaSchema,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Skip auth dep in tools provider'),
                  subtitle: const Text(
                    "Tools list won't refresh on login/logout — no error is thrown",
                  ),
                  value: settings.skipAuthDepInTools,
                  onChanged: notifier.setSkipAuthDepInTools,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Client Diagnostics
          _SectionHeader(title: 'Client Diagnostics'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Signals',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Emit one-off Faro signals (logs and custom events) to '
                    'verify the SDK pipeline end-to-end.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _sendTestDebugLog,
                      icon: const Icon(Icons.notes),
                      label: const Text('Send Debug Log'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _sendTestErrorLog,
                      icon: const Icon(Icons.error_outline),
                      label: const Text('Send Error Log'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _sendTestEvent,
                      icon: const Icon(Icons.event_note),
                      label: const Text('Send Custom Event'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Handled Exception',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Throws an exception inside a try/catch and reports it '
                    'via the Faro error API. Tests the manual reporting path.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sendTestException,
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Send Handled Exception'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unhandled Exception',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Throws a Dart exception outside any try/catch. Faro\'s '
                    'global error handler (installed by faro.runApp) captures '
                    'it and reports it. The app keeps running.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _throwUnhandledException,
                      icon: const Icon(Icons.bolt),
                      label: const Text('Throw Unhandled Exception'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Native Crash',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Triggers a real native crash via a MethodChannel. The '
                    'OS terminates the app — the crash is persisted by the '
                    'native crash reporter and delivered by Faro on the next '
                    'app launch.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _confirmNativeCrash(
                        title: 'Trigger native crash?',
                        body:
                            'The app will terminate. Relaunch it to see the '
                            'crash report in Frontend Observability.',
                        action: () => ref
                            .read(nativeCrashServiceProvider)
                            .crashWithMessage(
                              'Deliberate crash from QuickPizza debug tab',
                            ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      icon: const Icon(Icons.dangerous),
                      label: const Text('Crash (custom message)'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _confirmNativeCrash(
                        title: 'Trigger simulated NPE?',
                        body:
                            'Simulates a real-world null-dereference bug. '
                            'The app will terminate. Relaunch it to see the '
                            'crash report in Frontend Observability.',
                        action: () => ref
                            .read(nativeCrashServiceProvider)
                            .crashWithNullPointer(),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      icon: const Icon(Icons.broken_image),
                      label: const Text('Crash (simulated NPE)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status message
          if (_lastActionMessage != null)
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
                        _lastActionMessage!,
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showAction(String message) {
    setState(() => _lastActionMessage = message);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _lastActionMessage = null);
    });
  }

  static const _debugTabContext = <String, String>{'debug.source': 'debug_tab'};

  void _sendTestDebugLog() {
    ref
        .read(o11yLoggerProvider)
        .debug(
          'Test debug log from Debug tab',
          context: {..._debugTabContext, 'debug.action': 'logger.debug'},
        );
    _showAction('Sent debug log');
  }

  void _sendTestErrorLog() {
    ref
        .read(o11yLoggerProvider)
        .error(
          'Test error log from Debug tab',
          context: {..._debugTabContext, 'debug.action': 'logger.error'},
        );
    _showAction('Sent error log');
  }

  void _sendTestEvent() {
    ref
        .read(o11yEventsProvider)
        .trackEvent(
          'debug.test_event',
          context: {..._debugTabContext, 'debug.action': 'events.trackEvent'},
        );
    _showAction('Sent custom event');
  }

  void _sendTestException() {
    try {
      throw Exception('Test exception from Debug tab');
    } catch (e, stackTrace) {
      ref
          .read(o11yErrorsProvider)
          .reportError(
            type: 'DebugTestError',
            error: e.toString(),
            stacktrace: stackTrace,
            context: {
              ..._debugTabContext,
              'debug.action': 'errors.reportError',
            },
          );
    }
    _showAction('Sent handled exception');
  }

  /// Throws synchronously inside a setState callback so it escapes the
  /// try/catch inside the framework's button-tap zone and bubbles up to
  /// Faro's global error handler (installed by `faro.runApp`).
  void _throwUnhandledException() {
    _showAction('Threw unhandled exception');
    throw StateError('Deliberate unhandled exception from Debug tab');
  }

  void _confirmNativeCrash({
    required String title,
    required String body,
    required Future<void> Function() action,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              action();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Crash now'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
