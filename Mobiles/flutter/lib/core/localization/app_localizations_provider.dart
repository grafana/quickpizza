// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_localizations.dart';

/// Provider used to access the AppLocalizations object for the current locale
final appLocalizationsProvider =
    NotifierProvider<AppLocalizationsNotifier, AppLocalizations>(
  AppLocalizationsNotifier.new,
);

class AppLocalizationsNotifier extends Notifier<AppLocalizations> {
  _LocaleObserver? _observer;

  @override
  AppLocalizations build() {
    // Initialize with the current locale
    final initialLocale = _tryLookupAppLocalizations(
      WidgetsBinding.instance.platformDispatcher.locale,
    );

    // Create an observer to update the state when locale changes
    _observer = _LocaleObserver(() {
      state = _tryLookupAppLocalizations(
        WidgetsBinding.instance.platformDispatcher.locale,
      );
    });

    // Register the observer and dispose it when no longer needed
    final binding = WidgetsBinding.instance;
    binding.addObserver(_observer!);
    ref.onDispose(() {
      binding.removeObserver(_observer!);
    });

    return initialLocale;
  }
}

/// An observer used to notify the caller when the locale changes
class _LocaleObserver extends WidgetsBindingObserver {
  _LocaleObserver(this._didChangeLocales);

  final VoidCallback _didChangeLocales;

  @override
  void didChangeLocales(List<Locale>? locales) {
    _didChangeLocales();
  }
}

AppLocalizations _tryLookupAppLocalizations(Locale locale) {
  try {
    return lookupAppLocalizations(locale);
  } catch (e) {
    return lookupAppLocalizations(const Locale('en'));
  }
}
