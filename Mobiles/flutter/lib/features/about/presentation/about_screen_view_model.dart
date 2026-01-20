import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_version_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/app_localizations_provider.dart';
import '../../../core/o11y/events/o11y_events.dart';
import '../../../core/o11y/loggers/o11y_logger.dart';
import '../models/link_item.dart';

// =============================================================================
// UI State
// =============================================================================

class AboutScreenUiState extends Equatable {
  const AboutScreenUiState({
    required this.appVersion,
    required this.links,
    required this.features,
  });

  final String appVersion;
  final List<LinkItem> links;
  final List<String> features;

  @override
  List<Object?> get props => [appVersion, links, features];
}

// =============================================================================
// Actions Interface
// =============================================================================

abstract interface class AboutScreenActions {
  Future<void> launchLink(LinkItem link);
}

// =============================================================================
// ViewModel
// =============================================================================

class _AboutScreenViewModel extends Notifier<AboutScreenUiState>
    implements AboutScreenActions {
  // ---------------------------------------------------------------------------
  // Dependencies (initialized in build)
  // ---------------------------------------------------------------------------

  late O11yLogger _logger;
  late O11yEvents _events;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  AboutScreenUiState build() {
    _logger = ref.watch(o11yLoggerProvider);
    _events = ref.watch(o11yEventsProvider);

    final appVersion = ref.watch(appVersionProvider);
    final l10n = ref.watch(appLocalizationsProvider);

    _logger.debug('About screen ViewModel initialized');

    return AboutScreenUiState(
      appVersion: appVersion,
      links: _buildLinks(l10n),
      features: _buildFeatures(l10n),
    );
  }

  List<LinkItem> _buildLinks(AppLocalizations l10n) {
    return [
      LinkItem(
        id: 'github',
        icon: Icons.code,
        iconColor: Colors.black87,
        title: 'Faro Flutter SDK', // Product name - not localized
        subtitle: l10n.viewSourceCodeAndContribute,
        url: 'https://github.com/grafana/faro-flutter-sdk',
        eventName: 'github_link_clicked',
      ),
    ];
  }

  List<String> _buildFeatures(AppLocalizations l10n) {
    return [
      l10n.featureRum,
      l10n.featureErrorTracking,
      l10n.featureCustomEvents,
      l10n.featureDistributedTracing,
      l10n.featurePerformanceVitals,
    ];
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  @override
  Future<void> launchLink(LinkItem link) async {
    _logger.debug('Launching link: ${link.url}');
    _events.trackEvent(link.eventName, context: {'url': link.url});

    final uri = Uri.parse(link.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _logger.warning('Could not launch URL: ${link.url}');
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

final _aboutScreenViewModelProvider =
    NotifierProvider<_AboutScreenViewModel, AboutScreenUiState>(
      _AboutScreenViewModel.new,
    );

final aboutScreenUiStateProvider = Provider<AboutScreenUiState>((ref) {
  return ref.watch(_aboutScreenViewModelProvider);
});

final aboutScreenActionsProvider = Provider<AboutScreenActions>((ref) {
  return ref.read(_aboutScreenViewModelProvider.notifier);
});
