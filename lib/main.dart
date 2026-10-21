import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/services/mongo_service.dart';
import 'models/invoice/bill.dart';
import 'models/invoice/bill_item.dart';
import 'models/app_settings.dart';
import 'core/constants/app_constants.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/bill_form_viewmodel.dart';
import 'viewmodels/history_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';
import 'views/auth/auth_page.dart';
import 'views/home/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env configuration
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('[Main] Could not load .env file from assets: $e');
  }

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(BillItemAdapter());
  Hive.registerAdapter(BillAdapter());
  Hive.registerAdapter(AppSettingsAdapter());

  // Open boxes
  await Hive.openBox<Bill>(AppConstants.billsBoxName);
  await Hive.openBox<AppSettings>(AppConstants.settingsBoxName);
  await Hive.openBox(AuthViewModel.authBoxName);
  await Hive.openBox(AppConstants.packagesBoxName);

  // Initialize MongoDB Atlas connection asynchronously in background
  MongoService.instance.init();

  runApp(const MKStudioApp());
}

class MKStudioApp extends StatelessWidget {
  const MKStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthViewModel()..checkAuthStatus(),
        ),
        ChangeNotifierProvider(create: (_) => BillFormViewModel()),
        ChangeNotifierProvider(create: (_) => HistoryViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
      ],
      child: MaterialApp(
        title: 'MK Star',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Consumer<AuthViewModel>(
          builder: (context, auth, _) {
            if (auth.isLoading) {
              return Scaffold(
                backgroundColor: AppTheme.primaryDark,
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.gold,
                  ),
                ),
              );
            }

            if (!auth.isAuthenticated) {
              return const AuthPage();
            }

            // User is authenticated — initialize user-scoped viewmodels
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final userId = auth.currentUser?.id;
              final historyVm = context.read<HistoryViewModel>();
              if (historyVm.currentUserId != userId) {
                historyVm.loadBills(userId: userId);
              }
              final settingsVm = context.read<SettingsViewModel>();
              if (settingsVm.currentUserId != userId) {
                settingsVm.init(
                  userId: userId,
                  initialShopName: auth.currentUser?.shopName,
                );
              }

              // Sync bills in background if connected
              final billsBox = Hive.box<Bill>(AppConstants.billsBoxName);
              if (userId != null && userId.isNotEmpty) {
                MongoService.instance.init().then((connected) {
                  if (connected) {
                    MongoService.instance
                        .syncAllBills(billsBox, userId: userId);
                  }
                });
              }
            });

            return const MainShell();
          },
        ),
      ),
    );
  }
}
