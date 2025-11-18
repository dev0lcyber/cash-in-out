import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

// --- MODIFIED --- (Removed fl_chart, added syncfusion_flutter_charts)
// import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl_fmt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------
// NEW IMPORTS FOR NOTIFICATIONS
// ---------------------------------------------------------------------
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

// ---------------------------------------------------------------------
// NOTIFICATION SERVICE IMPLEMENTATION
// ---------------------------------------------------------------------

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // --- MODIFIED --- (Unique IDs for 5 daily notifications)
  static const int morningNotificationId = 1001;
  static const int middayNotificationId = 1002;
  static const int afternoonNotificationId = 1003;
  static const int eveningNotificationId = 1004;
  static const int nightNotificationId = 1005;

  static const String channelId = 'daily_motivation_channel';
  static const String channelName = 'cashinout Motivation';
  static const String channelDescription =
      'Daily reminders to log income and expenses.';

  Future<void> initNotifications() async {
    // 1. Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. Combine settings (only Android is needed for your current target)
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // onDidReceiveNotificationResponse is required, even if empty
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Here you can handle the tap, e.g., navigating to the Home Screen
      },
    );
  }

  // Helper to request notification permission (required for Android 13+)
  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    // Request notification permission (required for Android 13+)
    await androidImplementation?.requestNotificationsPermission();
    // Request exact alarm permission for scheduled notifications
    await androidImplementation?.requestExactAlarmsPermission();
  }

  // Helper to determine the next time for scheduling
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // --- MODIFIED --- (Complete rewrite to load data and schedule 5 notifs)
  Future<void> scheduleDailyNotifications(AppLocalizations loc) async {
    await flutterLocalNotificationsPlugin.cancelAll(); // Cancel old schedules
    await requestPermissions(); // Request permission before scheduling

    // --- NEW --- Load data for personalized notifications
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? 'User';
    final balance = prefs.getDouble('balance') ?? 0;
    final currency = prefs.getString('currency') ?? '';
    final json = prefs.getString('transactions') ?? '[]';
    final transactions =
        (jsonDecode(json) as List)
            .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
            .toList();

    // Calculate today's stats
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final todaysTransactions = transactions.where(
      (t) => t.date.isAfter(startOfDay) && t.date.isBefore(endOfDay),
    );

    final double todayIncome = todaysTransactions
        .where((t) => t.amount > 0)
        .fold(0, (a, b) => a + b.amount);

    final double todayExpense = todaysTransactions
        .where((t) => t.amount < 0)
        .fold(0, (a, b) => a + b.amount.abs());

    // Format for display
    final String fBalance = formatCurrencyCompact(balance, currency);
    final String fIncome = formatCurrencyCompact(todayIncome, currency);
    final String fExpense = formatCurrencyCompact(todayExpense, currency);

    // Get random messages
    final random = math.Random();

    // 1. Morning Notifications (Generic)
    final morningNotifs = [
      {
        'title': loc.notifMorningTitle1(username),
        'body': loc.notifMorningBody1,
      },
      {
        'title': loc.notifMorningTitle2(username),
        'body': loc.notifMorningBody2,
      },
    ];

    // 2. Midday Notifications (Generic)
    final middayNotifs = [
      {'title': loc.notifMiddayTitle1(username), 'body': loc.notifMiddayBody1},
      {'title': loc.notifMiddayTitle2(username), 'body': loc.notifMiddayBody2},
    ];

    // 3. Afternoon Notifications (Generic)
    final afternoonNotifs = [
      {
        'title': loc.notifAfternoonTitle1(username),
        'body': loc.notifAfternoonBody1,
      },
      {
        'title': loc.notifAfternoonTitle2(username),
        'body': loc.notifAfternoonBody2,
      },
    ];

    // 4. Evening Notifications (Data-driven)
    final String eveningTitle = loc.notifEveningTitle(username);
    final String eveningBody =
        (todayIncome == 0 && todayExpense == 0)
            ? loc.notifEveningBodyNoActivity(fBalance)
            : loc.notifEveningBodySummary(fIncome, fExpense, fBalance);

    // 5. Night Notifications (Data-driven)
    final String nightTitle = loc.notifNightTitle(username);
    final String nightBody =
        (todayIncome == 0 && todayExpense == 0)
            ? loc.notifNightBodyNoActivity
            : loc.notifNightBodySummary(fIncome, fExpense);

    final morningChoice = morningNotifs[random.nextInt(morningNotifs.length)];
    final middayChoice = middayNotifs[random.nextInt(middayNotifs.length)];
    final afternoonChoice =
        afternoonNotifs[random.nextInt(afternoonNotifs.length)];

    // Android-specific channel details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            '',
          ), // Allow multi-line text
        );

    const NotificationDetails platformChannelDetails = NotificationDetails(
      android: androidDetails,
    );

    // Schedule 1. Morning (~9:00 AM)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      morningNotificationId,
      morningChoice['title'],
      morningChoice['body'],
      _nextInstanceOfTime(9, 0), // 9:00 AM
      platformChannelDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule 2. Midday (~1:00 PM)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      middayNotificationId,
      middayChoice['title'],
      middayChoice['body'],
      _nextInstanceOfTime(13, 0), // 1:00 PM
      platformChannelDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule 3. Afternoon (~5:00 PM)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      afternoonNotificationId,
      afternoonChoice['title'],
      afternoonChoice['body'],
      _nextInstanceOfTime(17, 0), // 5:00 PM
      platformChannelDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule 4. Evening (~8:00 PM)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      eveningNotificationId,
      eveningTitle,
      eveningBody,
      _nextInstanceOfTime(20, 0), // 8:00 PM
      platformChannelDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule 5. Night (~10:00 PM)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      nightNotificationId,
      nightTitle,
      nightBody,
      _nextInstanceOfTime(22, 0), // 10:00 PM
      platformChannelDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint("Scheduled 5 daily notifications in ${loc.locale.languageCode}");
  }
}

// ---------------------------------------------------------------------
// MAIN FUNCTION UPDATE
// ---------------------------------------------------------------------

Future<void> main() async {
  // Must be called before any plugin is used
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data
  tz.initializeTimeZones();

  runApp(const MainApp());
}

/* --------------------------------------------------------------------- */
/* COLOR SCHEME                            */
// ... (AppColors remains unchanged)
/* --------------------------------------------------------------------- */
class AppColors {
  static const Color primary = Color(0xFF4CB8A9); // Soft Modern Teal
  static const Color accent = Color(0xFFFF6B35); // Vibrant Orange (good)
  static const Color lightBg = Color(0xFFF5F7FA);
  static const Color darkBg = Color(0xFF0D1B2A);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1B263B);
  static const Color positive = Color(0xFF4CAF50);
  static const Color negative = Color(0xFFF44336);
}

// ---------------------------------------------------------------------
// NEW CATEGORY DEFINITIONS
// ---------------------------------------------------------------------
class AppCategories {
  // Define category keys and their corresponding icons
  static const Map<String, IconData> categories = {
    'salary': Icons.work_outline,
    'gifts': Icons.card_giftcard,
    'food': Icons.fastfood_outlined,
    'transport': Icons.directions_bus_outlined,
    'entertainment': Icons.movie_creation_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'health': Icons.local_hospital_outlined,
    'bills': Icons.receipt_long_outlined,
    'other': Icons.category_outlined,
  };

  // --- NEW ---
  // Define category keys and their corresponding colors for charts
  static const Map<String, Color> categoryColors = {
    'salary': Color(0xFF4CAF50), // positive
    'gifts': Color(0xFF009688), // teal
    'food': Color(0xFFFF9800), // orange
    'transport': Color(0xFF2196F3), // blue
    'entertainment': Color(0xFF9C27B0), // purple
    'shopping': Color(0xFFE91E63), // pink
    'health': Color(0xFFF44336), // negative
    'bills': Color(0xFF3F51B5), // indigo
    'other': Color(0xFF9E9E9E), // grey
  };

