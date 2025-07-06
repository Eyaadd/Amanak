import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
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
/// import 'l10n/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Amanak'**
  String get appTitle;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'Health Care App For Elder People'**
  String get appDescription;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @chooseRole.
  ///
  /// In en, this message translates to:
  /// **'Choose Role'**
  String get chooseRole;

  /// No description provided for @chooseYourRole.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Role'**
  String get chooseYourRole;

  /// No description provided for @elder.
  ///
  /// In en, this message translates to:
  /// **'Elder'**
  String get elder;

  /// No description provided for @guardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get guardian;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @assignUser.
  ///
  /// In en, this message translates to:
  /// **'Assign User'**
  String get assignUser;

  /// No description provided for @assignUserTitle.
  ///
  /// In en, this message translates to:
  /// **'As a guardian, you need to assign yourself to a user'**
  String get assignUserTitle;

  /// No description provided for @assignUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter the email of the user you want to monitor'**
  String get assignUserSubtitle;

  /// No description provided for @enterUserEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter user\'s email'**
  String get enterUserEmail;

  /// No description provided for @completeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get completeRegistration;

  /// No description provided for @noUserFound.
  ///
  /// In en, this message translates to:
  /// **'No user found with this email or the user is not a regular user'**
  String get noUserFound;

  /// No description provided for @userAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'This user is already linked to another guardian'**
  String get userAlreadyLinked;

  /// No description provided for @errorValidatingEmail.
  ///
  /// In en, this message translates to:
  /// **'Error validating user email'**
  String get errorValidatingEmail;

  /// No description provided for @pleaseEnterUserEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a user email'**
  String get pleaseEnterUserEmail;

  /// No description provided for @errorAssigningUser.
  ///
  /// In en, this message translates to:
  /// **'Error assigning user'**
  String get errorAssigningUser;

  /// No description provided for @mainAmbulance.
  ///
  /// In en, this message translates to:
  /// **'Main Ambulance'**
  String get mainAmbulance;

  /// No description provided for @trafficPolice.
  ///
  /// In en, this message translates to:
  /// **'Traffic Police'**
  String get trafficPolice;

  /// No description provided for @emergencyPolice.
  ///
  /// In en, this message translates to:
  /// **'Emergency Police'**
  String get emergencyPolice;

  /// No description provided for @fireDepartment.
  ///
  /// In en, this message translates to:
  /// **'Fire Department'**
  String get fireDepartment;

  /// No description provided for @civilDefence.
  ///
  /// In en, this message translates to:
  /// **'Civil Defence'**
  String get civilDefence;

  /// No description provided for @naturalGasEmergency.
  ///
  /// In en, this message translates to:
  /// **'Natural Gas Emergency'**
  String get naturalGasEmergency;

  /// No description provided for @waterEmergency.
  ///
  /// In en, this message translates to:
  /// **'Water Emergency'**
  String get waterEmergency;

  /// No description provided for @electricityEmergency.
  ///
  /// In en, this message translates to:
  /// **'Electricity Emergency'**
  String get electricityEmergency;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @couldNotLaunchDialer.
  ///
  /// In en, this message translates to:
  /// **'Could not launch phone dialer'**
  String get couldNotLaunchDialer;

  /// No description provided for @errorOpeningDialer.
  ///
  /// In en, this message translates to:
  /// **'Error opening phone dialer'**
  String get errorOpeningDialer;

  /// No description provided for @editField.
  ///
  /// In en, this message translates to:
  /// **'Edit {field}'**
  String editField(Object field);

  /// No description provided for @enterNewField.
  ///
  /// In en, this message translates to:
  /// **'Enter new {field}'**
  String enterNewField(Object field);

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @medicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get medicine;

  /// No description provided for @medicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get medicines;

  /// No description provided for @medicineName.
  ///
  /// In en, this message translates to:
  /// **'Medicine Name'**
  String get medicineName;

  /// No description provided for @dosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get dosage;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @addMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add Medicine'**
  String get addMedicine;

  /// No description provided for @editMedicine.
  ///
  /// In en, this message translates to:
  /// **'Edit Medicine'**
  String get editMedicine;

  /// No description provided for @deleteMedicine.
  ///
  /// In en, this message translates to:
  /// **'Delete Medicine'**
  String get deleteMedicine;

  /// No description provided for @liveTracking.
  ///
  /// In en, this message translates to:
  /// **'Live\nTracking'**
  String get liveTracking;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @guardianLocation.
  ///
  /// In en, this message translates to:
  /// **'Guardian Location'**
  String get guardianLocation;

  /// No description provided for @nearestHospitals.
  ///
  /// In en, this message translates to:
  /// **'Nearest\nHospitals'**
  String get nearestHospitals;

  /// No description provided for @chatbot.
  ///
  /// In en, this message translates to:
  /// **'Chatbot'**
  String get chatbot;

  /// No description provided for @askQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask a question...'**
  String get askQuestion;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @pillReminder.
  ///
  /// In en, this message translates to:
  /// **'Pill Reminder'**
  String get pillReminder;

  /// No description provided for @timeToTakeMedicine.
  ///
  /// In en, this message translates to:
  /// **'Time to take your medicine'**
  String get timeToTakeMedicine;

  /// No description provided for @missedPill.
  ///
  /// In en, this message translates to:
  /// **'Missed Pill'**
  String get missedPill;

  /// No description provided for @youMissedYourMedicine.
  ///
  /// In en, this message translates to:
  /// **'You missed your medicine'**
  String get youMissedYourMedicine;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotifications;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @noMedicinesForToday.
  ///
  /// In en, this message translates to:
  /// **'No medications for today'**
  String get noMedicinesForToday;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @emergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contacts'**
  String get emergencyContacts;

  /// No description provided for @editInformation.
  ///
  /// In en, this message translates to:
  /// **'Edit Information'**
  String get editInformation;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Amanak, your health companion'**
  String get welcomeMessage;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @skipOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipOnboarding;

  /// No description provided for @onboarding_finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get onboarding_finish;

  /// No description provided for @onboarding_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboarding_next;

  /// No description provided for @onboarding_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboarding_back;

  /// No description provided for @onboarding_welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome To Amanak App'**
  String get onboarding_welcome_title;

  /// No description provided for @onboarding_welcome_body.
  ///
  /// In en, this message translates to:
  /// **'Caring for your well-being, every step of the way.'**
  String get onboarding_welcome_body;

  /// No description provided for @onboarding_safety_title.
  ///
  /// In en, this message translates to:
  /// **'Stay Safe'**
  String get onboarding_safety_title;

  /// No description provided for @onboarding_safety_body.
  ///
  /// In en, this message translates to:
  /// **'Advanced Fall Detection technology alerts your loved ones when help is needed.'**
  String get onboarding_safety_body;

  /// No description provided for @onboarding_connected_title.
  ///
  /// In en, this message translates to:
  /// **'Stay Connected'**
  String get onboarding_connected_title;

  /// No description provided for @onboarding_connected_body.
  ///
  /// In en, this message translates to:
  /// **'Real-time Live Tracking to ensure you\'re always within reach.'**
  String get onboarding_connected_body;

  /// No description provided for @onboarding_organized_title.
  ///
  /// In en, this message translates to:
  /// **'Stay Organized'**
  String get onboarding_organized_title;

  /// No description provided for @onboarding_organized_body.
  ///
  /// In en, this message translates to:
  /// **'A smart Calendar to remind you of medications and appointments.'**
  String get onboarding_organized_body;

  /// No description provided for @onboarding_hassle_free_title.
  ///
  /// In en, this message translates to:
  /// **'Stay Hassle-Free'**
  String get onboarding_hassle_free_title;

  /// No description provided for @onboarding_hassle_free_body.
  ///
  /// In en, this message translates to:
  /// **'Scan medical prescriptions and let the app manage your medication reminders automatically.'**
  String get onboarding_hassle_free_body;

  /// No description provided for @chooseLanguagePrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get chooseLanguagePrompt;

  /// No description provided for @languageChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'Language changed to {language}'**
  String languageChangedMessage(Object language);

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @enterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterYourEmail;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @agreeToAmanak.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Amanak'**
  String get agreeToAmanak;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @pleaseEnterValidEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email and password'**
  String get pleaseEnterValidEmailPassword;

  /// No description provided for @chatbotGreeting.
  ///
  /// In en, this message translates to:
  /// **'How Can I Help You Today?'**
  String get chatbotGreeting;

  /// No description provided for @yourGuardian.
  ///
  /// In en, this message translates to:
  /// **'Your Guardian:'**
  String get yourGuardian;

  /// No description provided for @yourCareReceiver.
  ///
  /// In en, this message translates to:
  /// **'Your Care Receiver:'**
  String get yourCareReceiver;

  /// No description provided for @medicineSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine Search'**
  String get medicineSearchTitle;

  /// No description provided for @medicineSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for medicines...'**
  String get medicineSearchHint;

  /// No description provided for @medicineSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a medicine name to search'**
  String get medicineSearchEmpty;

  /// No description provided for @medicineSearchNotFound.
  ///
  /// In en, this message translates to:
  /// **'No medicines found'**
  String get medicineSearchNotFound;

  /// No description provided for @medicineDetailDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get medicineDetailDescription;

  /// No description provided for @medicineDetailUses.
  ///
  /// In en, this message translates to:
  /// **'Uses'**
  String get medicineDetailUses;

  /// No description provided for @medicineDetailContraindications.
  ///
  /// In en, this message translates to:
  /// **'Contraindications'**
  String get medicineDetailContraindications;

  /// No description provided for @medicineDetailPrecautions.
  ///
  /// In en, this message translates to:
  /// **'Precautions'**
  String get medicineDetailPrecautions;

  /// No description provided for @medicineDetailInteractions.
  ///
  /// In en, this message translates to:
  /// **'Interactions'**
  String get medicineDetailInteractions;

  /// No description provided for @medicineDetailDosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get medicineDetailDosage;

  /// No description provided for @medicineDetailDosageForms.
  ///
  /// In en, this message translates to:
  /// **'Dosage Forms'**
  String get medicineDetailDosageForms;

  /// No description provided for @medicineDetailStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get medicineDetailStorage;

  /// No description provided for @medicineDetailUsageInstructions.
  ///
  /// In en, this message translates to:
  /// **'Usage Instructions'**
  String get medicineDetailUsageInstructions;

  /// No description provided for @medicineDetailSideEffects.
  ///
  /// In en, this message translates to:
  /// **'Side Effects'**
  String get medicineDetailSideEffects;

  /// No description provided for @medicineDetailEnglishName.
  ///
  /// In en, this message translates to:
  /// **'English Name'**
  String get medicineDetailEnglishName;

  /// No description provided for @medicineDetailArabicName.
  ///
  /// In en, this message translates to:
  /// **'Arabic Name'**
  String get medicineDetailArabicName;

  /// No description provided for @medicineDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Medicine not found'**
  String get medicineDetailNotFound;

  /// No description provided for @medicineDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine Details'**
  String get medicineDetailTitle;

  /// No description provided for @liveTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Tracking'**
  String get liveTrackingTitle;

  /// No description provided for @yourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your Location'**
  String get yourLocation;

  /// No description provided for @trackingSharedUser.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get trackingSharedUser;

  /// No description provided for @nearestHospitalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearest Hospitals'**
  String get nearestHospitalsTitle;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get showAll;

  /// No description provided for @searchHospitals.
  ///
  /// In en, this message translates to:
  /// **'Search hospitals...'**
  String get searchHospitals;

  /// No description provided for @noHospitalsFound.
  ///
  /// In en, this message translates to:
  /// **'No hospitals found nearby'**
  String get noHospitalsFound;

  /// No description provided for @errorLoadingMedicineDetails.
  ///
  /// In en, this message translates to:
  /// **'Error loading medicine details: {error}'**
  String errorLoadingMedicineDetails(Object error);

  /// No description provided for @invalidMedicineId.
  ///
  /// In en, this message translates to:
  /// **'Invalid medicine ID'**
  String get invalidMedicineId;

  /// No description provided for @errorSearchingMedicines.
  ///
  /// In en, this message translates to:
  /// **'Error searching medicines: {error}'**
  String errorSearchingMedicines(Object error);

  /// No description provided for @errorLoadingMedicineData.
  ///
  /// In en, this message translates to:
  /// **'Error loading medicine data: {error}'**
  String errorLoadingMedicineData(Object error);
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
