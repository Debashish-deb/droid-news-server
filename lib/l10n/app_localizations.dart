import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // General UI
  String get invalidEmail => _t('অবৈধ ইমেল', 'Invalid Email');
  String get close => _t('বন্ধ করুন', 'Close');
  String get home => _t('হোম', 'Home');
  String get profile => _t('প্রোফাইল', 'Profile');
  String get editProfile => _t('প্রোফাইল সম্পাদনা', 'Edit Profile');
  String get settings => _t('সেটিংস', 'Settings');
  String get theme => _t('থিম', 'Theme');
  String get language => _t('ভাষা', 'Language');
  String get darkTheme => _t('ডার্ক', 'Dark');
  String get lightTheme => _t('সিস্টেম', 'Default');
  String get deshTheme => _t('দেশ', 'Desh');
  String get version => _t('সংস্করণ', 'Version');
  String get clearCache => _t('ক্লিয়ারক্যাশ', 'Clear Cache');
  String get clearCacheSuccess => _t('ক্লিয়ারক্যাশ সাফল্য', 'Clear Cache Success');
  String get versionPrefix => _t('সংস্করণ', 'Version');
  String get bdNewsreader => _t('বিডি নিউজ রিডার 📰', 'BD News Reader 📰');
  String get otherOptions => _t('অন্যান্য বিকল্প', 'Other Options');
   

  String get paypalDonate => _t('পেপ্যাল ​​দান করুন', ' Paypal Donate');
  String get removeAds => _t('বিজ্ঞাপন সরান', 'Remove Ads');
  String get adsRemoved => _t('বিজ্ঞাপন সরানো হয়েছে', 'Ads Removed');
  
  // Auth
  String get login => _t('লগইন', 'Login');
  String get logout => _t('লগআউট', 'Logout');
  String get signup => _t('সাইন আপ', 'Sign Up');
  String get password => _t('পাসওয়ার্ড', 'Password');
  String get email => _t('ইমেইল', 'Email');
  String get search => _t('অনুসন্ধান করুন ', 'Search');
  String get help => _t('সাহায্য', 'Help');
  String get appTitle => _t('বিডি নিউজ রিডার', 'BD News Reader');
  String get fullName => _t('পুরো নাম', 'Full Name');
  String get name => _t('নাম', 'Name');
  String get enterName => _t('নাম লিখুন','Enter Name');
  String get save => _t('সংরক্ষণ করুন', 'Save');
  String get enterEmail => _t('ইমেল লিখুন', 'Enter Email'); 
  String get forgotPassword => _t('পাসওয়ার্ড ভুলে গেছেন', 'Forgot Password');
  String get sendResetLink => _t('রিসেট লিঙ্ক পাঠান', 'Send Reset Link');
  String get enterEmailReset => _t('পাসওয়ার্ড রিসেট করতে আপনার ইমেল লিখুন:', 'Enter your email to reset your password:');
  String get alreadyHaveAccount => _t('ইতিমধ্যে একটি অ্যাকাউন্ট আছে?', 'Already have an account? Login');
  String get createAccount => _t('অ্যাকাউন্ট তৈরি করুন', 'Create account');
  String get invalidCredentials => _t('ভুল ইমেইল বা পাসওয়ার্ড।', 'Invalid email or password.');
  String get noAccountFound => _t('এই ইমেইলে কোন অ্যাকাউন্ট নেই।', 'No account found for this email.');
  String get accountExists => _t('এই ইমেইলে ইতিমধ্যে অ্যাকাউন্ট আছে।', 'An account already exists with this email.');
  String get resetEmailSent => _t('📧 পাসওয়ার্ড রিসেট ইমেইল পাঠানো হয়েছে!', '📧 Password reset email sent!');

  // Profile Fields
  String get phone => _t('ফোন', 'Phone');
  String get bio => _t('জীবন বৃত্তান্ত', 'Bio');
  String get address => _t('ঠিকানা', 'Address');
  String get website => _t('ওয়েবসাইট', 'Website');
  String get role => _t('ভূমিকা', 'Role');
  String get department => _t('বিভাগ', 'Department');
  String get changeImage => _t('ছবি পরিবর্তন করুন', 'Change Image');
  String get removeImage => _t('ছবি অপসারণ', 'Remove Image');
  String get noUserConnected => _t('কোনো ব্যবহারকারী সংযুক্ত নেই', 'No user connected yet');
  String get scrollController => _t('স্ক্রোল কন্ট্রোলার', 'Scroll Controller');
 
  String get saveChanges => _t('পরিবর্তনগুলি সংরক্ষণ করুন', 'Save Changes');
  String get profileSaved => _t('প্রোফাইল সংরক্ষিত', 'Profile saved');
  String get required => _t('আবশ্যক', 'Required');
  String get details => _t('বিস্তারিত', 'Details');
  String get dailyQuiz => _t('দৈনিক কুইজ', 'Daily Quiz');
  String get notAnswered => _t('উত্তর দেওয়া হয়নি', 'Not Answered');
  String get lookup => _t('অনুসন্ধান', 'Lookup');
  String get tryAgain => _t('আবার চেষ্টা করুন', 'Try Again');
  String get quizSummary => _t('কুইজের সারাংশ', 'Quiz Summary');
 
  String get finish => _t('সমাপ্ত', 'Finish');
  String get correct => _t('সঠিক', 'Correct');
  String get yourAnswer => _t('আপনার উত্তর', 'Your Answer');
  String get highScore => _t('সর্বোচ্চ স্কোর', 'High Score');
  String get streak => _t('ধারা', 'Streak');
  String get recentSearches => _t('সাম্প্রতিক অনুসন্ধানগুলি', 'Recent Searches');
  
  String get latest => _t('সর্বশেষ', 'latest');
  String get quiz => _t('কুইজ', 'Quiz');
  String get newspapers => _t('সংবাদপত্র', 'Newspapers');
  String get magazines => _t('ম্যাগাজিন', 'Magazines');
  String get favorites => _t('প্রিয়', 'Favorites');
  String get national => _t('জাতীয়', 'National');
  String get international => _t('আন্তর্জাতিক', 'International');
  String get businessFinance => _t('ব্যবসা ও অর্থনীতি', 'Business & Finance');
  String get digitalTech => _t('ডিজিটাল ও প্রযুক্তি', 'Digital & Technology');
  String get sportsNews => _t('খেলার খবর', 'Sports News');
  String get entertainmentArts => _t('বিনোদন ও শিল্প', 'Entertainment & Arts');
  String get worldPolitics => _t('বিশ্ব ও রাজনীতি', 'World & Politics');
  String get blog => _t('ব্লগ', 'Blog');
  String get business => _t('ব্যবসা', 'Business');
  String get sports => _t('খেলা', 'Sports');
  String get satire => _t('হাস্যরস', 'Satire');
  String get technology => _t('প্রযুক্তি', 'Technology');
  String get entertainment => _t('বিনোদন', 'Entertainment');
  String get lifestyle => _t('জীবনধারা', 'LifeStyle');
  String get translateTooltip      => _t('অনুবাদ করুন', 'Translate');
  String get alwaysTranslateLabel  => _t('সবসময় বাংলায় অনুবাদ করুন', 'Always translate to Bengali');
  String get increaseFontSize      => _t('লেখা বড় করুন', 'Increase font size');
  String get toggleDarkMode        => _t('ডার্ক মোড চালু/বন্ধ', 'Toggle dark mode');
  String get readerMode            => _t('রিডার মোড চালু/বন্ধ', 'Toggle reader mode');
  String get mobileView            => _t('মোবাইল-বন্ধুসুলভ মোড', 'Mobile-friendly view');
  String get desktopView           => _t('মূল ডেস্কটপ মোড', 'Original desktop view');
  String get tryAmp                => _t('দ্রুত AMP সংস্করণ ব্যবহার করুন', 'Try AMP version');
  String get originalView          => _t('মূল সংস্করণ দেখুন', 'Switch to original version');
  String get sharePage             => _t('পৃষ্ঠা শেয়ার করুন', 'Share this page');
  String get bookmarkPage          => _t('পৃষ্ঠা বুকমার্ক করুন', 'Bookmark this page');
  String get bookmarkSuccess       => _t('সফলভাবে সংরক্ষণ করা হয়েছে!', 'URL saved successfully!');
    // Premium Features
  String get bangladeshTheme => _t('দেশ 🇧🇩', 'Desh 🇧🇩');
  String get adFree => _t('বিজ্ঞাপনবিহীন অভিজ্ঞতা', 'Ad-Free Experience');
  String get adFreeHint => _t('পরিষ্কার পড়ার অভিজ্ঞতার জন্য বিজ্ঞাপন সরানো হয়।', 'Removes all ads for a clean reading experience.');
  String get offlineDownloads => _t('অফলাইন ডাউনলোড', 'Offline Downloads');
  String get offlineHint => _t('অফলাইনে দেখার জন্য কনটেন্ট সংরক্ষণ করুন।', 'Save content locally for offline viewing.');
  String get prioritySupport => _t('প্রাধান্য সহায়তা', 'Priority Support');
  String get prioritySupportHint => _t('সহায়তা টিম থেকে দ্রুত সহায়তা।', 'Get faster responses from our support team.');

  String get back => _t('পিছনে যান', 'Go back');
  String get forward => _t('সামনে যান', 'Go forward');
  String get refresh => _t('রিফ্রেশ করুন', 'Refresh');
  String get translate => _t('অনুবাদ করা', 'Translate');
  String get share => _t('শেয়ার করুন', 'Share');
  String get bookmark => _t('বুকমার্ক', 'Bookmark');
  String get moreOptions => _t('আরও বিকল্প', 'More Options');
  String get darkMode => _t('ডার্ক মোড', 'Dark Mode');
  String get productNotAvailable => _t('পণ্য উপলব্ধ নয়', 'Product Not Available');
    // Search and Empty States
  String get searchHint => _t('সন্ধান করুন...', 'Search...');
  String get searchPapers => _t('পত্রিকা খুঁজুন…', 'Search…');
  String get noMagazines => _t('কোন ম্যাগাজিন পাওয়া যায়নি', 'No magazines found');
  String get noPapersFound => _t('কোন সংবাদপত্র পাওয়া যায়নি', 'No papers found');
  String get allLanguages => _t('সব ভাষা', 'All Languages');

  // Categories for Magazines
  String get catFashion => _t('ফ্যাশন ও সৌন্দর্য', 'Fashion & Aesthetics');
  String get catScience => _t('বিজ্ঞান ও আবিষ্কার', 'Science & Discovery');
  String get catFinance => _t('অর্থনীতি ও অর্থ', 'Economics & Finance');
  String get catAffairs => _t('আন্তর্জাতিক সম্পর্ক', 'Global Affairs');
  String get catTech => _t('প্রযুক্তি', 'Emerging Technologies');
  String get catArts => _t('শিল্প ও মানবিকতা', 'Arts & Humanities');
  String get misc => _t('অন্যান্য', 'Miscellaneous');
  String get catLifestyle => _t('জীবনধারা ও বিলাসিতা', 'Lifestyle & Luxury');
  String get catSports => _t('খেলা ও পারফরম্যান্স', 'Sports & Performance');
  String get games => _t('খেলা', 'Games');
  // Feedback
  String get feedback => _t('প্রতিক্রিয়া', 'Feedback');
  String get rateApp => _t('অ্যাপ রেট দিন', 'Rate this App');
  String get contactSupport => _t('সহায়তা যোগাযোগ', 'Contact Support');
  String get contactEmail => 'customerservice@dsmobiles.com';
  String get mailClientError => _t('মেইল ক্লায়েন্ট চালু করা যায়নি।', 'Could not launch mail client.');
  String get storeOpenError => _t('স্টোর খুলতে অক্ষম।', 'Unable to open store.');
  String get viewArticle => _t('নিবন্ধ দেখুন', 'View Article');
  String get loadError => _t('লোড করতে ব্যর্থ', 'Load failed');
  String get getStarted => _t('শুরু করুন', 'Get Started');
  String get next => _t('পরবর্তী', 'Next');
  String get fastReliable => _t('দ্রুত এবং নির্ভরযোগ্য', 'Fast & Reliable');
  String get personalizedExperience => _t('ব্যক্তিগত অভিজ্ঞতা', 'Personalized Experience');
  String get favoriteArticles=> _t('প্রিয় প্রবন্ধ', 'Favorite Articles');
  String get favoriteMagazines => _t('প্রিয় ম্যাগাজিন', 'Favorite Magazines');
  String get favoriteNewspapers => _t('প্রিয় সংবাদপত্র', 'Favorite Newspapers');
  String get noFavoritesYet => _t('কোনও প্রিয় নেই', 'No Favorites Yet');
  String get continueWithGoogle => _t('গুগলের সাথে চালিয়ে যান', 'Continue With Google');
  String get articles => _t('প্রবন্ধ', 'articles');
  String get noArticlesFound => _t('কোন নিবন্ধ পাওয়া যায়নি', 'No Articles Found');
  String get bangla => _t('বাংলা', 'Bengali');
  String get english => _t('ইংরেজি', 'English');
  String get supports => _t('সাপোর্ট', 'Supports');
  String get health => _t('স্বাস্থ্য', 'Health');
  String get opinion => _t('মতামত', 'Opinion');
  String get about => _t('সম্পর্কে', 'About');
  String get education => _t('শিক্ষা', 'Education');
  String get loading => _t('লোডিং', 'Loading');
  String get guest => _t('অতিথি', 'Guest');

  String get errorLoadingProfile => _t('ত্রুটিপ্রোফাইল লোড হচ্ছে', 'Error Loading Profile');

  String? get googlePay => null;

  String? get paypalError => null;

  String? get paypalCard => null;

  get topicLabel => null;
  // Translation Helper
  String _t(String bn, String en) => locale.languageCode == 'bn' ? bn : en;
}
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'bn'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
