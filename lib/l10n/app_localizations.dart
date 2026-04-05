import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';

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
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
  ];

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @marathi.
  ///
  /// In en, this message translates to:
  /// **'Marathi'**
  String get marathi;

  /// No description provided for @thisIsHowYouAppear.
  ///
  /// In en, this message translates to:
  /// **'This is how you appear to others'**
  String get thisIsHowYouAppear;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @pauseAccount.
  ///
  /// In en, this message translates to:
  /// **'Pause Account'**
  String get pauseAccount;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// No description provided for @discovery.
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get discovery;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @travelMode.
  ///
  /// In en, this message translates to:
  /// **'Travel Mode'**
  String get travelMode;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @privacyAndSafety.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Safety'**
  String get privacyAndSafety;

  /// No description provided for @activityStatus.
  ///
  /// In en, this message translates to:
  /// **'Activity Status'**
  String get activityStatus;

  /// No description provided for @verification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get verification;

  /// No description provided for @getVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Get that verified badge'**
  String get getVerifiedBadge;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsers;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @emailUpdates.
  ///
  /// In en, this message translates to:
  /// **'Email Updates'**
  String get emailUpdates;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @communityGuidelines.
  ///
  /// In en, this message translates to:
  /// **'Community Guidelines'**
  String get communityGuidelines;

  /// No description provided for @safeDating.
  ///
  /// In en, this message translates to:
  /// **'Safe Dating'**
  String get safeDating;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @logOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logOutConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @leavingSoSoon.
  ///
  /// In en, this message translates to:
  /// **'Leaving so soon?'**
  String get leavingSoSoon;

  /// No description provided for @deleteRetentionMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?\n\nStay and get 1 WEEK OF PREMIUM FREE!'**
  String get deleteRetentionMessage;

  /// No description provided for @claimPremium.
  ///
  /// In en, this message translates to:
  /// **'Claim 1 Week Premium'**
  String get claimPremium;

  /// No description provided for @putOnHold.
  ///
  /// In en, this message translates to:
  /// **'Put Account on Hold'**
  String get putOnHold;

  /// No description provided for @deleteAnyway.
  ///
  /// In en, this message translates to:
  /// **'Delete Anyway'**
  String get deleteAnyway;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @deleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This is permanent. All data, matches and messages will be lost.'**
  String get deleteWarning;

  /// No description provided for @yesDelete.
  ///
  /// In en, this message translates to:
  /// **'Yes, Delete'**
  String get yesDelete;

  /// No description provided for @verificationRequired.
  ///
  /// In en, this message translates to:
  /// **'Verification Required'**
  String get verificationRequired;

  /// No description provided for @verificationRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'To access Matches, Likes, and Discovery, you must verify your identity first.'**
  String get verificationRequiredMessage;

  /// No description provided for @verifyNow.
  ///
  /// In en, this message translates to:
  /// **'Verify Now'**
  String get verifyNow;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'PREMIUM'**
  String get premium;

  /// No description provided for @likesYou.
  ///
  /// In en, this message translates to:
  /// **'Likes You'**
  String get likesYou;

  /// No description provided for @heartsDrifting.
  ///
  /// In en, this message translates to:
  /// **'Hearts are drifting just beyond your beam.'**
  String get heartsDrifting;

  /// No description provided for @helpNavigateConnection.
  ///
  /// In en, this message translates to:
  /// **'We can help you navigate to more connections, sooner.'**
  String get helpNavigateConnection;

  /// No description provided for @likedBack.
  ///
  /// In en, this message translates to:
  /// **'You liked them back!'**
  String get likedBack;

  /// No description provided for @noJobTitle.
  ///
  /// In en, this message translates to:
  /// **'No job title'**
  String get noJobTitle;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matches;

  /// No description provided for @signalsReachingOut.
  ///
  /// In en, this message translates to:
  /// **'Your signals are reaching out wide, but a clear return frequency is still far off.'**
  String get signalsReachingOut;

  /// No description provided for @fineTuneTransmission.
  ///
  /// In en, this message translates to:
  /// **'We can help you fine-tune your transmission and find your match soon.'**
  String get fineTuneTransmission;

  /// No description provided for @tapToChat.
  ///
  /// In en, this message translates to:
  /// **'Tap to chat'**
  String get tapToChat;

  /// No description provided for @newMessage.
  ///
  /// In en, this message translates to:
  /// **'new message'**
  String get newMessage;

  /// No description provided for @newMessages.
  ///
  /// In en, this message translates to:
  /// **'new messages'**
  String get newMessages;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybeLater;

  /// No description provided for @accessCamera.
  ///
  /// In en, this message translates to:
  /// **'Access Your Camera'**
  String get accessCamera;

  /// No description provided for @cameraDescription.
  ///
  /// In en, this message translates to:
  /// **'To verify your identity and show you\'re real, we need access to your camera for a 5-second video.'**
  String get cameraDescription;

  /// No description provided for @findPeopleNearby.
  ///
  /// In en, this message translates to:
  /// **'Find People Nearby'**
  String get findPeopleNearby;

  /// No description provided for @locationDescription.
  ///
  /// In en, this message translates to:
  /// **'We use your location to show you amazing people in your city. Your exact coordinates are never shared.'**
  String get locationDescription;

  /// No description provided for @stayConnected.
  ///
  /// In en, this message translates to:
  /// **'Stay Connected'**
  String get stayConnected;

  /// No description provided for @notificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Get notified instantly when someone likes you back or sends you a message. Don\'t miss a beat.'**
  String get notificationsDescription;

  /// No description provided for @syncContacts.
  ///
  /// In en, this message translates to:
  /// **'Sync Contacts'**
  String get syncContacts;

  /// No description provided for @contactsDescription.
  ///
  /// In en, this message translates to:
  /// **'Find friends already on Clush or ensure you don\'t run into people you already know.'**
  String get contactsDescription;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;
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
      <String>['en', 'hi', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
