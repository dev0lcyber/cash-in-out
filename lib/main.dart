import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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

  // Unique IDs for the two daily notifications
  static const int morningNotificationId = 1001;
  static const int eveningNotificationId = 1002;
  static const String channelId = 'daily_motivation_channel';
  static const String channelName = 'Daily Motivation';
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

  Future<void> scheduleDailyNotifications(AppLocalizations loc) async {
    await flutterLocalNotificationsPlugin.cancelAll(); // Cancel old schedules
    await requestPermissions(); // Request permission before scheduling

    final List<Map<String, String>> morningNotifs = [
      {'title': loc.notif1Title, 'body': loc.notif1Body},
      {'title': loc.notif2Title, 'body': loc.notif2Body},
      {'title': loc.notif3Title, 'body': loc.notif3Body},
      {'title': loc.notif4Title, 'body': loc.notif4Body},
      {'title': loc.notif5Title, 'body': loc.notif5Body},
      {'title': loc.notif6Title, 'body': loc.notif6Body},
      {'title': loc.notif7Title, 'body': loc.notif7Body},
    ];

    final List<Map<String, String>> eveningNotifs = [
      {'title': loc.notif8Title, 'body': loc.notif8Body},
      {'title': loc.notif9Title, 'body': loc.notif9Body},
      {'title': loc.notif10Title, 'body': loc.notif10Body},
      {'title': loc.notif11Title, 'body': loc.notif11Body},
      {'title': loc.notif12Title, 'body': loc.notif12Body},
      {'title': loc.notif13Title, 'body': loc.notif13Body},
      {'title': loc.notif14Title, 'body': loc.notif14Body},
    ];

    final random = math.Random();

    // Choose randomized messages
    final morningChoice = morningNotifs[random.nextInt(morningNotifs.length)];
    final eveningChoice = eveningNotifs[random.nextInt(eveningNotifs.length)];

    // Android-specific channel details
    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher', // Use the icon you set up in AndroidManifest
    );

    const NotificationDetails platformChannelDetails = NotificationDetails(
      android: androidDetails,
    );

    // 1. Schedule Morning Notification (~9:00 AM)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      morningNotificationId, // ID
      morningChoice['title'],
      morningChoice['body'],
      _nextInstanceOfTime(9, 0), // Next 9:00 AM in user's timezone
      platformChannelDetails,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle, // Fire even in Doze mode
      matchDateTimeComponents:
          DateTimeComponents.time, // Repeat daily at 9:00 AM
    );

    // 2. Schedule Evening Notification (~8:00 PM)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      eveningNotificationId, // ID
      eveningChoice['title'],
      eveningChoice['body'],
      _nextInstanceOfTime(20, 00), // Next 8:00 PM (20:00) in user's timezone

      platformChannelDetails,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle, // Fire even in Doze mode
      matchDateTimeComponents:
          DateTimeComponents.time, // Repeat daily at 8:00 PM
    );

    debugPrint(
      "Scheduled notifications in ${loc.locale.languageCode}: Morning & Evening",
    );
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
  static const Color primary = Color(0xFF0A7E8C); // Deep Teal
  static const Color accent = Color(0xFFFF6B35); // Vibrant Orange
  static const Color lightBg = Color(0xFFF5F7FA);
  static const Color darkBg = Color(0xFF0D1B2A);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1B263B);
  static const Color positive = Color(0xFF4CAF50);
  static const Color negative = Color(0xFFF44336);
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
      // --- NOTIFICATION STRINGS ---
      'notif1Title': 'Start your cash flow strong 💪',
      'notif1Body': 'Add your first transaction and stay ahead today.',
      'notif2Title': 'Good morning, money mover ☀️',
      'notif2Body': 'Log what’s coming in — small wins build big stacks.',
      'notif3Title': 'Every dirham counts 💸',
      'notif3Body': 'Record your spending now before it disappears.',
      'notif4Title': 'New day, same goal: grow your wallet',
      'notif4Body': 'Open CashInOut and add today’s moves.',
      'notif5Title': 'Don’t let your money wander',
      'notif5Body': 'Track it before it forgets who owns it.',
      'notif6Title': 'Tap in before you cash out',
      'notif6Body': 'Quick log = clear mind. Let’s do this.',
      'notif7Title': 'Your budget’s waiting ⏱️',
      'notif7Body': 'Update your numbers and rule your finances today.',
      'notif8Title': 'Your wallet told me it’s tired',
      'notif8Body': 'Review your spending before tomorrow surprises you.',
      'notif9Title': 'End strong, saver 🧾',
      'notif9Body': 'Check today’s totals — progress happens nightly.',
      'notif10Title': 'You vs. yesterday',
      'notif10Body': 'Spent less? Spent more? Tap to see your stats.',
      'notif11Title': 'Dinner cost hit hard? 🍕',
      'notif11Body': 'Update your spending and face the truth gently.',
      'notif12Title': 'Track. Reflect. Chill.',
      'notif12Body': 'A minute here saves confusion later.',
      'notif13Title': 'Your cash day is closing',
      'notif13Body': 'Let’s log the final numbers — no loose ends.',
      'notif14Title': 'Daily balance check ✅',
      'notif14Body':
          'Tap to see what your wallet did while you weren’t looking.',
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
      'builtWithLove': 'Cette application a été créée avec amour et passion',
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
      // --- NOTIFICATION STRINGS ---
      'notif1Title': 'Commencez fort votre flux de trésorerie 💪',
      'notif1Body':
          'Ajoutez votre première transaction pour rester en tête aujourd\'hui.',
      'notif2Title': 'Bonjour, gestionnaire d\'argent ☀️',
      'notif2Body':
          'Enregistrez vos revenus — les petites victoires font les grandes réussites.',
      'notif3Title': 'Chaque dirham compte 💸',
      'notif3Body':
          'Enregistrez vos dépenses maintenant avant qu\'elles ne disparaissent.',
      'notif4Title':
          'Nouveau jour, même objectif : faites grandir votre portefeuille',
      'notif4Body':
          'Ouvrez CashInOut et ajoutez les mouvements d\'aujourd\'hui.',
      'notif5Title': 'Ne laissez pas votre argent s\'égarer',
      'notif5Body': 'Suivez-le avant qu\'il n\'oublie à qui il appartient.',
      'notif6Title': 'Enregistrez avant de dépenser',
      'notif6Body': 'Un enregistrement rapide = un esprit clair. C\'est parti.',
      'notif7Title': 'Votre budget vous attend ⏱️',
      'notif7Body':
          'Mettez à jour vos chiffres et maîtrisez vos finances aujourd\'hui.',
      'notif8Title': 'Votre portefeuille m\'a dit qu\'il est fatigué',
      'notif8Body':
          'Passez en revue vos dépenses avant que demain ne vous surprenne.',
      'notif9Title': 'Terminez en force, épargnant 🧾',
      'notif9Body':
          'Vérifiez les totaux du jour — les progrès se font chaque nuit.',
      'notif10Title': 'Vous contre hier',
      'notif10Body':
          'Moins dépensé ? Plus dépensé ? Touchez pour voir vos stats.',
      'notif11Title': 'Le dîner a coûté cher ? 🍕',
      'notif11Body':
          'Mettez à jour vos dépenses et affrontez la vérité en douceur.',
      'notif12Title': 'Suivre. Réfléchir. Détendez-vous.',
      'notif12Body': 'Une minute ici vous évite la confusion plus tard.',
      'notif13Title': 'Votre journée d\'argent se termine',
      'notif13Body':
          'Enregistrons les derniers chiffres — pas de détails oubliés.',
      'notif14Title': 'Vérification quotidienne du solde ✅',
      'notif14Body':
          'Touchez pour voir ce que votre portefeuille a fait à votre insu.',
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
      'github': 'جيت هب',
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
      // --- NOTIFICATION STRINGS ---
      'notif1Title': 'ابدأ تدفقك المالي بقوة 💪',
      'notif1Body': 'أضف أول معاملة لك وابقَ متقدماً اليوم.',
      'notif2Title': 'صباح الخير، يا محرك المال ☀️',
      'notif2Body': 'سجل ما يدخل - الإنجازات الصغيرة تبني أرصدة كبيرة.',
      'notif3Title': 'كل درهم مهم 💸',
      'notif3Body': 'سجل مصروفاتك الآن قبل أن تختفي.',
      'notif4Title': 'يوم جديد، نفس الهدف: تنمية محفظتك',
      'notif4Body': 'افتح CashInOut وأضف تحركات اليوم.',
      'notif5Title': 'لا تدع أموالك تتجول',
      'notif5Body': 'تتبعها قبل أن تنسى من يملكها.',
      'notif6Title': 'سجل قبل أن تصرف',
      'notif6Body': 'تسجيل سريع = ذهن صافي. لنفعلها.',
      'notif7Title': 'ميزانيتك تنتظرك ⏱️',
      'notif7Body': 'حدث أرقامك وتحكم في أموالك اليوم.',
      'notif8Title': 'محفظتك أخبرتني أنها متعبة',
      'notif8Body': 'راجع إنفاقك قبل أن يفاجئك الغد.',
      'notif9Title': 'اختتم بقوة، يا مدخر 🧾',
      'notif9Body': 'تحقق من إجمالي اليوم - التقدم يحدث ليلاً.',
      'notif10Title': 'أنت مقابل الأمس',
      'notif10Body': 'أنفقت أقل؟ أنفقت أكثر؟ اضغط لترى إحصائياتك.',
      'notif11Title': 'هل أثرت تكلفة العشاء بشدة؟ 🍕',
      'notif11Body': 'حدث إنفاقك وواجه الحقيقة بلطف.',
      'notif12Title': 'تتبع. فكر. استرخ.',
      'notif12Body': 'دقيقة هنا توفر عليك الارتباك لاحقاً.',
      'notif13Title': 'يومك المالي يقترب من النهاية',
      'notif13Body': 'لنسجل الأرقام النهائية - لا نترك أي شيء ناقصاً.',
      'notif14Title': 'تحقق من الرصيد اليومي ✅',
      'notif14Body': 'اضغط لترى ما فعلته محفظتك وأنت لا تنظر.',
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

  // Notification Getters
  String get notif1Title =>
      _localizedValues[locale.languageCode]!['notif1Title']!;
  String get notif1Body =>
      _localizedValues[locale.languageCode]!['notif1Body']!;
  String get notif2Title =>
      _localizedValues[locale.languageCode]!['notif2Title']!;
  String get notif2Body =>
      _localizedValues[locale.languageCode]!['notif2Body']!;
  String get notif3Title =>
      _localizedValues[locale.languageCode]!['notif3Title']!;
  String get notif3Body =>
      _localizedValues[locale.languageCode]!['notif3Body']!;
  String get notif4Title =>
      _localizedValues[locale.languageCode]!['notif4Title']!;
  String get notif4Body =>
      _localizedValues[locale.languageCode]!['notif4Body']!;
  String get notif5Title =>
      _localizedValues[locale.languageCode]!['notif5Title']!;
  String get notif5Body =>
      _localizedValues[locale.languageCode]!['notif5Body']!;
  String get notif6Title =>
      _localizedValues[locale.languageCode]!['notif6Title']!;
  String get notif6Body =>
      _localizedValues[locale.languageCode]!['notif6Body']!;
  String get notif7Title =>
      _localizedValues[locale.languageCode]!['notif7Title']!;
  String get notif7Body =>
      _localizedValues[locale.languageCode]!['notif7Body']!;
  String get notif8Title =>
      _localizedValues[locale.languageCode]!['notif8Title']!;
  String get notif8Body =>
      _localizedValues[locale.languageCode]!['notif8Body']!;
  String get notif9Title =>
      _localizedValues[locale.languageCode]!['notif9Title']!;
  String get notif9Body =>
      _localizedValues[locale.languageCode]!['notif9Body']!;
  String get notif10Title =>
      _localizedValues[locale.languageCode]!['notif10Title']!;
  String get notif10Body =>
      _localizedValues[locale.languageCode]!['notif10Body']!;
  String get notif11Title =>
      _localizedValues[locale.languageCode]!['notif11Title']!;
  String get notif11Body =>
      _localizedValues[locale.languageCode]!['notif11Body']!;
  String get notif12Title =>
      _localizedValues[locale.languageCode]!['notif12Title']!;
  String get notif12Body =>
      _localizedValues[locale.languageCode]!['notif12Body']!;
  String get notif13Title =>
      _localizedValues[locale.languageCode]!['notif13Title']!;
  String get notif13Body =>
      _localizedValues[locale.languageCode]!['notif13Body']!;
  String get notif14Title =>
      _localizedValues[locale.languageCode]!['notif14Title']!;
  String get notif14Body =>
      _localizedValues[locale.languageCode]!['notif14Body']!;
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
          // The service now handles localization based on the context's locale
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
              ? GoogleFonts.cairo().fontFamily
              : GoogleFonts.poppins().fontFamily,
      textTheme:
          isArabic
              ? GoogleFonts.cairoTextTheme()
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
class ChartData {
  final List<FlSpot> spots;
  final List<DateTime> periods;

