import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_version_provider.dart';
import '../../../core/config/config_service.dart';
import '../../../core/localization/app_localizations_provider.dart';
import '../../../core/o11y/events/o11y_events.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/quick_pizza_app_bar.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(
    String url,
    String eventName,
    O11yEvents o11yEvents,
  ) async {
    o11yEvents.trackEvent(eventName, context: {'url': url});
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final appVersion = ref.watch(appVersionProvider);
    final configService = ref.watch(configServiceProvider);
    final o11yEvents = ref.watch(o11yEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: const QuickPizzaAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_pizza,
                      size: 64,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.aboutQuickPizza,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.aboutDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Links Section
              Text(
                l10n.links,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildLinkCard(
                icon: Icons.code,
                iconColor: Colors.black87,
                title: l10n.contributeOnGitHub,
                subtitle: l10n.viewSourceCodeAndContribute,
                onTap: () => _launchUrl(
                  'https://github.com/grafana/quickpizza',
                  'github_link_clicked',
                  o11yEvents,
                ),
              ),
              const SizedBox(height: 8),
              _buildLinkCard(
                icon: Icons.admin_panel_settings,
                iconColor: Colors.blue,
                title: l10n.adminDashboard,
                subtitle: l10n.managePizzasAndIngredients,
                onTap: () => _launchUrl(
                  '${configService.baseUrl}/admin',
                  'admin_link_clicked',
                  o11yEvents,
                ),
              ),
              const SizedBox(height: 8),
              _buildLinkCard(
                icon: Icons.analytics,
                iconColor: Colors.orange,
                title: l10n.grafanaObservability,
                subtitle: l10n.viewAppTelemetryAndDashboards,
                onTap: () => _launchUrl(
                  'https://grafana.com/products/cloud/',
                  'grafana_link_clicked',
                  o11yEvents,
                ),
              ),

              const SizedBox(height: 40),

              // About Section
              Text(
                l10n.aboutThisDemo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aboutDemoDescription,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.featuresDemo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FeatureItem(text: l10n.featureRum),
                    _FeatureItem(text: l10n.featureErrorTracking),
                    _FeatureItem(text: l10n.featureCustomEvents),
                    _FeatureItem(text: l10n.featureDistributedTracing),
                    _FeatureItem(text: l10n.featurePerformanceVitals),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Footer
              Center(
                child: Column(
                  children: [
                    Text(
                      l10n.madeWithLove,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics,
                          size: 16,
                          color: Colors.orange.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.poweredByGrafanaFaro,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.versionLabel} $appVersion',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String text;

  const _FeatureItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
