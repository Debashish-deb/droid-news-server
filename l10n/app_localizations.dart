import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en')
  ];

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @misc.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get misc;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// No description provided for @adFree.
  ///
  /// In en, this message translates to:
  /// **'Ad-Free Experience'**
  String get adFree;

  /// No description provided for @adFreeHint.
  ///
  /// In en, this message translates to:
  /// **'Removes all ads for a clean reading experience.'**
  String get adFreeHint;

  /// No description provided for @offlineDownloads.
  ///
  /// In en, this message translates to:
  /// **'Offline Downloads'**
  String get offlineDownloads;

  /// No description provided for @offlineHint.
  ///
  /// In en, this message translates to:
  /// **'Save content locally for offline viewing.'**
  String get offlineHint;

  /// No description provided for @prioritySupport.
  ///
  /// In en, this message translates to:
  /// **'Priority Support'**
  String get prioritySupport;

  /// No description provided for @prioritySupportHint.
  ///
  /// In en, this message translates to:
  /// **'Get faster responses from our support team.'**
  String get prioritySupportHint;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate this App'**
  String get rateApp;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'customerservice@dsmobiles.com'**
  String get contactEmail;

  /// No description provided for @mailClientError.
  ///
  /// In en, this message translates to:
  /// **'Could not launch mail client.'**
  String get mailClientError;

  /// No description provided for @storeOpenError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open store.'**
  String get storeOpenError;

  /// No description provided for @bdNewsHub.
  ///
  /// In en, this message translates to:
  /// **'BDNews Hub 📰'**
  String get bdNewsHub;

  /// No description provided for @viewArticle.
  ///
  /// In en, this message translates to:
  /// **'View Article'**
  String get viewArticle;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @national.
  ///
  /// In en, this message translates to:
  /// **'National'**
  String get national;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @business.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get business;

  /// No description provided for @technology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get technology;

  /// No description provided for @sports.
  ///
  /// In en, this message translates to:
  /// **'Sports & Performance'**
  String get sports;

  /// No description provided for @entertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get entertainment;

  /// No description provided for @noImage.
  ///
  /// In en, this message translates to:
  /// **'No Image'**
  String get noImage;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

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

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove Image'**
  String get removeImage;

  /// No description provided for @changeImage.
  ///
  /// In en, this message translates to:
  /// **'Change Image'**
  String get changeImage;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get alreadyHaveAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @resetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'📧 Password reset email sent!'**
  String get resetEmailSent;

  /// No description provided for @enterEmailReset.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to reset your password:'**
  String get enterEmailReset;

  /// No description provided for @accountExists.
  ///
  /// In en, this message translates to:
  /// **'Account already exists. Please log in.'**
  String get accountExists;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get invalidCredentials;

  /// No description provided for @noAccountFound.
  ///
  /// In en, this message translates to:
  /// **'No account found. Please sign up first.'**
  String get noAccountFound;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @aboutUs.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get aboutUs;

  /// No description provided for @ourStory.
  ///
  /// In en, this message translates to:
  /// **'Our Story'**
  String get ourStory;

  /// No description provided for @ourVision.
  ///
  /// In en, this message translates to:
  /// **'Our Vision'**
  String get ourVision;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @copySuccess.
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String copySuccess(Object label);

  /// No description provided for @appSlogan.
  ///
  /// In en, this message translates to:
  /// **'Real-time News at Your Fingertips'**
  String get appSlogan;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'BDNewspaper'**
  String get appName;

  /// No description provided for @versionPrefix.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionPrefix;

  /// No description provided for @companyFooter.
  ///
  /// In en, this message translates to:
  /// **'© {year} DreamSD Group'**
  String companyFooter(Object year);

  /// No description provided for @magazines.
  ///
  /// In en, this message translates to:
  /// **'Magazines'**
  String get magazines;

  /// No description provided for @searchMagazines.
  ///
  /// In en, this message translates to:
  /// **'Search magazines...'**
  String get searchMagazines;

  /// No description provided for @noMagazinesFound.
  ///
  /// In en, this message translates to:
  /// **'No magazines found'**
  String get noMagazinesFound;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @fashion.
  ///
  /// In en, this message translates to:
  /// **'Fashion & Aesthetics'**
  String get fashion;

  /// No description provided for @science.
  ///
  /// In en, this message translates to:
  /// **'Science & Discovery'**
  String get science;

  /// No description provided for @finance.
  ///
  /// In en, this message translates to:
  /// **'Economics & Finance'**
  String get finance;

  /// No description provided for @global.
  ///
  /// In en, this message translates to:
  /// **'Global Affairs'**
  String get global;

  /// No description provided for @arts.
  ///
  /// In en, this message translates to:
  /// **'Arts & Humanities'**
  String get arts;

  /// No description provided for @lifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle & Luxury'**
  String get lifestyle;

  /// No description provided for @noWebsite.
  ///
  /// In en, this message translates to:
  /// **'No website available for this magazine'**
  String get noWebsite;

  /// No description provided for @failedToOpenWebsite.
  ///
  /// In en, this message translates to:
  /// **'Failed to open website'**
  String get failedToOpenWebsite;

  /// No description provided for @unknownMagazine.
  ///
  /// In en, this message translates to:
  /// **'Unknown Magazine'**
  String get unknownMagazine;

  /// No description provided for @unknownCountry.
  ///
  /// In en, this message translates to:
  /// **'Unknown Country'**
  String get unknownCountry;

  /// No description provided for @unknownLanguage.
  ///
  /// In en, this message translates to:
  /// **'Unknown Language'**
  String get unknownLanguage;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @catSatire.
  ///
  /// In en, this message translates to:
  /// **'Satire'**
  String get catSatire;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Load error: {message}'**
  String loadError(Object message);

  /// No description provided for @newspapers.
  ///
  /// In en, this message translates to:
  /// **'Newspapers'**
  String get newspapers;

  /// No description provided for @searchPapers.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchPapers;

  /// No description provided for @noPapersFound.
  ///
  /// In en, this message translates to:
  /// **'No papers found'**
  String get noPapersFound;

  /// No description provided for @international.
  ///
  /// In en, this message translates to:
  /// **'International'**
  String get international;

  /// No description provided for @businessFinance.
  ///
  /// In en, this message translates to:
  /// **'Business & Finance'**
  String get businessFinance;

  /// No description provided for @digitalTech.
  ///
  /// In en, this message translates to:
  /// **'Digital & Technology'**
  String get digitalTech;

  /// No description provided for @sportsNews.
  ///
  /// In en, this message translates to:
  /// **'Sports News'**
  String get sportsNews;

  /// No description provided for @entertainmentArts.
  ///
  /// In en, this message translates to:
  /// **'Entertainment & Arts'**
  String get entertainmentArts;

  /// No description provided for @worldPolitics.
  ///
  /// In en, this message translates to:
  /// **'World & Politics'**
  String get worldPolitics;

  /// No description provided for @blog.
  ///
  /// In en, this message translates to:
  /// **'Blog'**
  String get blog;

  /// No description provided for @allLanguages.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allLanguages;

  /// No description provided for @bangla.
  ///
  /// In en, this message translates to:
  /// **'Bangla'**
  String get bangla;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @unknownNewspaper.
  ///
  /// In en, this message translates to:
  /// **'Unknown Newspaper'**
  String get unknownNewspaper;

  /// No description provided for @noWebsiteNewspaper.
  ///
  /// In en, this message translates to:
  /// **'No website available for this newspaper'**
  String get noWebsiteNewspaper;

  /// No description provided for @shareNews.
  ///
  /// In en, this message translates to:
  /// **'Share News'**
  String get shareNews;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn': return AppLocalizationsBn();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