  ChartData(this.spots, this.periods);
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

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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

  ChartData _getChartData() {
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
      startDate = DateTime(now.year, now.month - 11, 1);
    }

    final List<DateTime> relevantPeriods = [];

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

    List<FlSpot> spots = [];
    List<DateTime> periodsWithData = [];

    for (final p in relevantPeriods) {
      final net = nets[p] ?? 0.0;
      if (net != 0.0) {
        spots.add(FlSpot(periodsWithData.length.toDouble(), net));
        periodsWithData.add(p);
      }
    }

    if (spots.isEmpty) {
      spots.add(const FlSpot(0, 0));
      periodsWithData.add(DateTime.now());
    }

    return ChartData(spots, periodsWithData);
  }

  List<LineTooltipItem?> _getTooltipItems(List<LineBarSpot> touchedSpots) {
    return touchedSpots.map((LineBarSpot touchedSpot) {
      final textStyle = TextStyle(
        color: touchedSpot.y >= 0 ? AppColors.positive : AppColors.negative,
        fontWeight: FontWeight.bold,
      );
      return LineTooltipItem(
        formatCurrency(touchedSpot.y, currency ?? ''),
        textStyle,
      );
    }).toList();
  }

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
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
                                            formatCurrency(value, currency!),
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
                                child: Builder(
                                  builder: (context) {
                                    final chartData = _getChartData();
                                    var spots = chartData.spots;

                                    double minY = 0;
                                    double maxY = 0;
                                    if (spots.isNotEmpty) {
                                      minY = spots
                                          .map((s) => s.y)
                                          .reduce(math.min);
                                      maxY = spots
                                          .map((s) => s.y)
                                          .reduce(math.max);
                                    }

                                    double delta = (maxY - minY) * 0.1;
                                    if (delta == 0) {
                                      delta = 10;
                                    }
                                    minY = math.min(0, minY - delta);
                                    maxY = math.max(0, maxY + delta);

                                    final double zeroPercent =
                                        (0 - minY) / (maxY - minY);
                                    final cleanZeroPercent = zeroPercent.clamp(
                                      0.0,
                                      1.0,
                                    );

                                    return LineChart(
                                      LineChartData(
                                        minY: minY,
                                        maxY: maxY,
                                        gridData: FlGridData(
                                          show: true,
                                          drawVerticalLine: false,
                                          getDrawingHorizontalLine:
                                              (v) => FlLine(
                                                color: Colors.grey.withAlpha(
                                                  51,
                                                ), // FIX: withOpacity(0.2)
                                                strokeWidth: 1,
                                              ),
                                        ),
                                        titlesData: FlTitlesData(
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 50,
                                              getTitlesWidget:
                                                  (v, m) => Text(
                                                    v.toStringAsFixed(0),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color:
                                                          theme
                                                              .textTheme
                                                              .bodyMedium!
                                                              .color,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              interval: 1.0,
                                              getTitlesWidget: (v, m) {
                                                final idx = v.toInt();

                                                if (idx < 0 ||
                                                    idx >=
                                                        chartData
                                                            .periods
                                                            .length) {
                                                  return const SizedBox();
                                                }

                                                final d =
                                                    chartData.periods[idx];
                                                String label;

                                                if (period ==
                                                    ChartPeriod.week) {
                                                  label = intl_fmt.DateFormat(
                                                    'EEE',
                                                    loc.locale.languageCode,
                                                  ).format(d);
                                                } else if (period ==
                                                    ChartPeriod.month) {
                                                  label = d.day.toString();
                                                } else {
                                                  // ChartPeriod.year
                                                  label = intl_fmt.DateFormat(
                                                    'MMM',
                                                    loc.locale.languageCode,
                                                  ).format(d);
                                                }

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8.0,
                                                      ),
                                                  child: Text(
                                                    label,
                                                    style:
                                                        theme
                                                            .textTheme
                                                            .labelSmall,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          topTitles: const AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                          rightTitles: const AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                        ),
                                        borderData: FlBorderData(show: false),
                                        lineTouchData: LineTouchData(
                                          handleBuiltInTouches: true,
                                          touchTooltipData:
                                              LineTouchTooltipData(
                                                getTooltipColor:
                                                    (LineBarSpot touchedSpot) =>
                                                        theme.cardColor
                                                            .withAlpha(230),
                                                getTooltipItems:
                                                    _getTooltipItems,
                                              ),
                                        ),
                                        lineBarsData: [
                                          LineChartBarData(
                                            spots: spots,
                                            isCurved: true,
                                            barWidth: 3,
                                            isStrokeCapRound: true,
                                            dotData: FlDotData(show: false),
                                            color: AppColors.primary,
                                            belowBarData: BarAreaData(
                                              show: true,
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  AppColors.positive.withAlpha(
                                                    77,
                                                  ), // FIX: withOpacity(0.3)
                                                  AppColors.positive.withAlpha(
                                                    77,
                                                  ), // FIX: withOpacity(0.3)
                                                  AppColors.negative.withAlpha(
                                                    77,
                                                  ), // FIX: withOpacity(0.3)
                                                  AppColors.negative.withAlpha(
                                                    77,
                                                  ), // FIX: withOpacity(0.3)
                                                ],
                                                stops: [
                                                  0.0,
                                                  cleanZeroPercent,
                                                  cleanZeroPercent,
                                                  1.0,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
                                onPressed: _exportCsv,
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
                                        return ScaleFadeIn(
                                          delay: i * 0.05,
                                          child: ListTile(
                                            leading: Icon(
                                              t.amount > 0
                                                  ? Icons.trending_up
                                                  : Icons.trending_down,
                                              color:
                                                  t.amount > 0
                                                      ? AppColors.positive
                                                      : AppColors.negative,
                                            ),
                                            title: Text(
                                              '${t.amount > 0 ? '+' : ''}${formatCurrency(t.amount.abs(), currency!)}',
                                            ),
                                            subtitle: Text(
                                              intl_fmt.DateFormat(
                                                'MMM dd, HH:mm',
                                                loc.locale.languageCode,
                                              ).format(t.date),
                                            ),
                                            trailing: Text(
                                              formatCurrency(
                                                t.balanceAfter,
                                                currency!,
                                              ),
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

  Future<void> _modifyBalance(bool add) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final loc = AppLocalizations.of(context);

    final result = await showDialog<double>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(add ? loc.addIncome : loc.addExpense),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: ctrl,
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.cancel),
              ),
              ElevatedButton(
                onPressed:
                    () =>
                        formKey.currentState!.validate()
                            ? Navigator.pop(ctx, double.parse(ctrl.text))
                            : null,
                child: Text(loc.save),
              ),
            ],
          ),
    );

    if (result == null) return;

    setState(() {
      balance = (balance ?? 0) + (add ? result : -result);
      transactions.add(
        Transaction(
          amount: add ? result : -result,
          date: DateTime.now(),
          balanceAfter: balance!,
        ),
      );
      _saveAll();
    });
  }

  Future<void> _exportCsv() async {
    final buffer = StringBuffer()..writeln('Date,Amount,Balance');
    for (final t in transactions) {
      buffer.writeln(
        '${intl_fmt.DateFormat('MMM dd, HH:mm').format(t.date)},${t.amount},${t.balanceAfter}',
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
                    Text(
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
      if (!ctx.mounted) return;
      _restartApp();
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
      if (!ctx.mounted) return;
      _restartApp();
    }
  }

  Future<void> _resetData(BuildContext ctx) async {
    final loc = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: ctx,
      builder:
          (_) => AlertDialog(
            title: Text(loc.reset),
            content: const Text(
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
                formatCurrency(value, currency),
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

class Transaction {
  final double amount;
  final DateTime date;
  final double balanceAfter;
  Transaction({
    required this.amount,
    required this.date,
    required this.balanceAfter,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    amount: json['amount'] as double,
    date: DateTime.parse(json['date'] as String),
    balanceAfter: json['balanceAfter'] as double,
  );

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'date': date.toIso8601String(),
    'balanceAfter': balanceAfter,
  };
}

class HistoryPage extends StatelessWidget {
  final List<Transaction> transactions;
  final String currency;
  const HistoryPage({
    required this.transactions,
    required this.currency,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final sortedTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: Text(loc.fullHistory)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sortedTransactions.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, i) {
          final t = sortedTransactions[i];
          return ScaleFadeIn(
            delay: i * 0.02,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    t.amount > 0
                        ? AppColors.positive.withAlpha(
                          51,
                        ) // FIX: withOpacity(0.2)
                        : AppColors.negative.withAlpha(
                          51,
                        ), // FIX: withOpacity(0.2)
                child: Icon(
                  t.amount > 0 ? Icons.add : Icons.remove,
                  color: t.amount > 0 ? AppColors.positive : AppColors.negative,
                ),
              ),
              title: Text(
                '${t.amount > 0 ? '+' : ''}${formatCurrency(t.amount.abs(), currency)}',
              ),
              subtitle: Text(
                intl_fmt.DateFormat(
                  'MMM dd, HH:mm',
                  loc.locale.languageCode,
                ).format(t.date),
              ),
              trailing: Text(
                formatCurrency(t.balanceAfter, currency),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        },
      ),
    );
  }
}
