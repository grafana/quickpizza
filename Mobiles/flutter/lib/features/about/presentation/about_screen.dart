import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/app_localizations_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/quick_pizza_app_bar.dart';
import 'about_screen_view_model.dart';
import 'widgets/feature_item.dart';
import 'widgets/link_card.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final uiState = ref.watch(aboutScreenUiStateProvider);
    final actions = ref.watch(aboutScreenActionsProvider);

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
              _Header(l10n: l10n),
              const SizedBox(height: 40),

              // Links Section
              _LinksSection(l10n: l10n, uiState: uiState, actions: actions),
              const SizedBox(height: 40),

              // About Section
              _AboutSection(l10n: l10n, uiState: uiState),
              const SizedBox(height: 40),

              // Footer
              _Footer(l10n: l10n, appVersion: uiState.appVersion),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Private Widgets
// =============================================================================

class _Header extends StatelessWidget {
  const _Header({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.local_pizza, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            l10n.aboutQuickPizza,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.aboutDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _LinksSection extends StatelessWidget {
  const _LinksSection({
    required this.l10n,
    required this.uiState,
    required this.actions,
  });

  final AppLocalizations l10n;
  final AboutScreenUiState uiState;
  final AboutScreenActions actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.links,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...uiState.links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LinkCard(
              icon: link.icon,
              iconColor: link.iconColor,
              title: link.title,
              subtitle: link.subtitle,
              onTap: () => actions.launchLink(link),
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.l10n, required this.uiState});

  final AppLocalizations l10n;
  final AboutScreenUiState uiState;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              ...uiState.features.map(
                (feature) => FeatureItem(text: feature),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.l10n, required this.appVersion});

  final AppLocalizations l10n;
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              Icon(Icons.analytics, size: 16, color: Colors.orange.shade400),
              const SizedBox(width: 4),
              Text(
                l10n.poweredByGrafanaFaro,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.versionLabel} $appVersion',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