  // Helper to get an icon for a category key, defaulting to 'other'
  static IconData getIcon(String? categoryKey) {
    return categories[categoryKey] ?? categories['other']!;
  }

  // --- NEW ---
  // Helper to get a color for a category key, defaulting to 'other'
  static Color getColor(String? categoryKey) {
    return categoryColors[categoryKey] ?? categoryColors['other']!;
  }

  // Helper to get all category keys
  static List<String> get keys => categories.keys.toList();
}

/* --------------------------------------------------------------------- */
/* LANGUAGE SUPPORT (AppLocalizations)                                  */
/* --------------------------------------------------------------------- */
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (loc == null) {
      throw FlutterError('AppLocalizations not found in the given context.');
    }
    return loc;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // --- MODIFIED --- (Reworked all notification strings)
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'selectLang': 'Select Language',
      'confirm': 'Confirm',
      'welcome': 'Welcome!',
      'yourName': 'Your name',
      'startingBalance': 'Starting balance',
      'currency': 'Currency',
      'start': 'Start',
      'hey': 'Hey, ',
      'balance': 'Balance',
      'income': 'Income',
      'expense': 'Expense',
      'quickActions': 'Quick Actions',
      'add': 'Add',
      'minus': 'Minus',
      'recentTransactions': 'Recent Transactions',
      'export': 'Export',
      'showAll': 'Show all',
      'fullHistory': 'Full History',
      'settings': 'Settings',
      'darkMode': 'Dark Mode',
      'editName': 'Edit Name',
      'changeCurrency': 'Change Currency',
      'resetData': 'Reset All Data',
      'developer': 'Developer',
      'builtWithLove': 'This app was built with love and passion',
      'website': 'Website',
      'github': 'GitHub',
      'addIncome': 'Add Income',
      'addExpense': 'Add Expense',
      'amount': 'Amount',
      'cancel': 'Cancel',
      'save': 'Save',
      'reset': 'Reset',
      'noTransactions': 'No transactions yet',
      'week': 'Week',
      'month': 'Month',
      'year': 'Year',
      'language': 'Language',
      'description': 'Description (Optional)',
      'category': 'Category',
      'food': 'Food',
      'transport': 'Transport',
      'entertainment': 'Entertainment',
      'shopping': 'Shopping',
      'health': 'Health',
      'bills': 'Bills',
      'salary': 'Salary',
      'gifts': 'Gifts',
      'other': 'Other',
      // --- NEW NOTIFICATION STRINGS ---
      'notifMorningTitle1': 'Good morning, {username}! ☀️',
      'notifMorningBody1':
          'Ready to conquer your finances? Start by logging today\'s first move.',
      'notifMorningTitle2': 'Rise and shine, {username}!',
      'notifMorningBody2':
          'A new day to grow your wallet. Open CashInOut and stay on top.',
      'notifMiddayTitle1': 'Lunchtime check-in, {username}!',
      'notifMiddayBody1':
          'Grabbed a bite? Take 10 seconds to log it. Your future self will thank you.',
      'notifMiddayTitle2': 'Hey {username}, how\'s your day?',
      'notifMiddayBody2':
          'Don\'t let expenses slip by. A quick log keeps your balance accurate.',
      'notifAfternoonTitle1': 'Afternoon update, {username} ☕',
      'notifAfternoonBody1':
          'Heading home soon? Log that transport cost or afternoon coffee!',
      'notifAfternoonTitle2': 'Quick reminder, {username}!',
      'notifAfternoonBody2':
          'Keep the momentum going. Add any new transactions to see your progress.',
      'notifEveningTitle': 'Your Daily Report, {username} 📊',
      'notifEveningBodySummary':
          'Today: +{income} | -{expense}. Your new balance is {balance}. Great job!',
      'notifEveningBodyNoActivity':
          'No new transactions logged today. Your balance is {balance}. Don\'t forget to update!',
      'notifNightTitle': 'Wrapping up, {username}? 🌙',
      'notifNightBodySummary':
          'You rocked it today with +{income} earned and -{expense} managed. Sleep well!',
      'notifNightBodyNoActivity':
          'One last check... any final expenses to log before bed? Keep your records perfect!',
    },
    'fr': {
      'selectLang': 'Sélectionner la langue',
      'confirm': 'Confirmer',
      'welcome': 'Bienvenue !',
      'yourName': 'Votre nom',
      'startingBalance': 'Solde initial',
      'currency': 'Devise',
      'start': 'Démarrer',
      'hey': 'Salut, ',
      'balance': 'Solde',
      'income': 'Revenus',
      'expense': 'Dépenses',
      'quickActions': 'Actions rapides',
      'add': 'Ajouter',
      'minus': 'Soustraire',
      'recentTransactions': 'Transactions récentes',
      'export': 'Exporter',
      'showAll': 'Tout afficher',
      'fullHistory': 'Historique complet',
      'settings': 'Paramètres',
      'darkMode': 'Mode sombre',
      'editName': 'Modifier le nom',
      'changeCurrency': 'Changer la devise',
      'resetData': 'Réinitialiser',
      'developer': 'Développeur',
      'builtWithLove': 'Cette application a été créée with amour et passion',
      'website': 'Site web',
      'github': 'GitHub',
      'addIncome': 'Ajouter un revenu',
      'addExpense': 'Ajouter une dépense',
      'amount': 'Montant',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'reset': 'Réinitialiser',
      'noTransactions': 'Aucune transaction',
      'week': 'Semaine',
      'month': 'Mois',
      'year': 'Année',
      'language': 'Langue',
      'description': 'Description (Optionnel)',
      'category': 'Catégorie',
      'food': 'Nourriture',
      'transport': 'Transport',
      'entertainment': 'Divertissement',
      'shopping': 'Achats',
      'health': 'Santé',
      'bills': 'Factures',
      'salary': 'Salaire',
      'gifts': 'Cadeaux',
      'other': 'Autre',
      // --- NEW NOTIFICATION STRINGS ---
      'notifMorningTitle1': 'Bonjour, {username} ! ☀️',
      'notifMorningBody1':
          'Prêt à maîtriser vos finances ? Commencez par noter votre premier mouvement du jour.',
      'notifMorningTitle2': 'Debout, {username} !',
      'notifMorningBody2':
          'Un nouveau jour pour faire grandir votre portefeuille. Ouvrez CashInOut et gardez le contrôle.',
      'notifMiddayTitle1': 'Point du midi, {username} !',
      'notifMiddayBody1':
          'Un petit creux ? Prenez 10 secondes pour l\'enregistrer. Votre futur vous remerciera.',
      'notifMiddayTitle2': 'Salut {username}, comment ça va ?',
      'notifMiddayBody2':
          'Ne laissez pas les dépenses s\'accumuler. Un enregistrement rapide garantit un solde précis.',
      'notifAfternoonTitle1': 'Mise à jour de l\'après-midi, {username} ☕',
      'notifAfternoonBody1':
          'Bientôt la fin ? Notez ces frais de transport ou ce café !',
      'notifAfternoonTitle2': 'Petit rappel, {username} !',
      'notifAfternoonBody2':
          'Continuez sur votre lancée. Ajoutez vos nouvelles transactions pour voir vos progrès.',
      'notifEveningTitle': 'Votre rapport du jour, {username} 📊',
      'notifEveningBodySummary':
          'Aujourd\'hui : +{income} | -{expense}. Votre nouveau solde est de {balance}. Bravo !',
      'notifEveningBodyNoActivity':
          'Aucune transaction enregistrée aujourd\'hui. Votre solde est de {balance}. Pensez à mettre à jour !',
      'notifNightTitle': 'C\'est la fin, {username} ? 🌙',
      'notifNightBodySummary':
          'Vous avez assuré aujourd\'hui avec +{income} gagnés et -{expense} gérés. Dormez bien !',
      'notifNightBodyNoActivity':
          'Une dernière vérification... des dépenses finales à noter avant de dormir ? Gardez des comptes parfaits !',
    },
    'ar': {
      'selectLang': 'اختر اللغة',
      'confirm': 'تأكيد',
      'welcome': 'مرحباً!',
      'yourName': 'اسمك',
      'startingBalance': 'الرصيد الابتدائي',
      'currency': 'العملة',
      'start': 'ابدأ',
      'hey': 'مرحباً، ',
      'balance': 'الرصيد',
      'income': 'الدخل',
      'expense': 'المصروفات',
      'quickActions': 'إجراءات سريعة',
      'add': 'إضافة',
      'minus': 'خصم',
      'recentTransactions': 'المعاملات الأخيرة',
      'export': 'تصدير',
      'showAll': 'عرض الكل',
      'fullHistory': 'السجل الكامل',
      'settings': 'الإعدادات',
      'darkMode': 'الوضع الليلي',
      'editName': 'تعديل الاسم',
      'changeCurrency': 'تغيير العملة',
      'resetData': 'إعادة تعيين البيانات',
      'developer': 'المطور',
      'builtWithLove': 'تم تطوير هذا التطبيق بحب وشغف',
      'website': 'الموقع الإلكتروني',
      'github': 'GitHub',
      'addIncome': 'إضافة دخل',
      'addExpense': 'إضافة مصروف',
      'amount': 'المبلغ',
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'reset': 'إعادة تعيين',
      'noTransactions': 'لا توجد معاملات',
      'week': 'أسبوع',
      'month': 'شهر',
      'year': 'سنة',
      'language': 'اللغة',
      'description': 'الوصف (اختياري)',
      'category': 'الفئة',
      'food': 'طعام',
      'transport': 'مواصلات',
      'entertainment': 'ترفيه',
      'shopping': 'تسوق',
      'health': 'صحة',
      'bills': 'فواتير',
      'salary': 'راتب',
      'gifts': 'هدايا',
      'other': 'أخرى',
      // --- NEW NOTIFICATION STRINGS ---
      'notifMorningTitle1': 'صباح الخير، {username}! ☀️',
      'notifMorningBody1':
          'مستعد للسيطرة على أموالك؟ ابدأ بتسجيل أول حركة مالية اليوم.',
      'notifMorningTitle2': 'صباح النجاح، {username}!',
      'notifMorningBody2':
          'يوم جديد لتنمية محفظتك. افتح CashInOut وابقَ متحكماً.',
      'notifMiddayTitle1': 'تفقّد الظهيرة، {username}!',
      'notifMiddayBody1':
          'هل تناولت الغداء؟ خذ 10 ثوانٍ لتسجيله. مستقبلك سيشكرك.',
      'notifMiddayTitle2': 'مرحباً {username}، كيف يومك؟',
      'notifMiddayBody2':
          'لا تدع المصاريف تفلت منك. تسجيل سريع يحافظ على دقة رصيدك.',
      'notifAfternoonTitle1': 'تحديث المساء، {username} ☕',
      'notifAfternoonBody1':
          'هل أنت في طريقك للمنزل؟ سجل تكلفة المواصلات أو قهوة العصر!',
      'notifAfternoonTitle2': 'تذكير سريع، {username}!',
      'notifAfternoonBody2': 'حافظ على حماسك. أضف أي معاملات جديدة لترى تقدمك.',
      'notifEveningTitle': 'تقريرك اليومي، {username} 📊',
      'notifEveningBodySummary':
          'اليوم: +{income} | -{expense}. رصيدك الجديد {balance}. أحسنت صنعاً!',
      'notifEveningBodyNoActivity':
          'لم يتم تسجيل معاملات جديدة اليوم. رصيدك {balance}. لا تنس التحديث!',
      'notifNightTitle': 'تستعد للنوم، {username}؟ 🌙',
      'notifNightBodySummary':
          'لقد أبدعت اليوم بدخل +{income} وإدارة -{expense}. نوماً هنيئاً!',
      'notifNightBodyNoActivity':
          'تحقق أخير... هل هناك أي مصاريف أخيرة لتسجيلها قبل النوم؟ حافظ على سجلاتك مثالية!',
    },
  };

  String get selectLang =>
      _localizedValues[locale.languageCode]!['selectLang']!;
  String get confirm => _localizedValues[locale.languageCode]!['confirm']!;
  String get welcome => _localizedValues[locale.languageCode]!['welcome']!;
  String get yourName => _localizedValues[locale.languageCode]!['yourName']!;
  String get startingBalance =>
      _localizedValues[locale.languageCode]!['startingBalance']!;
  String get currency => _localizedValues[locale.languageCode]!['currency']!;
  String get start => _localizedValues[locale.languageCode]!['start']!;
  String hey(String name) =>
      '${_localizedValues[locale.languageCode]!['hey']!}$name';
  String get balance => _localizedValues[locale.languageCode]!['balance']!;
  String get income => _localizedValues[locale.languageCode]!['income']!;
  String get expense => _localizedValues[locale.languageCode]!['expense']!;
  String get quickActions =>
      _localizedValues[locale.languageCode]!['quickActions']!;
  String get add => _localizedValues[locale.languageCode]!['add']!;
  String get minus => _localizedValues[locale.languageCode]!['minus']!;
  String get recentTransactions =>
      _localizedValues[locale.languageCode]!['recentTransactions']!;
  String get export => _localizedValues[locale.languageCode]!['export']!;
  String get showAll => _localizedValues[locale.languageCode]!['showAll']!;
  String get fullHistory =>
      _localizedValues[locale.languageCode]!['fullHistory']!;
  String get settings => _localizedValues[locale.languageCode]!['settings']!;
  String get darkMode => _localizedValues[locale.languageCode]!['darkMode']!;
  String get editName => _localizedValues[locale.languageCode]!['editName']!;
  String get changeCurrency =>
      _localizedValues[locale.languageCode]!['changeCurrency']!;
  String get resetData => _localizedValues[locale.languageCode]!['resetData']!;
  String get developer => _localizedValues[locale.languageCode]!['developer']!;
  String get builtWithLove =>
      _localizedValues[locale.languageCode]!['builtWithLove']!;
  String get website => _localizedValues[locale.languageCode]!['website']!;
  String get github => _localizedValues[locale.languageCode]!['github']!;
  String get addIncome => _localizedValues[locale.languageCode]!['addIncome']!;
  String get addExpense =>
      _localizedValues[locale.languageCode]!['addExpense']!;
  String get amount => _localizedValues[locale.languageCode]!['amount']!;
  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
  String get save => _localizedValues[locale.languageCode]!['save']!;
  String get reset => _localizedValues[locale.languageCode]!['reset']!;
  String get noTransactions =>
      _localizedValues[locale.languageCode]!['noTransactions']!;
  String get week => _localizedValues[locale.languageCode]!['week']!;
  String get month => _localizedValues[locale.languageCode]!['month']!;
  String get year => _localizedValues[locale.languageCode]!['year']!;
  String get language => _localizedValues[locale.languageCode]!['language']!;

  // --- NEW CATEGORY & DESCRIPTION GETTERS ---
  String get description =>
      _localizedValues[locale.languageCode]!['description']!;
  String get category => _localizedValues[locale.languageCode]!['category']!;
  String get food => _localizedValues[locale.languageCode]!['food']!;
  String get transport => _localizedValues[locale.languageCode]!['transport']!;
  String get entertainment =>
      _localizedValues[locale.languageCode]!['entertainment']!;
  String get shopping => _localizedValues[locale.languageCode]!['shopping']!;
  String get health => _localizedValues[locale.languageCode]!['health']!;
  String get bills => _localizedValues[locale.languageCode]!['bills']!;
  String get salary => _localizedValues[locale.languageCode]!['salary']!;
  String get gifts => _localizedValues[locale.languageCode]!['gifts']!;
  String get other => _localizedValues[locale.languageCode]!['other']!;

  // --- NEW HELPER ---
  // Helper to get the localized display name for a category key
  String getCategoryDisplayName(String? key) {
    switch (key) {
      case 'food':
        return food;
      case 'transport':
        return transport;
      case 'entertainment':
        return entertainment;
      case 'shopping':
        return shopping;
      case 'health':
        return health;
      case 'bills':
        return bills;
      case 'salary':
        return salary;
      case 'gifts':
        return gifts;
      case 'other':
        return other;
      default:
        return other;
    }
  }

  // --- MODIFIED --- (New notification string getters)
  String notifMorningTitle1(String username) =>
      _localizedValues[locale.languageCode]!['notifMorningTitle1']!.replaceAll(
        '{username}',
        username,
      );
  String get notifMorningBody1 =>
      _localizedValues[locale.languageCode]!['notifMorningBody1']!;
  String notifMorningTitle2(String username) =>
      _localizedValues[locale.languageCode]!['notifMorningTitle2']!.replaceAll(
        '{username}',
        username,
      );
  String get notifMorningBody2 =>
      _localizedValues[locale.languageCode]!['notifMorningBody2']!;

  String notifMiddayTitle1(String username) =>
      _localizedValues[locale.languageCode]!['notifMiddayTitle1']!.replaceAll(
        '{username}',
        username,
      );
  String get notifMiddayBody1 =>
      _localizedValues[locale.languageCode]!['notifMiddayBody1']!;
  String notifMiddayTitle2(String username) =>
      _localizedValues[locale.languageCode]!['notifMiddayTitle2']!.replaceAll(
        '{username}',
        username,
      );
  String get notifMiddayBody2 =>
      _localizedValues[locale.languageCode]!['notifMiddayBody2']!;

  String notifAfternoonTitle1(String username) =>
      _localizedValues[locale.languageCode]!['notifAfternoonTitle1']!
          .replaceAll('{username}', username);
  String get notifAfternoonBody1 =>
      _localizedValues[locale.languageCode]!['notifAfternoonBody1']!;
  String notifAfternoonTitle2(String username) =>
      _localizedValues[locale.languageCode]!['notifAfternoonTitle2']!
          .replaceAll('{username}', username);
  String get notifAfternoonBody2 =>
      _localizedValues[locale.languageCode]!['notifAfternoonBody2']!;

  String notifEveningTitle(String username) =>
      _localizedValues[locale.languageCode]!['notifEveningTitle']!.replaceAll(
        '{username}',
        username,
      );
  String notifEveningBodySummary(
    String income,
    String expense,
    String balance,
  ) => _localizedValues[locale.languageCode]!['notifEveningBodySummary']!
      .replaceAll('{income}', income)
      .replaceAll('{expense}', expense)
      .replaceAll('{balance}', balance);
  String notifEveningBodyNoActivity(String balance) =>
      _localizedValues[locale.languageCode]!['notifEveningBodyNoActivity']!
          .replaceAll('{balance}', balance);

  String notifNightTitle(String username) =>
      _localizedValues[locale.languageCode]!['notifNightTitle']!.replaceAll(
        '{username}',
        username,
      );
  String notifNightBodySummary(String income, String expense) =>
      _localizedValues[locale.languageCode]!['notifNightBodySummary']!
          .replaceAll('{income}', income)
          .replaceAll('{expense}', expense);
  String get notifNightBodyNoActivity =>
      _localizedValues[locale.languageCode]!['notifNightBodyNoActivity']!;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'fr', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_) => false;
}

