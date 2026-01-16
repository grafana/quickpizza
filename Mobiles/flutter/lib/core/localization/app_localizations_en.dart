// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'QuickPizza';

  @override
  String get navHome => 'Home';

  @override
  String get navAbout => 'About';

  @override
  String get heroTitle => 'Looking to break out of\nyour pizza routine?';

  @override
  String get heroSubtitle => 'QuickPizza has your back!';

  @override
  String get heroDescription =>
      'With just one click, you\'ll discover new and exciting pizza combinations.';

  @override
  String get pizzaPleaseButton => 'Pizza, Please!';

  @override
  String get customizeYourPizza => 'Customize Your Pizza';

  @override
  String get maxCalories => 'Max Calories';

  @override
  String get minToppings => 'Min Toppings';

  @override
  String get maxToppings => 'Max Toppings';

  @override
  String get vegetarianOnly => 'Vegetarian only';

  @override
  String get excludeTools => 'Exclude tools:';

  @override
  String get customPizzaName => 'Custom Pizza Name (optional)';

  @override
  String get ourRecommendation => 'Our Recommendation';

  @override
  String get dough => 'Dough';

  @override
  String get tool => 'Tool';

  @override
  String get calories => 'Calories';

  @override
  String caloriesPerSlice(String calories) {
    return '$calories per slice';
  }

  @override
  String get vegetarian => 'Vegetarian';

  @override
  String get ingredients => 'Ingredients';

  @override
  String get pass => 'Pass';

  @override
  String get loveIt => 'Love it!';

  @override
  String get rated => 'Rated!';

  @override
  String get savedToFavorites => 'Saved to favorites!';

  @override
  String get gotItNextTime => 'Got it, next time!';

  @override
  String get pleaseLoginFirst => 'Please log in first.';

  @override
  String get notAvailable => 'N/A';

  @override
  String get aboutQuickPizza => 'About QuickPizza';

  @override
  String get aboutDescription =>
      'Discover new and exciting pizza\ncombinations with just one click!';

  @override
  String get links => 'Links';

  @override
  String get contributeOnGitHub => 'Contribute on GitHub';

  @override
  String get viewSourceCodeAndContribute => 'View source code and contribute';

  @override
  String get adminDashboard => 'Admin Dashboard';

  @override
  String get managePizzasAndIngredients => 'Manage pizzas and ingredients';

  @override
  String get grafanaObservability => 'Grafana Observability';

  @override
  String get viewAppTelemetryAndDashboards =>
      'View app telemetry and dashboards';

  @override
  String get aboutThisDemo => 'About This Demo';

  @override
  String get aboutDemoDescription =>
      'QuickPizza is a demo application showcasing Grafana\'s mobile observability capabilities using Faro.';

  @override
  String get featuresDemo => 'Features demonstrated:';

  @override
  String get featureRum => 'Real User Monitoring (RUM)';

  @override
  String get featureErrorTracking => 'Error tracking & crash reporting';

  @override
  String get featureCustomEvents => 'Custom events & metrics';

  @override
  String get featureDistributedTracing => 'Distributed tracing';

  @override
  String get featurePerformanceVitals => 'Performance vitals';

  @override
  String get madeWithLove => 'Made with love by QuickPizza Labs';

  @override
  String get poweredByGrafanaFaro => 'Powered by Grafana Faro';

  @override
  String get versionLabel => 'Version';

  @override
  String get login => 'Login';

  @override
  String get welcomeToQuickPizza => 'Welcome to QuickPizza';

  @override
  String get signInToSaveFavorites => 'Sign in to save your favorite pizzas';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign In';

  @override
  String get loginHint => 'Hint: Use \"default\" / \"12345678\" to login';

  @override
  String get loginTip =>
      'Tip: You can create a new user via the POST http://quickpizza.grafana.com/api/users endpoint. Attach a JSON payload with username and password keys.';

  @override
  String get profile => 'Profile';

  @override
  String get pizzaLover => 'Pizza Lover';

  @override
  String pizzasRated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pizzas rated',
      one: '$count pizza rated',
    );
    return '$_temp0';
  }

  @override
  String get loading => 'Loading...';

  @override
  String get yourRatings => 'Your Ratings';

  @override
  String get noRatingsYet => 'No ratings yet';

  @override
  String get rateSomePizzas => 'Rate some pizzas to see them here!';

  @override
  String pizzaNumber(int pizzaId) {
    return 'Pizza #$pizzaId';
  }

  @override
  String get lovedIt => 'Loved it!';

  @override
  String get passed => 'Passed';

  @override
  String get clearRatings => 'Clear Ratings';

  @override
  String get signOut => 'Sign Out';

  @override
  String get ratingsClearedSuccessfully => 'Ratings cleared successfully!';
}
