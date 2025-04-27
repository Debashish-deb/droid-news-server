import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // General UI
  String get close => _t('বন্ধ করুন', 'Close');
  String get home => _t('হোম', 'Home');
  String get profile => _t('প্রোফাইল', 'Profile');
  String get editProfile => _t('প্রোফাইল সম্পাদনা', 'Edit Profile');
  String get settings => _t('সেটিংস', 'Settings');
  String get theme => _t('থিম', 'Theme');
  String get language => _t('ভাষা', 'Language');
  String get darkMode => _t('ডার্ক মোড', 'Dark Mode');
  String get version => _t('সংস্করণ', 'Version');
  String get versionPrefix => _t('সংস্করণ', 'Version');
  String get bdNewsHub => _t('বিডিনিউজ হাব 📰', 'BDNews Hub 📰');

  // Auth
  String get login => _t('লগইন', 'Login');
  String get logout => _t('লগআউট', 'Logout');
  String get signup => _t('সাইন আপ', 'Sign Up');
  String get password => _t('পাসওয়ার্ড', 'Password');
  String get email => _t('ইমেইল', 'Email');
  String get fullName => _t('পুরো নাম', 'Full Name');
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

  // Editor Features
  String get saveChanges => _t('পরিবর্তনগুলি সংরক্ষণ করুন', 'Save Changes');
  String get profileSaved => _t('প্রোফাইল সংরক্ষিত', 'Profile saved');
  String get required => _t('আবশ্যক', 'Required');

  // News Categories
  String get breakingNews => _t('ব্রেকিংনিউজ', 'Breaking News');
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
  String get technology => _t('প্রযুক্তি', 'Technology');
  String get entertainment => _t('বিনোদন', 'Entertainment');
  String get lifestyle => _t('জীবনধারা', 'LifeStyle');

  // Premium Features
  String get bangladeshTheme => _t('দেশ 🇧🇩', 'Desh 🇧🇩');
  String get adFree => _t('বিজ্ঞাপনবিহীন অভিজ্ঞতা', 'Ad-Free Experience');
  String get adFreeHint => _t('পরিষ্কার পড়ার অভিজ্ঞতার জন্য বিজ্ঞাপন সরানো হয়।', 'Removes all ads for a clean reading experience.');
  String get offlineDownloads => _t('অফলাইন ডাউনলোড', 'Offline Downloads');
  String get offlineHint => _t('অফলাইনে দেখার জন্য কনটেন্ট সংরক্ষণ করুন।', 'Save content locally for offline viewing.');
  String get prioritySupport => _t('প্রাধান্য সহায়তা', 'Priority Support');
  String get prioritySupportHint => _t('সহায়তা টিম থেকে দ্রুত সহায়তা।', 'Get faster responses from our support team.');

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
  String get catLifestyle => _t('জীবনধারা ও বিলাসিতা', 'Lifestyle & Luxury');
  String get catSports => _t('খেলা ও পারফরম্যান্স', 'Sports & Performance');

  // Feedback
  String get feedback => _t('প্রতিক্রিয়া', 'Feedback');
  String get rateApp => _t('অ্যাপ রেট দিন', 'Rate this App');
  String get contactSupport => _t('সহায়তা যোগাযোগ', 'Contact Support');
  String get contactEmail => 'customerservice@dsmobiles.com';
  String get mailClientError => _t('মেইল ক্লায়েন্ট চালু করা যায়নি।', 'Could not launch mail client.');
  String get storeOpenError => _t('স্টোর খুলতে অক্ষম।', 'Unable to open store.');
  String get viewArticle => _t('নিবন্ধ দেখুন', 'View Article');
  String get loadError => _t('লোড করতে ব্যর্থ', 'Load failed');
  String get noUserConnected => _t('কোনো ব্যবহারকারী সংযুক্ত নেই', 'No user connected yet');
  String get enterEmail => _t('ইমেইল লিখুন', 'Enter your email');
String get save => _t('সংরক্ষণ করুন', 'Save');
String get getFullProfile => _t('পূর্ণ প্রোফাইল পান', 'Get Full Profile');
  String get bangla => _t('বাংলা', 'Bengali');
  String get english => _t('ইংরেজি', 'English');
  String get supports => _t('সাপোর্ট', 'Supports');
  String get health => _t('স্বাস্থ্য', 'Health');
  String get opinion => _t('মতামত', 'Opinion');
  String get about => _t('সম্পর্কে', 'About');
  String get education => _t('শিক্ষা', 'Education');

  // Dynamic Translation Helper
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