/* --------------------------------------------------------------------- */
/* HELPER FORMATTERS                                                    */
/* --------------------------------------------------------------------- */
String formatCurrency(double amount, String currency) => intl_fmt
    .NumberFormat.currency(symbol: currency, decimalDigits: 2).format(amount);

// --- NEW --- (Compact formatter for large numbers)
String formatCurrencyCompact(double amount, String currency) =>
    intl_fmt.NumberFormat.compactCurrency(
      symbol: currency,
      decimalDigits: 2,
    ).format(amount);

/* --------------------------------------------------------------------- */
/* MAIN APP                                                             */
/* --------------------------------------------------------------------- */
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  static MainAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainAppState>();
  }

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  // 1. Instantiate the Notification Service
  final NotificationService _notificationService = NotificationService();

  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // 2. Initialize Notification Service
    // No need to await here, let it run asynchronously
    _notificationService.initNotifications();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language') ?? 'en';
    final isDark = prefs.getBool('dark_mode') ?? false;

    setState(() {
      _locale = Locale(langCode);
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _isLoading = false;
    });

    // 3. Schedule notifications after loading settings
    // Ensure the app is not rebuilding unnecessarily
    if (!_isLoading) {
      _scheduleNotifications();
    }
  }

  // New method to schedule localized notifications
  void _scheduleNotifications() {
    // Wait for the first frame so MaterialApp and its Localizations are available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = navigatorKey.currentContext;
      if (navContext != null) {
        try {
          final loc = AppLocalizations.of(navContext);
          // --- MODIFIED --- (Service now handles all data loading)
          _notificationService.scheduleDailyNotifications(loc);
        } catch (e) {
          // In case Localizations are still not ready, fallback to the stored locale
          debugPrint(
            'AppLocalizations not available yet: $e — falling back to stored locale ${_locale.languageCode}',
          );
          try {
            final fallbackLoc = AppLocalizations(_locale);
            _notificationService.scheduleDailyNotifications(fallbackLoc);
          } catch (e2) {
            debugPrint(
              'Failed to schedule notifications with fallback locale: $e2',
            );
          }
        }
      } else {
        debugPrint(
          'Navigator context not available for scheduling notifications.',
        );
      }
    });
  }

  // Public helper to (re)schedule notifications using the app's current locale/context.
  // Call this after locale changes or when you want to force rescheduling.
  Future<void> rescheduleNotifications() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = navigatorKey.currentContext;
      try {
        final loc =
            ctx != null ? AppLocalizations.of(ctx) : AppLocalizations(_locale);
        // --- MODIFIED --- (Service now handles all data loading)
        await _notificationService.scheduleDailyNotifications(loc);
      } catch (e) {
        debugPrint('Failed to schedule notifications: $e');
      }
    });
  }

  Future<void> setLocaleAndRestart(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
    await prefs.setBool('language_set', true);

    // Removed setState and _scheduleNotifications to prevent using old context

    final navContext = navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      Navigator.pushAndRemoveUntil(
        navContext,
        MaterialPageRoute(builder: (_) => const MainApp()),
        (r) => false,
      );
    }
  }

  Future<void> setThemeAndRestart(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark);

    final navContext = navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      Navigator.pushAndRemoveUntil(
        navContext,
        MaterialPageRoute(builder: (_) => const MainApp()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CashInOut',
      locale: _locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: _themeMode,
      home: const OnboardingWrapper(),
    );
  }

  ThemeData _lightTheme() {
    final isArabic = _locale.languageCode == 'ar';
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.cardLight,
      fontFamily:
          isArabic
              ? GoogleFonts.zain().fontFamily
              : GoogleFonts.poppins().fontFamily,
      textTheme:
          isArabic
              ? GoogleFonts.zainTextTheme()
              : GoogleFonts.poppinsTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  ThemeData _darkTheme() {
    final isArabic = _locale.languageCode == 'ar';
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.darkBg,
      cardColor: AppColors.cardDark,
      fontFamily:
          isArabic
              ? GoogleFonts.cairo().fontFamily
              : GoogleFonts.poppins().fontFamily,
      textTheme:
          isArabic
              ? GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme)
              : GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

/* --------------------------------------------------------------------- */
/* 1. ONBOARDING                                                        */
/* --------------------------------------------------------------------- */
class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});
  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  bool _hasCompleted = false;
  bool _isInitialCheckDone = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    final langSet = prefs.getBool('language_set') ?? false;

    setState(() {
      _hasCompleted = done;
      _isInitialCheckDone = true;
    });

    if (!langSet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLanguageDialog();
      });
    }
  }

  void _showLanguageDialog() {
    String selected = Localizations.localeOf(context).languageCode;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final loc = AppLocalizations.of(dialogContext);

        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: Text(loc.selectLang),
              content: DropdownButton<String>(
                value: selected,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    stfSetState(() => selected = v);
                  }
                },
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(loc.confirm),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    MainApp.of(context)?.setLocaleAndRestart(selected);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialCheckDone) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _hasCompleted
        ? const HomePage()
        : FadeInSlide(
          child: OnboardingPage(
            onFinish: () => setState(() => _hasCompleted = true),
          ),
        );
  }
}

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingPage({required this.onFinish, super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController(text: '0.00');
  String _currency = 'MAD';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final initialBalance = double.tryParse(_balanceCtrl.text) ?? 0.0;
    final transactions = <Transaction>[];

    if (initialBalance != 0.0) {
      transactions.add(
        Transaction(
          amount: initialBalance,
          date: DateTime.now(),
          balanceAfter: initialBalance,
          category: 'other', // --- MODIFIED ---
          description: 'Starting Balance', // --- MODIFIED ---
        ),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    await prefs.setString('username', _nameCtrl.text.trim());
    await prefs.setDouble('balance', initialBalance);
    await prefs.setString('currency', _currency);
    await prefs.setString(
      'transactions',
      jsonEncode(transactions.map((t) => t.toJson()).toList()),
    );

    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeInSlide(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Cash',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineLarge!.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(
                                    context,
                                  ).textTheme.headlineLarge!.color,
                            ),
                          ),
                          TextSpan(
                            text: 'in',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineLarge!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.positive,
                            ),
                          ),
                          TextSpan(
                            text: 'out',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineLarge!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.negative,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    child: Text(
                      loc.welcome,
                      style: Theme.of(context).textTheme.headlineMedium!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInSlide(
                    delay: 0.2,
                    child: TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: loc.yourName,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    delay: 0.3,
                    child: TextFormField(
                      controller: _balanceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: loc.startingBalance,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    delay: 0.4,
                    child: DropdownButtonFormField<String>(
                      value: _currency,
                      decoration: InputDecoration(
                        labelText: loc.currency,
                        border: const OutlineInputBorder(),
                      ),
                      items:
                          ['MAD', 'USD', 'EUR', 'GBP']
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInSlide(
                    delay: 0.5,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: Text(
                          loc.start,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* --------------------------------------------------------------------- */
/* 2. HOME PAGE                                                         */
/* --------------------------------------------------------------------- */

// --- MODIFIED --- (Removed old ChartData class)
// --- NEW --- (Data model for Syncfusion line chart)
class SalesData {
  SalesData(this.date, this.net);
  final DateTime date;
  final double net;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String? username;
  double? balance;
  String? currency;
  List<Transaction> transactions = [];
  ChartPeriod period = ChartPeriod.week;

  late Future<void> _initFuture;
  late AnimationController _fabController;

  // --- NEW --- (Tooltip behavior for Syncfusion chart)
  late TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // --- NEW ---
    _tooltipBehavior = TooltipBehavior(
      enable: true,
      // Format the tooltip
      builder: (
        dynamic data,
        dynamic point,
        dynamic series,
        int pointIndex,
        int seriesIndex,
      ) {
        final SalesData salesData = data as SalesData;
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5),
            ],
          ),
          child: Text(
            // --- MODIFIED --- (Use regular formatCurrency for tooltips)
            '${intl_fmt.DateFormat('MMM d').format(salesData.date)}: ${formatCurrency(salesData.net, currency!)}',
            style: TextStyle(
              color:
                  salesData.net >= 0 ? AppColors.positive : AppColors.negative,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
    _initFuture = _loadAll();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? 'User';
      balance = prefs.getDouble('balance') ?? 0;
      currency = prefs.getString('currency') ?? 'MAD';
      final json = prefs.getString('transactions') ?? '[]';
      transactions =
          (jsonDecode(json) as List)
              .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
              .toList();
      transactions.sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('balance', balance!);
    await prefs.setString(
      'transactions',
      jsonEncode(transactions.map((t) => t.toJson()).toList()),
    );
  }

  double get totalIncome =>
      transactions.where((t) => t.amount > 0).fold(0, (a, b) => a + b.amount);
  double get totalExpense => transactions
      .where((t) => t.amount < 0)
      .fold(0, (a, b) => a + b.amount.abs());

  Map<DateTime, double> _getNets(ChartPeriod period) {
    Map<DateTime, double> nets = {};
    for (final t in transactions) {
      final date = t.date;
      DateTime key;

      if (period == ChartPeriod.year) {
        key = DateTime(date.year, date.month, 1); // Group by Month
      } else {
        key = DateTime(date.year, date.month, date.day); // Group by Day
      }

      nets[key] = (nets[key] ?? 0) + t.amount;
    }
    return nets;
  }

  // --- MODIFIED --- (Changed to return List<SalesData> for Syncfusion)
  List<SalesData> _getChartData() {
    final now = DateTime.now();
    final nets = _getNets(period);
    DateTime startDate;

    if (period == ChartPeriod.week) {
      startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
    } else if (period == ChartPeriod.month) {
      startDate = DateTime(now.year, now.month, 1);
    } else {
      // Year
      startDate = DateTime(now.year, now.month - 11, 1);
    }

    final List<DateTime> relevantPeriods = [];
    final List<SalesData> chartData = [];

    if (period == ChartPeriod.year) {
      for (int i = 0; i < 12; i++) {
        int mon = startDate.month + i;
        int yr = startDate.year;
        while (mon > 12) {
          mon -= 12;
          yr++;
        }
        relevantPeriods.add(DateTime(yr, mon, 1));
      }
    } else {
      DateTime current = startDate;
      final endDate = DateTime(now.year, now.month, now.day);
      while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
        relevantPeriods.add(current);
        current = current.add(const Duration(days: 1));
      }
    }

    // Populate chartData with net values for each period
    for (final p in relevantPeriods) {
      final net = nets[p] ?? 0.0;
      chartData.add(SalesData(p, net));
    }

    // Handle empty case
    if (chartData.isEmpty) {
      chartData.add(SalesData(DateTime.now(), 0));
    }

    return chartData;
  }

  // --- MODIFIED --- (Removed _getTooltipItems, Syncfusion handles this)

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isRTL = Localizations.localeOf(context).languageCode == 'ar';

    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Directionality(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            appBar: AppBar(
              title: FadeInSlide(
                child: Text(
                  loc.hey(username!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              centerTitle: true,
              backgroundColor: AppColors.primary,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              actions: [
                FadeInSlide(
                  delay: 0.1,
                  child: IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed:
                        () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, a1, a2) => const SettingsPage(),
                            transitionsBuilder:
                                (_, a, __, c) =>
                                    FadeTransition(opacity: a, child: c),
                          ),
                        ),
                  ),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final padding = constraints.maxWidth > 600 ? 40.0 : 20.0;
                return StaggeredFadeIn(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: loc.income,
                                value: totalIncome,
                                color: AppColors.positive,
                                delay: 0.1,
                                currency: currency!,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: loc.expense,
                                value: totalExpense,
                                color: AppColors.negative,
                                delay: 0.2,
                                currency: currency!,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FadeInSlide(
                          delay: 0.3,
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loc.balance,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(
                                          begin: 0,
                                          end: balance!,
                                        ),
                                        duration: const Duration(
                                          milliseconds: 1200,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, value, child) {
                                          return Text(
                                            // --- MODIFIED --- (Use compact formatter)
                                            formatCurrencyCompact(
                                              value,
                                              currency!,
                                            ),
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  value >= 0
                                                      ? AppColors.positive
                                                      : AppColors.negative,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.account_balance_wallet,
                                    size: 56,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeInSlide(
                          delay: 0.4,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _periodChip(loc.week, ChartPeriod.week),
                              _periodChip(loc.month, ChartPeriod.month),
                              _periodChip(loc.year, ChartPeriod.year),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeInSlide(
                          delay: 0.5,
                          child: Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: SizedBox(
                                height: 280,
                                // --- MODIFIED --- (Replaced LineChart with SfCartesianChart)
                                child: Builder(
                                  builder: (context) {
                                    final chartData = _getChartData();

                                    // Determine axis intervals
                                    DateTimeIntervalType intervalType;
                                    double interval;
                                    intl_fmt.DateFormat dateFormat;

                                    if (period == ChartPeriod.year) {
                                      intervalType =
                                          DateTimeIntervalType.months;
                                      interval = 1;
                                      dateFormat = intl_fmt.DateFormat.MMM(
                                        loc.locale.languageCode,
                                      );
                                    } else if (period == ChartPeriod.month) {
                                      intervalType = DateTimeIntervalType.days;
                                      interval = 5; // Show a label every 5 days
                                      dateFormat = intl_fmt.DateFormat.d(
                                        loc.locale.languageCode,
                                      );
                                    } else {
                                      // Week
                                      intervalType = DateTimeIntervalType.days;
                                      interval = 1; // Show a label every day
                                      dateFormat = intl_fmt.DateFormat.E(
                                        loc.locale.languageCode,
                                      );
                                    }

                                    return SfCartesianChart(
                                      primaryXAxis: DateTimeAxis(
                                        intervalType: intervalType,
                                        interval: interval,
                                        dateFormat: dateFormat,
                                        majorGridLines: const MajorGridLines(
                                          width: 0,
                                        ),
                                        axisLine: const AxisLine(width: 0),
                                        // --- MODIFIED --- (Rotate labels to prevent overlap)
                                        labelIntersectAction:
                                            AxisLabelIntersectAction.rotate45,
                                      ),
                                      primaryYAxis: NumericAxis(
                                        // Use compact format for large numbers
                                        numberFormat:
                                            intl_fmt.NumberFormat.compact(),
                                        axisLine: const AxisLine(width: 0),
                                        majorTickLines: const MajorTickLines(
                                          size: 0,
                                        ),
                                        // Add a plot band to highlight the 0 line
                                        plotBands: <PlotBand>[
                                          PlotBand(
                                            start: 0,
                                            end: 0,
                                            borderColor: Colors.grey
                                                .withOpacity(0.5),
                                            borderWidth: 1,
                                          ),
                                        ],
                                      ),
                                      tooltipBehavior: _tooltipBehavior,
                                      series: <
                                        CartesianSeries<SalesData, DateTime>
                                      >[
                                        SplineAreaSeries<SalesData, DateTime>(
                                          dataSource: chartData,
                                          xValueMapper:
                                              (SalesData sales, _) =>
                                                  sales.date,
                                          yValueMapper:
                                              (SalesData sales, _) => sales.net,
                                          splineType: SplineType.cardinal,
                                          // Line color
                                          borderColor: AppColors.primary,
                                          borderWidth: 3,
                                          // Fill gradient
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary.withOpacity(
                                                0.4,
                                              ),
                                              AppColors.primary.withOpacity(
                                                0.1,
                                              ),
                                              AppColors.negative.withOpacity(
                                                0.1,
                                              ),
                                              AppColors.negative.withOpacity(
                                                0.4,
                                              ),
                                            ],
                                            stops: [0.0, 0.45, 0.55, 1.0],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeInSlide(
                          delay: 0.6,
                          child: Text(
                            loc.quickActions,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeInSlide(
                          delay: 0.7,
                          child: Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  label: loc.add,
                                  gradient: [
                                    AppColors.positive,
                                    AppColors.positive.withAlpha(
                                      204,
                                    ), // FIX: withOpacity(0.8)
                                  ],
                                  onTap: () => _modifyBalance(true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionButton(
                                  label: loc.minus,
                                  gradient: [
                                    AppColors.negative,
                                    AppColors.negative.withAlpha(
                                      204,
                                    ), // FIX: withOpacity(0.8)
                                  ],
                                  onTap: () => _modifyBalance(false),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeInSlide(
                          delay: 0.8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.recentTransactions,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton.icon(
                                onPressed:
                                    () => _exportCsv(loc), // --- MODIFIED ---
                                icon: const Icon(Icons.share),
                                label: Text(loc.export),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeInSlide(
                          delay: 0.9,
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child:
                                transactions.isEmpty
                                    ? Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Center(
                                        child: Text(loc.noTransactions),
                                      ),
                                    )
                                    : ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount:
                                          transactions.length > 5
                                              ? 5
                                              : transactions.length,
                                      separatorBuilder:
                                          (_, __) => const Divider(height: 1),
                                      itemBuilder: (_, i) {
                                        final t =
                                            transactions[transactions.length -
                                                1 -
                                                i];
                                        // --- MODIFIED --- (ListTile layout changed)
                                        final isPositive = t.amount > 0;
                                        final color =
                                            isPositive
                                                ? AppColors.positive
                                                : AppColors.negative;

                                        return ScaleFadeIn(
                                          delay: i * 0.05,
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: color.withAlpha(
                                                51,
                                              ),
                                              child: Icon(
                                                AppCategories.getIcon(
                                                  t.category,
                                                ),
                                                color: color,
                                                size: 20,
                                              ),
                                            ),
                                            title: Text(
                                              t.description?.isNotEmpty == true
                                                  ? t.description!
                                                  : loc.getCategoryDisplayName(
                                                    t.category,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              intl_fmt.DateFormat(
                                                'MMM dd, HH:mm',
                                                loc.locale.languageCode,
                                              ).format(t.date),
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${isPositive ? '+' : ''}${formatCurrency(t.amount.abs(), currency!)}',
                                                  style: TextStyle(
                                                    color: color,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  // --- MODIFIED --- (Use compact formatter)
                                                  formatCurrencyCompact(
                                                    t.balanceAfter,
                                                    currency!,
                                                  ),
                                                  style:
                                                      Theme.of(
                                                        context,
                                                      ).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ),
                        if (transactions.length > 5)
                          FadeInSlide(
                            delay: 1.0,
                            child: TextButton(
                              onPressed:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => HistoryPage(
                                            transactions: transactions,
                                            currency: currency!,
                                          ),
                                    ),
                                  ),
                              child: Text(loc.showAll),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            floatingActionButton: ScaleTransition(
              scale: _fabController,
              child: FloatingActionButton(
                onPressed: () {
                  _fabController.forward();
                  _modifyBalance(true);
                },
                backgroundColor: AppColors.accent,
                child: const Icon(Icons.add, size: 32),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _periodChip(String label, ChartPeriod p) {
    final selected = period == p;
    return ChoiceChip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selected,
      onSelected: (_) => setState(() => period = p),
      selectedColor: AppColors.primary.withAlpha(51), // FIX: withOpacity(0.2)
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              selected
                  ? AppColors.primary
                  : Theme.of(
                    context,
                  ).dividerColor.withAlpha(128), // FIX: withOpacity(0.5)
        ),
      ),
    );
  }

  // --- MODIFIED --- (Whole dialog logic updated for categories)
  Future<void> _modifyBalance(bool add) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final loc = AppLocalizations.of(context);
    String? selectedCategory = add ? 'salary' : 'food';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(add ? loc.addIncome : loc.addExpense),
            content: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: '${loc.amount} ($currency)',
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                          validator:
                              (v) =>
                                  double.tryParse(v ?? '') == null ||
                                          double.parse(v!) <= 0
                                      ? 'Enter valid amount'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descCtrl,
                          decoration: InputDecoration(
                            labelText: loc.description,
                            prefixIcon: const Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.category,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children:
                              AppCategories.keys.map((key) {
                                final isSelected = selectedCategory == key;
                                return ChoiceChip(
                                  label: Text(loc.getCategoryDisplayName(key)),
                                  avatar: Icon(
                                    AppCategories.getIcon(key),
                                    size: 16,
                                    color:
                                        isSelected
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                            : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color:
                                        isSelected
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                            : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      selectedCategory = key;
                                    });
                                  },
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, {
                      'amount': double.parse(amountCtrl.text),
                      'description': descCtrl.text.trim(),
                      'category': selectedCategory,
                    });
                  }
                },
                child: Text(loc.save),
              ),
            ],
          ),
    );

    if (result == null) return;

    final double amount = result['amount'] as double;
    final String description = result['description'] as String;
    final String category = result['category'] as String;

    setState(() {
      balance = (balance ?? 0) + (add ? amount : -amount);
      transactions.add(
        Transaction(
          amount: add ? amount : -amount,
          date: DateTime.now(),
          balanceAfter: balance!,
          description: description,
          category: category,
        ),
      );
      _saveAll();
    });
  }

  // --- MODIFIED --- (Added loc and updated CSV format)
  Future<void> _exportCsv(AppLocalizations loc) async {
    final buffer =
        StringBuffer()..writeln('Date,Amount,Category,Description,Balance');
    for (final t in transactions) {
      buffer.writeln(
        '${intl_fmt.DateFormat('MMM dd, HH:mm').format(t.date)},${t.amount},${loc.getCategoryDisplayName(t.category)},"${t.description ?? ''}",${t.balanceAfter}',
      );
    }
    final tempDir = Directory.systemTemp;
    final path = '${tempDir.path}/cashinout_history.csv';
    await File(path).writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(path)], text: 'CashInOut History');
  }
}

/* --------------------------------------------------------------------- */
/* SETTINGS PAGE                                                        */
/* --------------------------------------------------------------------- */
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedLang = 'en';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLang = prefs.getString('language') ?? 'en';
    });
  }

  Future<void> _changeLang(String lang) async {
    MainApp.of(context)?.setLocaleAndRestart(lang);
  }

  Future<void> _toggleDarkMode(bool value) async {
    MainApp.of(context)?.setThemeAndRestart(value);
  }

  void _restartApp() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainApp()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final currentBrightness = Theme.of(context).brightness;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(loc.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FadeInSlide(
            child: SwitchListTile(
              title: Text(loc.darkMode),
              value: currentBrightness == Brightness.dark,
              onChanged: _toggleDarkMode,
            ),
          ),
          const Divider(),
          FadeInSlide(
            delay: 0.1,
            child: ListTile(
              title: Text(loc.editName),
              trailing: const Icon(Icons.edit),
              onTap: () => _editName(context),
            ),
          ),
          FadeInSlide(
            delay: 0.2,
            child: ListTile(
              title: Text(loc.changeCurrency),
              trailing: const Icon(Icons.currency_exchange),
              onTap: () => _changeCurrency(context),
            ),
          ),
          FadeInSlide(
            delay: 0.3,
            child: ListTile(
              title: Text(loc.language),
              trailing: DropdownButton<String>(
                value: _selectedLang,
                items: [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                ],
                onChanged: (v) => v != null ? _changeLang(v) : null,
              ),
            ),
          ),
          FadeInSlide(
            delay: 0.4,
            child: ListTile(
              title: Text(loc.resetData),
              trailing: const Icon(Icons.delete_forever, color: Colors.red),
              onTap: () => _resetData(context),
            ),
          ),
          const Divider(height: 32),
          FadeInSlide(
            delay: 0.5,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ScaleFadeIn(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[200],
                        child: const Icon(
                          Icons.code,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    isArabic
                        ? Text(
                          'عبد الله دروش',
                          style: Theme.of(context).textTheme.titleLarge,
                        )
                        : Text(
                          'Abdallah Driouich',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                    const SizedBox(height: 8),
                    Text(
                      loc.builtWithLove,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed:
                              () => launchUrl(
                                Uri.parse('https://portfolio.driouich.me'),
                              ),
                          icon: const Icon(Icons.web),
                          label: Text(loc.website),
                        ),
                        TextButton.icon(
                          onPressed:
                              () => launchUrl(
                                Uri.parse('https://github.com/dev0lcyber/'),
                              ),
                          icon: const Icon(Icons.code),
                          label: Text(loc.github),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    final initialName = prefs.getString('username') ?? '';
    final ctrl = TextEditingController(text: initialName);
    final loc = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: ctx,
      builder:
          (_) => AlertDialog(
            title: Text(loc.editName),
            content: TextField(controller: ctrl),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: Text(loc.save),
              ),
            ],
          ),
    );
    if (result != null && result.isNotEmpty) {
      await prefs.setString('username', result);
      // --- NEW --- Reschedule notifications with the new name
      if (ctx.mounted) {
        await MainApp.of(ctx)?.rescheduleNotifications();
        if (ctx.mounted) {
          _restartApp();
        }
      }
    }
  }

  Future<void> _changeCurrency(BuildContext ctx) async {
    final current = await SharedPreferences.getInstance().then(
      (p) => p.getString('currency') ?? 'MAD',
    );
    String? newCurrency = current;

    final loc = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: ctx,
      builder:
          (_) => AlertDialog(
            title: Text(loc.changeCurrency),
            content: StatefulBuilder(
              builder: (context, setState) {
                return DropdownButton<String>(
                  value: newCurrency,
                  items:
                      ['MAD', 'USD', 'EUR', 'GBP']
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => newCurrency = v),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), // Pop without value
                child: Text(loc.cancel),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.pop(
                      ctx,
                      newCurrency,
                    ), // Pop with selected value
                child: Text(loc.save),
              ),
            ],
          ),
    );

    if (result != null && result != current) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency', result);
      // --- NEW --- Reschedule notifications with the new currency
      if (ctx.mounted) {
        await MainApp.of(ctx)?.rescheduleNotifications();
        if (ctx.mounted) {
          _restartApp();
        }
      }
    }
  }

  Future<void> _resetData(BuildContext ctx) async {
    final loc = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(ctx).languageCode == 'ar';
    final confirm = await showDialog<bool>(
      context: ctx,
      builder:
          (_) => AlertDialog(
            title: Text(loc.reset),
            content:
                isArabic
                    ? Text(
                      'لا يمكن التراجع عن هذا الإجراء. سيتم حذف جميع المعاملات والإعدادات.',
                    )
                    : const Text(
                      'This cannot be undone. All transactions and settings will be deleted.',
                    ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(loc.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  loc.reset,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirm == true) {
      // --- NEW --- Cancel all notifications before clearing
      await NotificationService().flutterLocalNotificationsPlugin.cancelAll();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setBool('language_set', false);

      if (!ctx.mounted) return;
      _restartApp();
    }
  }
}

/* --------------------------------------------------------------------- */
/* ANIMATIONS & HELPERS                                                 */
/* --------------------------------------------------------------------- */
class FadeInSlide extends StatelessWidget {
  final Widget child;
  final double delay;
  const FadeInSlide({required this.child, this.delay = 0, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: (600 + delay * 1000).round()),
      curve: Curves.easeOutCubic,
      builder:
          (_, val, child) => Opacity(
            opacity: val,
            child: Transform.translate(
              offset: Offset(0, 50 * (1 - val)),
              child: child,
            ),
          ),
      child: child,
    );
  }
}

class ScaleFadeIn extends StatelessWidget {
  final Widget child;
  final double delay;
  const ScaleFadeIn({required this.child, this.delay = 0, super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.8, end: 1),
      duration: Duration(milliseconds: (400 + delay * 1000).round()),
      curve: Curves.easeOutCubic,
      builder:
          (_, val, child) => Transform.scale(
            scale: val,
            child: Opacity(opacity: (val - 0.8) / 0.2, child: child),
          ),
      child: child,
    );
  }
}

class StaggeredFadeIn extends StatelessWidget {
  final Widget child;
  const StaggeredFadeIn({required this.child, super.key});

  @override
  Widget build(BuildContext context) => child;
}

class _StatCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  final double delay;
  final String currency;
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.delay,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInSlide(
      delay: delay,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                // --- MODIFIED --- (Use compact formatter)
                formatCurrencyCompact(value, currency),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: gradient),
      borderRadius: BorderRadius.circular(16),
    ),
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  );
}

enum ChartPeriod { week, month, year }

// --- MODIFIED --- (Added description and category fields)
class Transaction {
  final double amount;
  final DateTime date;
  final double balanceAfter;
  final String? description;
  final String? category;

  Transaction({
    required this.amount,
    required this.date,
    required this.balanceAfter,
    this.description,
    this.category,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    amount: json['amount'] as double,
    date: DateTime.parse(json['date'] as String),
    balanceAfter: json['balanceAfter'] as double,
    description: json['description'] as String?,
    category: json['category'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'date': date.toIso8601String(),
    'balanceAfter': balanceAfter,
    'description': description,
    'category': category,
  };
}

// --- NEW --- (Data model for Syncfusion pie chart)
class ExpenseChartData {
  ExpenseChartData(this.category, this.amount);
  final String category;
  final double amount;
}

class HistoryPage extends StatelessWidget {
  final List<Transaction> transactions;
  final String currency;
  const HistoryPage({
    required this.transactions,
    required this.currency,
    super.key,
  });

  // --- MODIFIED --- (Complete rewrite for Syncfusion chart and responsiveness)
  void _showExpenseChart(
    BuildContext context,
    AppLocalizations loc,
    List<Transaction> transactions,
    String currency,
  ) {
    // 1. Process data
    final Map<String, double> expenseDataMap = {};
    final expenses = transactions.where((t) => t.amount < 0);

    if (expenses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.noTransactions)));
      return;
    }

    for (final t in expenses) {
      final key = t.category ?? 'other';
      expenseDataMap[key] = (expenseDataMap[key] ?? 0) + t.amount.abs();
    }

    // Convert map to list for Syncfusion
    final List<ExpenseChartData> pieData =
        expenseDataMap.entries
            .map((entry) => ExpenseChartData(entry.key, entry.value))
            .toList();

    int _selectedIdx = -1;

    // 2. Show Dialog
    showDialog(
      context: context,
      builder: (ctx) {
        // Get screen width for responsive sizing
        final width = MediaQuery.of(context).size.width;

        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.expense, // "Expense"
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    // Responsive SizedBox
                    SizedBox(
                      // Use 80% of screen width, max 350
                      width: math.min(width * 0.8, 350),
                      height: math.min(width * 0.8, 350),
                      child: SfCircularChart(
                        tooltipBehavior: TooltipBehavior(
                          enable: true,
                          // --- MODIFIED --- (Use regular formatCurrency for tooltips)
                          builder: (
                            dynamic data,
                            dynamic point,
                            dynamic series,
                            int pointIndex,
                            int seriesIndex,
                          ) {
                            final ExpenseChartData eData =
                                data as ExpenseChartData;
                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Text(
                                '${loc.getCategoryDisplayName(eData.category)}: ${formatCurrency(eData.amount, currency)}',
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                ),
                              ),
                            );
                          },
                        ),
                        // Use built-in legend
                        legend: Legend(
                          isVisible: true,
                          overflowMode: LegendItemOverflowMode.wrap,
                          position: LegendPosition.bottom,
                        ),
                        series: <CircularSeries>[
                          DoughnutSeries<ExpenseChartData, String>(
                            dataSource: pieData,
                            xValueMapper:
                                (ExpenseChartData data, _) =>
                                    loc.getCategoryDisplayName(data.category),
                            yValueMapper:
                                (ExpenseChartData data, _) => data.amount,
                            pointColorMapper:
                                (ExpenseChartData data, _) =>
                                    AppCategories.getColor(data.category),
                            // Explode on tap
                            explode: true,
                            explodeIndex: _selectedIdx,
                            // Data labels (e.g., percentages)
                            dataLabelSettings: const DataLabelSettings(
                              isVisible: true,
                              labelPosition: ChartDataLabelPosition.outside,
                              // Use %
                              labelIntersectAction: LabelIntersectAction.shift,
                              connectorLineSettings: ConnectorLineSettings(
                                type: ConnectorType.curve,
                                length: '10%',
                              ),
                            ),
                            dataLabelMapper: (ExpenseChartData data, _) {
                              final total = pieData.fold<double>(
                                0,
                                (sum, item) => sum + item.amount,
                              );
                              final percent = (data.amount / total * 100)
                                  .toStringAsFixed(0);
                              return '$percent%';
                            },
                            innerRadius: '40%',
                            radius: '80%',
                            // Selection behavior
                            selectionBehavior: SelectionBehavior(
                              enable: true,
                              unselectedOpacity: 0.5,
                            ),
                            onPointTap: (ChartPointDetails args) {
                              stfSetState(() {
                                _selectedIdx = args.pointIndex ?? -1;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(loc.cancel),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final sortedTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.fullHistory),
        // --- MODIFIED --- (Button to trigger the pie chart)
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            onPressed:
                () => _showExpenseChart(
                  context,
                  loc,
                  sortedTransactions,
                  currency,
                ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sortedTransactions.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) {
          final t = sortedTransactions[i];
          // --- MODIFIED --- (ListTile layout changed for consistency)
          final isPositive = t.amount > 0;
          final color = isPositive ? AppColors.positive : AppColors.negative;

          return ScaleFadeIn(
            delay: i * 0.02,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withAlpha(51),
                child: Icon(
                  AppCategories.getIcon(t.category),
                  color: color,
                  size: 20,
                ),
              ),
              title: Text(
                t.description?.isNotEmpty == true
                    ? t.description!
                    : loc.getCategoryDisplayName(t.category),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                intl_fmt.DateFormat(
                  'MMM dd, HH:mm',
                  loc.locale.languageCode,
                ).format(t.date),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${isPositive ? '+' : ''}${formatCurrency(t.amount.abs(), currency)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    // --- MODIFIED --- (Use compact formatter)
                    formatCurrencyCompact(t.balanceAfter, currency),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

