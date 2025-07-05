// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Amanak';

  @override
  String get appDescription => 'Health Care App For Elder People';

  @override
  String get login => 'Login';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get signUp => 'Sign Up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get chooseRole => 'Choose Role';

  @override
  String get chooseYourRole => 'Choose Your Role';

  @override
  String get elder => 'Elder';

  @override
  String get guardian => 'Guardian';

  @override
  String get user => 'User';

  @override
  String get assignUser => 'Assign User';

  @override
  String get assignUserTitle =>
      'As a guardian, you need to assign yourself to a user';

  @override
  String get assignUserSubtitle =>
      'Please enter the email of the user you want to monitor';

  @override
  String get enterUserEmail => 'Enter user\'s email';

  @override
  String get completeRegistration => 'Complete Registration';

  @override
  String get noUserFound =>
      'No user found with this email or the user is not a regular user';

  @override
  String get userAlreadyLinked =>
      'This user is already linked to another guardian';

  @override
  String get errorValidatingEmail => 'Error validating user email';

  @override
  String get pleaseEnterUserEmail => 'Please enter a user email';

  @override
  String get errorAssigningUser => 'Error assigning user';

  @override
  String get mainAmbulance => 'Main Ambulance';

  @override
  String get trafficPolice => 'Traffic Police';

  @override
  String get emergencyPolice => 'Emergency Police';

  @override
  String get fireDepartment => 'Fire Department';

  @override
  String get civilDefence => 'Civil Defence';

  @override
  String get naturalGasEmergency => 'Natural Gas Emergency';

  @override
  String get waterEmergency => 'Water Emergency';

  @override
  String get electricityEmergency => 'Electricity Emergency';

  @override
  String get goBack => 'Go Back';

  @override
  String get couldNotLaunchDialer => 'Could not launch phone dialer';

  @override
  String get errorOpeningDialer => 'Error opening phone dialer';

  @override
  String editField(Object field) {
    return 'Edit $field';
  }

  @override
  String enterNewField(Object field) {
    return 'Enter new $field';
  }

  @override
  String get home => 'Home';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get logout => 'Logout';

  @override
  String get search => 'Search';

  @override
  String get notifications => 'Notifications';

  @override
  String get messages => 'Messages';

  @override
  String get calendar => 'Calendar';

  @override
  String get medicine => 'Medicine';

  @override
  String get medicines => 'Medicines';

  @override
  String get medicineName => 'Medicine Name';

  @override
  String get dosage => 'Dosage';

  @override
  String get frequency => 'Frequency';

  @override
  String get time => 'Time';

  @override
  String get addMedicine => 'Add Medicine';

  @override
  String get editMedicine => 'Edit Medicine';

  @override
  String get deleteMedicine => 'Delete Medicine';

  @override
  String get liveTracking => 'Live\nTracking';

  @override
  String get location => 'Location';

  @override
  String get guardianLocation => 'Guardian Location';

  @override
  String get nearestHospitals => 'Nearest\nHospitals';

  @override
  String get chatbot => 'Chatbot';

  @override
  String get askQuestion => 'Ask a question...';

  @override
  String get send => 'Send';

  @override
  String get pillReminder => 'Pill Reminder';

  @override
  String get timeToTakeMedicine => 'Time to take your medicine';

  @override
  String get missedPill => 'Missed Pill';

  @override
  String get youMissedYourMedicine => 'You missed your medicine';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get theme => 'Theme';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get ok => 'OK';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String get done => 'Done';

  @override
  String get skip => 'Skip';

  @override
  String get continueButton => 'Continue';

  @override
  String get seeAll => 'See all';

  @override
  String get noMedicinesForToday => 'No medications for today';

  @override
  String get today => 'Today';

  @override
  String get emergencyContacts => 'Emergency Contacts';

  @override
  String get editInformation => 'Edit Information';

  @override
  String get welcome => 'Welcome';

  @override
  String get welcomeMessage => 'Welcome to Amanak, your health companion';

  @override
  String get getStarted => 'Get Started';

  @override
  String get skipOnboarding => 'Skip';

  @override
  String get onboarding_finish => 'Finish';

  @override
  String get onboarding_next => 'Next';

  @override
  String get onboarding_back => 'Back';

  @override
  String get onboarding_welcome_title => 'Welcome To Amanak App';

  @override
  String get onboarding_welcome_body =>
      'Caring for your well-being, every step of the way.';

  @override
  String get onboarding_safety_title => 'Stay Safe';

  @override
  String get onboarding_safety_body =>
      'Advanced Fall Detection technology alerts your loved ones when help is needed.';

  @override
  String get onboarding_connected_title => 'Stay Connected';

  @override
  String get onboarding_connected_body =>
      'Real-time Live Tracking to ensure you\'re always within reach.';

  @override
  String get onboarding_organized_title => 'Stay Organized';

  @override
  String get onboarding_organized_body =>
      'A smart Calendar to remind you of medications and appointments.';

  @override
  String get onboarding_hassle_free_title => 'Stay Hassle-Free';

  @override
  String get onboarding_hassle_free_body =>
      'Scan medical prescriptions and let the app manage your medication reminders automatically.';

  @override
  String get chooseLanguagePrompt => 'Choose Language';

  @override
  String languageChangedMessage(Object language) {
    return 'Language changed to $language';
  }

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get enterYourEmail => 'Enter your email';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get agreeToAmanak => 'I agree to the Amanak';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get and => 'and';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get pleaseEnterValidEmailPassword =>
      'Please enter a valid email and password';

  @override
  String get chatbotGreeting => 'How Can I Help You Today?';

  @override
  String get yourGuardian => 'Your Guardian:';

  @override
  String get yourCareReceiver => 'Your Care Receiver:';

  @override
  String get medicineSearchTitle => 'Medicine Search';

  @override
  String get medicineSearchHint => 'Search for medicines...';

  @override
  String get medicineSearchEmpty => 'Enter a medicine name to search';

  @override
  String get medicineSearchNotFound => 'No medicines found';

  @override
  String get medicineDetailDescription => 'Description';

  @override
  String get medicineDetailUses => 'Uses';

  @override
  String get medicineDetailContraindications => 'Contraindications';

  @override
  String get medicineDetailPrecautions => 'Precautions';

  @override
  String get medicineDetailInteractions => 'Interactions';

  @override
  String get medicineDetailDosage => 'Dosage';

  @override
  String get medicineDetailDosageForms => 'Dosage Forms';

  @override
  String get medicineDetailStorage => 'Storage';

  @override
  String get medicineDetailUsageInstructions => 'Usage Instructions';

  @override
  String get medicineDetailSideEffects => 'Side Effects';

  @override
  String get medicineDetailEnglishName => 'English Name';

  @override
  String get medicineDetailArabicName => 'Arabic Name';

  @override
  String get medicineDetailNotFound => 'Medicine not found';

  @override
  String get medicineDetailTitle => 'Medicine Details';

  @override
  String get liveTrackingTitle => 'Live Tracking';

  @override
  String get yourLocation => 'Your Location';

  @override
  String get trackingSharedUser => 'Tracking';

  @override
  String get nearestHospitalsTitle => 'Nearest Hospitals';

  @override
  String get showAll => 'Show All';

  @override
  String get searchHospitals => 'Search hospitals...';

  @override
  String get noHospitalsFound => 'No hospitals found nearby';
}
