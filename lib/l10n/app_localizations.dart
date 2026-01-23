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
    Locale('bn'),
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

  /// No description provided for @offlineReading.
  ///
  /// In en, this message translates to:
  /// **'Offline Reading'**
  String get offlineReading;

  /// No description provided for @offlineHint.
  ///
  /// In en, this message translates to:
  /// **'Save content locally for offline viewing.'**
  String get offlineHint;

  /// No description provided for @offlineShowingCached.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing cached news'**
  String get offlineShowingCached;

  /// No description provided for @checkBackLater.
  ///
  /// In en, this message translates to:
  /// **'Check back later for the latest updates.'**
  String get checkBackLater;

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

  /// No description provided for @latestNewsUpdates.
  ///
  /// In en, this message translates to:
  /// **'Latest news and updates'**
  String get latestNewsUpdates;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated;

  /// No description provided for @storiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} stories'**
  String storiesCount(int count);

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
  /// **'Sports'**
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

  /// No description provided for @bookmarkSuccess.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked Successfully'**
  String get bookmarkSuccess;

  /// No description provided for @readerMode.
  ///
  /// In en, this message translates to:
  /// **'Reader Mode'**
  String get readerMode;

  /// No description provided for @articles.
  ///
  /// In en, this message translates to:
  /// **'Articles'**
  String get articles;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No Favorites Yet'**
  String get noFavoritesYet;

  /// No description provided for @bdNewsreader.
  ///
  /// In en, this message translates to:
  /// **'BD News Reader'**
  String get bdNewsreader;

  /// No description provided for @noArticlesFound.
  ///
  /// In en, this message translates to:
  /// **'No Articles Found'**
  String get noArticlesFound;

  /// No description provided for @catFashion.
  ///
  /// In en, this message translates to:
  /// **'Fashion'**
  String get catFashion;

  /// No description provided for @noMagazines.
  ///
  /// In en, this message translates to:
  /// **'No Magazines'**
  String get noMagazines;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @supports.
  ///
  /// In en, this message translates to:
  /// **'Supports'**
  String get supports;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @productNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Product Not Available'**
  String get productNotAvailable;

  /// No description provided for @clearCacheSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cache Cleared Successfully'**
  String get clearCacheSuccess;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light Theme'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get darkTheme;

  /// No description provided for @bangladeshTheme.
  ///
  /// In en, this message translates to:
  /// **'Desh Theme'**
  String get bangladeshTheme;

  /// No description provided for @adsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Ads Removed'**
  String get adsRemoved;

  /// No description provided for @removeAds.
  ///
  /// In en, this message translates to:
  /// **'Remove Ads'**
  String get removeAds;

  /// No description provided for @paypalDonate.
  ///
  /// In en, this message translates to:
  /// **'Donate by Paypal'**
  String get paypalDonate;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Hint'**
  String get searchHint;

  /// No description provided for @dailyQuiz.
  ///
  /// In en, this message translates to:
  /// **'Daily Quiz'**
  String get dailyQuiz;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @highScore.
  ///
  /// In en, this message translates to:
  /// **'HighScore'**
  String get highScore;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue With Google'**
  String get continueWithGoogle;

  /// No description provided for @quizSummary.
  ///
  /// In en, this message translates to:
  /// **'Quiz Summary'**
  String get quizSummary;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @fastReliable.
  ///
  /// In en, this message translates to:
  /// **'Fast & Reliable'**
  String get fastReliable;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @catScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get catScience;

  /// No description provided for @catFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get catFinance;

  /// No description provided for @catAffairs.
  ///
  /// In en, this message translates to:
  /// **'World Affairs'**
  String get catAffairs;

  /// No description provided for @catTech.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get catTech;

  /// No description provided for @catArts.
  ///
  /// In en, this message translates to:
  /// **'Arts'**
  String get catArts;

  /// No description provided for @catLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get catLifestyle;

  /// No description provided for @catSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get catSports;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get loadFailed;

  /// No description provided for @pressBackToExit.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get pressBackToExit;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @replaceFirst.
  ///
  /// In en, this message translates to:
  /// **'Replace First'**
  String get replaceFirst;

  /// No description provided for @personalizedExperience.
  ///
  /// In en, this message translates to:
  /// **'Personalized Experience'**
  String get personalizedExperience;

  /// No description provided for @extras.
  ///
  /// In en, this message translates to:
  /// **'Extras'**
  String get extras;

  /// No description provided for @currentLanguage.
  ///
  /// In en, this message translates to:
  /// **'Current Language'**
  String get currentLanguage;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @excellentScore.
  ///
  /// In en, this message translates to:
  /// **'Excellent Score!'**
  String get excellentScore;

  /// No description provided for @goodScore.
  ///
  /// In en, this message translates to:
  /// **'Good Job!'**
  String get goodScore;

  /// No description provided for @keepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Keep Practicing!'**
  String get keepPracticing;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @chooseCorrect.
  ///
  /// In en, this message translates to:
  /// **'Choose the correct answer'**
  String get chooseCorrect;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No Data Available'**
  String get noData;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @exploreFeatures.
  ///
  /// In en, this message translates to:
  /// **'Explore Features'**
  String get exploreFeatures;

  /// No description provided for @onThisDay.
  ///
  /// In en, this message translates to:
  /// **'OnThisDay...'**
  String get onThisDay;

  /// No description provided for @onThisDayDesc.
  ///
  /// In en, this message translates to:
  /// **'Historical events, birthdays & inventions'**
  String get onThisDayDesc;

  /// No description provided for @brainBuzz.
  ///
  /// In en, this message translates to:
  /// **'BrainBuzz'**
  String get brainBuzz;

  /// No description provided for @dataSaver.
  ///
  /// In en, this message translates to:
  /// **'Data Saver'**
  String get dataSaver;

  /// No description provided for @dataSaverDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduce image quality and background syncing'**
  String get dataSaverDesc;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Breaking news alerts'**
  String get pushNotificationsDesc;

  /// No description provided for @privacyData.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data'**
  String get privacyData;

  /// No description provided for @privacyDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your data and privacy'**
  String get privacyDataDesc;

  /// No description provided for @premiumFeature.
  ///
  /// In en, this message translates to:
  /// **'Premium Feature'**
  String get premiumFeature;

  /// No description provided for @premiumFeatureDesc.
  ///
  /// In en, this message translates to:
  /// **'{feature} is available for Premium users only.'**
  String premiumFeatureDesc(String feature);

  /// No description provided for @goPremium.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get goPremium;

  /// No description provided for @brainBuzzDesc.
  ///
  /// In en, this message translates to:
  /// **'Test your knowledge with daily trivia'**
  String get brainBuzzDesc;

  /// No description provided for @snakeCircuit.
  ///
  /// In en, this message translates to:
  /// **'Snake Circuit'**
  String get snakeCircuit;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @faqHowToUse.
  ///
  /// In en, this message translates to:
  /// **'How to use BD News Reader?'**
  String get faqHowToUse;

  /// No description provided for @faqHowToUseDesc.
  ///
  /// In en, this message translates to:
  /// **'Navigate news categories from the homepage.'**
  String get faqHowToUseDesc;

  /// No description provided for @faqDataSecure.
  ///
  /// In en, this message translates to:
  /// **'Is my data secure?'**
  String get faqDataSecure;

  /// No description provided for @faqDataSecureDesc.
  ///
  /// In en, this message translates to:
  /// **'Yes, we respect your privacy and do not store personal data.'**
  String get faqDataSecureDesc;

  /// No description provided for @faqUpdates.
  ///
  /// In en, this message translates to:
  /// **'How to get latest updates?'**
  String get faqUpdates;

  /// No description provided for @faqUpdatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Updates are pushed automatically via Play Store.'**
  String get faqUpdatesDesc;

  /// No description provided for @visitWebsite.
  ///
  /// In en, this message translates to:
  /// **'Visit Website'**
  String get visitWebsite;

  /// No description provided for @helpInquiry.
  ///
  /// In en, this message translates to:
  /// **'Help & Support Inquiry'**
  String get helpInquiry;

  /// No description provided for @ourStoryDesc.
  ///
  /// In en, this message translates to:
  /// **'BD News Reader is the first mobile app by DSMobiles Group, delivering fast and reliable news updates. Our mission is to create free, high-quality apps that inform and empower.'**
  String get ourStoryDesc;

  /// No description provided for @ourVisionDesc.
  ///
  /// In en, this message translates to:
  /// **'We envision a world where information is free and universal. Through user-first design and innovative tools, we aim to create digital experiences that inspire.'**
  String get ourVisionDesc;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String copiedToClipboard(String label);

  /// No description provided for @emailError.
  ///
  /// In en, this message translates to:
  /// **'Could not open email app.'**
  String get emailError;

  /// No description provided for @snakeCircuitDesc.
  ///
  /// In en, this message translates to:
  /// **'Classic 90s reimagined'**
  String get snakeCircuitDesc;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get recentSearches;

  /// No description provided for @noMatchFound.
  ///
  /// In en, this message translates to:
  /// **'No match found for \"{query}\"'**
  String noMatchFound(String query);

  /// No description provided for @allSources.
  ///
  /// In en, this message translates to:
  /// **'All Sources'**
  String get allSources;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleLabel;

  /// No description provided for @departmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get departmentLabel;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterName;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name required'**
  String get nameRequired;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdated;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @logoutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirmation;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicyDesc.
  ///
  /// In en, this message translates to:
  /// **'Read how we handle your data'**
  String get privacyPolicyDesc;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @termsOfServiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Read our terms and conditions'**
  String get termsOfServiceDesc;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Your Data'**
  String get exportData;

  /// No description provided for @exportDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Download all your data (GDPR right)'**
  String get exportDataDesc;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all your data'**
  String get deleteAccountDesc;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountConfirmation;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete:\n\n• Your account\n• All favorites and history\n• All preferences\n• All synced data\n\nThis action cannot be undone.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteEverything.
  ///
  /// In en, this message translates to:
  /// **'Delete Everything'**
  String get deleteEverything;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully'**
  String get accountDeleted;

  /// No description provided for @dataExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Data Export'**
  String get dataExportTitle;

  /// No description provided for @dataExportComplete.
  ///
  /// In en, this message translates to:
  /// **'Data export complete'**
  String get dataExportComplete;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @openUrlError.
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get openUrlError;

  /// No description provided for @exportError.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportError(String error);

  /// No description provided for @deleteError.
  ///
  /// In en, this message translates to:
  /// **'Deletion failed: {error}'**
  String deleteError(String error);

  /// No description provided for @moreFeaturesComingSoon.
  ///
  /// In en, this message translates to:
  /// **'More features coming soon'**
  String get moreFeaturesComingSoon;

  /// No description provided for @whatWeCollect.
  ///
  /// In en, this message translates to:
  /// **'What We Collect'**
  String get whatWeCollect;

  /// No description provided for @whatWeCollectDetails.
  ///
  /// In en, this message translates to:
  /// **'• Email and name (if signed in)\\n• Reading preferences and favorites\\n• App usage statistics\\n• Crash and performance data\\n• Device information'**
  String get whatWeCollectDetails;

  /// No description provided for @yourRights.
  ///
  /// In en, this message translates to:
  /// **'Your Rights'**
  String get yourRights;

  /// No description provided for @yourRightsDetails.
  ///
  /// In en, this message translates to:
  /// **'✓ Right to access your data\\n✓ Right to export your data\\n✓ Right to delete your data\\n✓ Right to opt-out of analytics\\n✓ Right to be forgotten'**
  String get yourRightsDetails;
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
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
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
