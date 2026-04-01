import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'QuickPizza'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Looking to break out of\nyour pizza routine?'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'QuickPizza has your back!'**
  String get heroSubtitle;

  /// No description provided for @heroDescription.
  ///
  /// In en, this message translates to:
  /// **'With just one click, you\'ll discover new and exciting pizza combinations.'**
  String get heroDescription;

  /// No description provided for @pizzaPleaseButton.
  ///
  /// In en, this message translates to:
  /// **'Pizza, Please!'**
  String get pizzaPleaseButton;

  /// No description provided for @customizeYourPizza.
  ///
  /// In en, this message translates to:
  /// **'Customize Your Pizza'**
  String get customizeYourPizza;

  /// No description provided for @maxCalories.
  ///
  /// In en, this message translates to:
  /// **'Max Calories'**
  String get maxCalories;

  /// No description provided for @minToppings.
  ///
  /// In en, this message translates to:
  /// **'Min Toppings'**
  String get minToppings;

  /// No description provided for @maxToppings.
  ///
  /// In en, this message translates to:
  /// **'Max Toppings'**
  String get maxToppings;

  /// No description provided for @vegetarianOnly.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian only'**
  String get vegetarianOnly;

  /// No description provided for @excludeTools.
  ///
  /// In en, this message translates to:
  /// **'Exclude tools:'**
  String get excludeTools;

  /// No description provided for @customPizzaName.
  ///
  /// In en, this message translates to:
  /// **'Custom Pizza Name (optional)'**
  String get customPizzaName;

  /// No description provided for @ourRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Our Recommendation'**
  String get ourRecommendation;

  /// No description provided for @dough.
  ///
  /// In en, this message translates to:
  /// **'Dough'**
  String get dough;

  /// No description provided for @tool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get tool;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @caloriesPerSlice.
  ///
  /// In en, this message translates to:
  /// **'{calories} per slice'**
  String caloriesPerSlice(String calories);

  /// No description provided for @vegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get vegetarian;

  /// No description provided for @ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// No description provided for @pass.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get pass;

  /// No description provided for @loveIt.
  ///
  /// In en, this message translates to:
  /// **'Love it!'**
  String get loveIt;

  /// No description provided for @thanksFeedback.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback!'**
  String get thanksFeedback;

  /// No description provided for @gotItNextTime.
  ///
  /// In en, this message translates to:
  /// **'Got it, next time!'**
  String get gotItNextTime;

  /// No description provided for @pleaseLoginFirst.
  ///
  /// In en, this message translates to:
  /// **'Please log in first.'**
  String get pleaseLoginFirst;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @aboutQuickPizza.
  ///
  /// In en, this message translates to:
  /// **'About QuickPizza'**
  String get aboutQuickPizza;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Discover new and exciting pizza\ncombinations with just one click!'**
  String get aboutDescription;

  /// No description provided for @links.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// No description provided for @contributeOnGitHub.
  ///
  /// In en, this message translates to:
  /// **'Contribute on GitHub'**
  String get contributeOnGitHub;

  /// No description provided for @viewSourceCodeAndContribute.
  ///
  /// In en, this message translates to:
  /// **'View source code and contribute'**
  String get viewSourceCodeAndContribute;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @managePizzasAndIngredients.
  ///
  /// In en, this message translates to:
  /// **'Manage pizzas and ingredients'**
  String get managePizzasAndIngredients;

  /// No description provided for @grafanaObservability.
  ///
  /// In en, this message translates to:
  /// **'Grafana Observability'**
  String get grafanaObservability;

  /// No description provided for @viewAppTelemetryAndDashboards.
  ///
  /// In en, this message translates to:
  /// **'View app telemetry and dashboards'**
  String get viewAppTelemetryAndDashboards;

  /// No description provided for @aboutThisDemo.
  ///
  /// In en, this message translates to:
  /// **'About This Demo'**
  String get aboutThisDemo;

  /// No description provided for @aboutDemoDescription.
  ///
  /// In en, this message translates to:
  /// **'QuickPizza is a demo application showcasing Grafana\'s mobile observability capabilities using Faro.'**
  String get aboutDemoDescription;

  /// No description provided for @featuresDemo.
  ///
  /// In en, this message translates to:
  /// **'Features demonstrated:'**
  String get featuresDemo;

  /// No description provided for @featureRum.
  ///
  /// In en, this message translates to:
  /// **'Real User Monitoring (RUM)'**
  String get featureRum;

  /// No description provided for @featureErrorTracking.
  ///
  /// In en, this message translates to:
  /// **'Error tracking & crash reporting'**
  String get featureErrorTracking;

  /// No description provided for @featureCustomEvents.
  ///
  /// In en, this message translates to:
  /// **'Custom events & metrics'**
  String get featureCustomEvents;

  /// No description provided for @featureDistributedTracing.
  ///
  /// In en, this message translates to:
  /// **'Distributed tracing'**
  String get featureDistributedTracing;

  /// No description provided for @featurePerformanceVitals.
  ///
  /// In en, this message translates to:
  /// **'Performance vitals'**
  String get featurePerformanceVitals;

  /// No description provided for @madeWithLove.
  ///
  /// In en, this message translates to:
  /// **'Made with love by QuickPizza Labs'**
  String get madeWithLove;

  /// No description provided for @poweredByGrafanaFaro.
  ///
  /// In en, this message translates to:
  /// **'Powered by Grafana Faro'**
  String get poweredByGrafanaFaro;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionLabel;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @welcomeToQuickPizza.
  ///
  /// In en, this message translates to:
  /// **'Welcome to QuickPizza'**
  String get welcomeToQuickPizza;

  /// No description provided for @signInToSaveFavorites.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save your favorite pizzas'**
  String get signInToSaveFavorites;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @loginHint.
  ///
  /// In en, this message translates to:
  /// **'Hint: Use \"default\" / \"12345678\" to login'**
  String get loginHint;

  /// No description provided for @loginTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: You can create a new user via the POST http://quickpizza.grafana.com/api/users endpoint. Attach a JSON payload with username and password keys.'**
  String get loginTip;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @pizzaLover.
  ///
  /// In en, this message translates to:
  /// **'Pizza Lover'**
  String get pizzaLover;

  /// No description provided for @pizzasRated.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{{count} pizza rated} other{{count} pizzas rated}}'**
  String pizzasRated(int count);

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @yourRatings.
  ///
  /// In en, this message translates to:
  /// **'Your Ratings'**
  String get yourRatings;

  /// No description provided for @noRatingsYet.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet'**
  String get noRatingsYet;

  /// No description provided for @rateSomePizzas.
  ///
  /// In en, this message translates to:
  /// **'Rate some pizzas to see them here!'**
  String get rateSomePizzas;

  /// No description provided for @pizzaNumber.
  ///
  /// In en, this message translates to:
  /// **'Pizza #{pizzaId}'**
  String pizzaNumber(int pizzaId);

  /// No description provided for @lovedIt.
  ///
  /// In en, this message translates to:
  /// **'Love it!'**
  String get lovedIt;

  /// No description provided for @passed.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get passed;

  /// No description provided for @clearRatings.
  ///
  /// In en, this message translates to:
  /// **'Clear Ratings'**
  String get clearRatings;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @ratingsClearedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Ratings cleared successfully!'**
  String get ratingsClearedSuccessfully;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
