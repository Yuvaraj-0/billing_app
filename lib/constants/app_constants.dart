class AppConstants {
  // App Info
  static const String appName = 'MK Star';
  static const String defaultShopName = 'MK Star';
  static const String tagline = 'Photography Services';
  static const String billNumberPrefix = 'MK-';
  static const String currencySymbol = '₹';

  // Hive Box Names
  static const String billsBoxName = 'bills';
  static const String settingsBoxName = 'settings';
  static const String packagesBoxName = 'packages_box';
  static const String settingsKey = 'app_settings';

  // GST Rates
  static const double gstPercentage = 18.0;
  static const double cgstPercentage = 9.0;
  static const double sgstPercentage = 9.0;

  // Service Types
  static const List<String> serviceTypes = [
    'Photography Service',
    'Videography Service',
    'Both (Photo + Video)',
    'Editing Service',
    'Album Design Service',
  ];

  // Routes
  static const String routeDashboard = '/dashboard';
  static const String routeGenerateBill = '/generate-bill';
  static const String routeHistory = '/history';
  static const String routeBillDetails = '/bill-details';
  static const String routeSettings = '/settings';
}
