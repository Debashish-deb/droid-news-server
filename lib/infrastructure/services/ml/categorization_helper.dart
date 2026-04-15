// lib/infrastructure/services/ml/categorization_helper.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'enhanced_ai_categorizer.dart';

/// Result of categorization with confidence score
class CategorizationResult {
  const CategorizationResult({
    required this.category,
    required this.confidence,
    required this.source, // 'keyword', 'pattern', 'ai'
    this.reason = '',
  });

  final String category;
  final double confidence; // 0.0 to 1.0
  final String source;
  final String reason;

  bool get isHighConfidence => confidence >= 0.7;
  bool get isMediumConfidence => confidence >= 0.55;
  bool get isLowConfidence => confidence < 0.55;

  CategorizationResult copyWith({
    String? category,
    double? confidence,
    String? source,
    String? reason,
  }) {
    return CategorizationResult(
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      reason: reason ?? this.reason,
    );
  }

  @override
  String toString() =>
      'Category: $category (${(confidence * 100).toStringAsFixed(0)}% via $source)';
}

/// Helper class for intelligent news categorization
class CategorizationHelper {
  // Prevent instantiation
  CategorizationHelper._();

  static const String _tag = '🎯 Categorizer';
  static const int _maxAiKnowledgeSamples = 500;
  static const Set<String> _aiKnowledgeHomeFeedCategories = {
    'home',
    'latest',
    'general',
    'all',
    'mixed',
  };
  static final List<Map<String, dynamic>> _aiKnowledgeSamples =
      <Map<String, dynamic>>[];

  static final RegExp _alphanumericPtn = RegExp(r'^[a-z0-9\s]+$');
  static final Map<String, RegExp> _regexCache = {};
  static const int _maxCacheSize = 500;

  // ============================================================
  //  STRONG KEYWORDS  (high-signal, primary decision drivers)
  // ============================================================

  static const Map<String, List<String>> _strongKeywords = {
    // ----------------------------------------------------------
    //  SPORTS
    // ----------------------------------------------------------
    'sports': [
      // ── Disciplines ──────────────────────────────────────────
      'cricket', 'ক্রিকেট', 'ক্রীড়া', 'খেলাধুলা', 'খেলা',
      'football', 'ফুটবল', 'soccer', 'সকার',
      'hockey', 'হকি', 'field hockey',
      'badminton', 'ব্যাডমিন্টন',
      'tennis', 'টেনিস',
      'kabaddi', 'কাবাডি',
      'volleyball', 'ভলিবল',
      'athletics', 'অ্যাথলেটিক্স',
      'swimming', 'সাঁতার',
      'wrestling', 'কুস্তি',
      'boxing', 'বক্সিং',
      'archery', 'তীরন্দাজি',
      'cycling', 'সাইক্লিং',
      'golf', 'গলফ',
      'basketball', 'বাস্কেটবল',
      'chess', 'দাবা',
      'shooting', 'শুটিং',
      'weightlifting', 'ভারোত্তোলন',
      'judo', 'কারাতে', 'karate', 'taekwondo',
      'handball', 'হ্যান্ডবল',
      'polo', 'equestrian',

      // ── Cricket-specific ─────────────────────────────────────
      'test match', 'test cricket', 'odi', 'one day international',
      't20', 'টি-টোয়েন্টি', 'টি২০', 't20i',
      'innings', 'ইনিংস',
      'wicket', 'উইকেট', 'wickets',
      'runs', 'রান',
      'century', 'সেঞ্চুরি', 'শতরান',
      'half-century', 'ফিফটি',
      'over', 'ওভার',
      'bowled', 'bowling', 'বোলিং',
      'batting', 'ব্যাটিং',
      'fielding', 'ফিল্ডিং',
      'spinner', 'স্পিনার',
      'pacer', 'পেসার',
      'batsman', 'ব্যাটসম্যান', 'ব্যাটার', 'batter',
      'bowler', 'বোলার',
      'all-rounder', 'অলরাউন্ডার',
      'wicketkeeper', 'উইকেটরক্ষক',
      'lbw', 'caught', 'run out',
      'no-ball', 'wide', 'extras',
      'drs', 'review',
      'powerplay', 'death over',
      'duck', 'golden duck',
      'hat-trick', 'হ্যাটট্রিক',
      'test series', 'odi series', 't20 series',
      'cricket board', 'bcb', 'bcci', 'icc', 'ecb', 'ca', 'pcb', 'zc',
      'bangladesh cricket board',
      'national cricket team',

      // ── Football/Soccer-specific ─────────────────────────────
      'goal', 'গোল', 'goals',
      'penalty', 'পেনাল্টি', 'penalty shootout',
      'red card', 'yellow card',
      'offside', 'foul',
      'corner kick', 'free kick',
      'clean sheet',
      'hat trick',
      'dribble', 'assist',

      // ── Tournaments & Leagues ────────────────────────────────
      'bpl', 'bangladesh premier league',
      'ipl', 'indian premier league',
      'psl', 'pakistan super league',
      'cpl', 'caribbean premier league',
      'bbl', 'big bash',
      'fifa', 'উয়েফা', 'uefa',
      'la liga', 'লা লিগা',
      'serie a', 'সেরিয়া এ',
      'bundesliga', 'বুন্দেসলিগা',
      'ligue 1',
      'premier league', 'english premier league', 'epl',
      'champions league', 'চ্যাম্পিয়নস লিগ',
      'europa league',
      'world cup', 'বিশ্বকাপ',
      'asia cup', 'এশিয়া কাপ',
      'champions trophy',
      'test championship', 'wtc',
      'afcon', 'copa america',
      'olympics', 'অলিম্পিক', 'olympic games',
      'asian games', 'এশিয়ান গেমস',
      'commonwealth games', 'কমনওয়েলথ গেমস',
      'south asian games', 'sag',
      'federation cup',
      'saff', 'saff championship',
      'bangabandhu cup',
      'gulf cup',
      'sudirman cup', 'thomas cup', 'uber cup',
      'davis cup',
      'grand slam', 'wimbledon', 'us open', 'french open', 'australian open',

      // ── Notable Players / Coaches ────────────────────────────
      'shakib', 'শাকিব আল হাসান', 'shakib al hasan',
      'tamim', 'তামিম ইকবাল', 'tamim iqbal',
      'mushfiq', 'মুশফিকুর রহিম', 'mushfiqur rahim',
      'mahmudullah', 'মাহমুদউল্লাহ',
      'liton das', 'লিটন দাস',
      'najmul', 'নাজমুল হোসেন শান্ত',
      'mehidy', 'মেহেদী হাসান মিরাজ',
      'taskin', 'তাসকিন আহমেদ',
      'mustafizur', 'মুস্তাফিজুর রহমান',
      'shoriful', 'শরিফুল',
      'nasum', 'নাসুম আহমেদ',
      'ebadot', 'এবাদত হোসেন',
      'towhid ridoy', 'তৌহিদ হৃদয়',
      'messi', 'লিওনেল মেসি',
      'ronaldo', 'ক্রিস্টিয়ানো রোনালদো',
      'mbappé', 'mbappe', 'এমবাপ্পে',
      'neymar', 'নেইমার',
      'haaland', 'হালান্ড',
      'kohli', 'বিরাট কোহলি',
      'rohit sharma', 'রোহিত শর্মা',
      'bumrah', 'বুমরাহ',
      'babar azam', 'বাবর আজম',
      'kane williamson',
      'steve smith',
      'ben stokes',
      'joe root',
      'rahim sterling', 'salah',
      'federer', 'djokovic', 'nadal', 'alcaraz',
      'serena williams', 'iga swiatek',

      // ── Venue / Organization terms ───────────────────────────
      'stadium', 'স্টেডিয়াম',
      'cricket ground', 'ক্রিকেট মাঠ',
      'mirpur', 'মিরপুর', // Sher-e-Bangla Stadium
      'sher-e-bangla', 'শেরেবাংলা',
      'national stadium',
      'match', 'ম্যাচ',
      'tournament', 'টুর্নামেন্ট',
      'league', 'লীগ', 'লিগ',
      'final', 'ফাইনাল',
      'semi-final', 'সেমিফাইনাল',
      'quarterfinal', 'কোয়ার্টার ফাইনাল',
      'coach', 'কোচ', 'head coach',
      'captain', 'অধিনায়ক', 'skipper',
      'selector', 'নির্বাচক',
      'team', 'ক্রীড়া দল',
      'player', 'খেলোয়াড়',
      'umpire', 'আম্পায়ার',
      'referee', 'রেফারি',
      'score', 'স্কোর',
      'scorecard', 'স্কোরকার্ড',
      'squad', 'স্কোয়াড',
      'playing xi', 'একাদশ',
      'transfer', 'ট্রান্সফার',
      'signing', 'সাইনিং',
      'sports minister', 'ক্রীড়ামন্ত্রী',
      'sports federation', 'ক্রীড়া ফেডারেশন',
    ],

    // ----------------------------------------------------------
    //  ENTERTAINMENT
    // ----------------------------------------------------------
    'entertainment': [
      // ── Core labels ──────────────────────────────────────────
      'entertainment', 'বিনোদন',
      'showbiz', 'শোবিজ', 'শো-বিজ',
      'celebrity', 'celebrities', 'তারকা', 'তারকারা',
      'celeb', 'celebs',
      'সেলিব্রিটি',

      // ── Film ─────────────────────────────────────────────────
      'movie', 'movies',
      'film', 'films', 'চলচ্চিত্র',
      'cinema', 'সিনেমা',
      'picture', 'ছবি',
      'dhallywood', 'ঢালিউড',
      'tollywood', 'টলিউড',
      'bollywood', 'বলিউড',
      'hollywood',
      'kollywood',
      'korean drama', 'kdrama', 'k-drama',
      'anime',
      'director', 'পরিচালক', 'পরিচালিকা',
      'actor', 'অভিনেতা',
      'actress', 'অভিনেত্রী',
      'hero', 'নায়ক',
      'heroine', 'নায়িকা',
      'villain',
      'casting',
      'screenplay', 'script',
      'box office',
      'trailer', 'ট্রেলার',
      'teaser', 'টিজার',
      'release', 'মুক্তি', 'রিলিজ',
      'premiere', 'প্রিমিয়ার',
      'special screening',
      'censor board',
      'box office collection',
      'film festival', 'চলচ্চিত্র উৎসব',

      // ── Television / Streaming ───────────────────────────────
      'drama', 'নাটক',
      'serial', 'সিরিয়াল',
      'web series', 'ওয়েব সিরিজ',
      'series',
      'tv show', 'টিভি শো',
      'reality show', 'রিয়েলিটি শো',
      'talk show', 'টক শো',
      'sitcom',
      'netflix', 'নেটফ্লিক্স',
      'amazon prime', 'প্রাইম ভিডিও',
      'disney+', 'disney plus', 'হটস্টার', 'hotstar',
      'hbo', 'hbo max',
      'apple tv',
      'hulu',
      'ott', 'ওটিটি',
      'hoichoi',
      'chorki', 'চোরকি',
      'binge', 'bongo',
      'toffee', 'টফি',
      'bioscope',
      'zee5',
      'jiocinema',
      'sony liv',
      'streaming platform',
      'episode', 'এপিসোড',
      'season', 'সিজন',
      'finale',

      // ── Music ────────────────────────────────────────────────
      'music', 'গান', 'সংগীত', 'সঙ্গীত',
      'song',
      'album', 'অ্যালবাম',
      'single',
      'music video',
      'concert', 'কনসার্ট',
      'singer', 'গায়ক', 'গায়িকা', 'শিল্পী',
      'band', 'ব্যান্ড',
      'rapper', 'rap',
      'musician', 'সঙ্গীতশিল্পী',
      'pop star',
      'k-pop', 'কে-পপ',
      'bts',
      'taylor swift',
      'ed sheeran',
      'ariana grande',
      'beyonce', 'beyoncé',
      'eminem',
      'youtube music',
      'spotify',
      'lyrics',
      'chart', 'billboard',

      // ── Awards ───────────────────────────────────────────────
      'oscar', 'oscars', 'academy awards',
      'grammy', 'grammys', 'grammy awards',
      'emmy', 'emmys',
      'bafta',
      'golden globe', 'golden globes',
      'national film awards', 'জাতীয় চলচ্চিত্র পুরস্কার',
      'bangladesh national film award',
      'meril-prothom alo', 'মেরিল-প্রথম আলো',
      'bachsas award',

      // ── BD Entertainment Figures ─────────────────────────────
      'shakib khan', 'শাকিব খান',
      'apu biswas', 'অপু বিশ্বাস',
      'porimoni', 'পরীমনি',
      'jaya ahsan', 'জয়া আহসান',
      'mosharraf karim', 'মোশাররফ করিম',
      'chanchal chowdhury', 'চঞ্চল চৌধুরী',
      'afran nisho', 'আফরান নিশো',
      'mehazabien', 'মেহজাবীন',
      'tasnia farin', 'তাসনিয়া ফারিন',
      'mim', 'বিদ্যা সিনহা মিম', 'bidya sinha mim',
      'nusraat faria', 'নুসরাত ফারিয়া',
      'dipjol', 'দীপজল',
      'manna', 'মান্না',
      'ilias kanchan', 'ইলিয়াস কাঞ্চন',
      'razzak', 'রাজ্জাক',
      'ferdous', 'ফেরদৌস',
      'riaz', 'রিয়াজ',
      'bapparaj', 'বাপ্পারাজ',
      'habib wahid', 'হাবিব ওয়াহিদ',
      'nancy', 'ন্যান্সি',
      'tahsan', 'তাহসান',
      'imran', 'ইমরান',
      'fuad', 'ফুয়াদ',
      'arfin rumey', 'আরফিন রুমি',
      'kona', 'কনা',
      'mirzapur',
      'selena gomez',
      'dua lipa',
      'billie eilish',
      'sam smith',

      // ── Fashion / Lifestyle (entertainment-adjacent) ─────────
      'fashion', 'ফ্যাশন',
      'model', 'মডেল',
      'runway',
      'photoshoot', 'ফটোশুট',
      'magazine',

      // ── Misc Entertainment ───────────────────────────────────
      'dance', 'নৃত্য', 'ডান্স',
      'theater', 'থিয়েটার',
      'performance', 'পারফরম্যান্স',
      'stand-up comedy',
      'influencer', 'ইউটিউবার', 'youtuber', 'tiktoker',
      'tiktok', 'instagram reel',
      'viral video',
      'celebrity interview',
      'red carpet',
    ],

    // ----------------------------------------------------------
    //  INTERNATIONAL
    // ----------------------------------------------------------
    'international': [
      // ── Major Countries (English) ────────────────────────────
      'usa', 'united states', 'america',
      'uk', 'united kingdom', 'britain', 'england',
      'france',
      'germany',
      'italy',
      'spain',
      'canada',
      'australia',
      'japan',
      'south korea', 'korea',
      'north korea',
      'china',
      'russia',
      'ukraine',
      'india',
      'pakistan',
      'afghanistan',
      'iran',
      'iraq',
      'israel',
      'palestine',
      'saudi arabia',
      'uae', 'united arab emirates',
      'qatar',
      'kuwait',
      'bahrain',
      'oman',
      'jordan',
      'turkey', 'turkiye',
      'egypt',
      'libya',
      'syria',
      'lebanon',
      'yemen',
      'morocco',
      'kenya', 'nigeria', 'south africa', 'ethiopia',
      'brazil',
      'argentina',
      'mexico',
      'venezuela',
      'colombia',
      'myanmar',
      'thailand',
      'vietnam', 'indonesia', 'malaysia', 'philippines',
      'singapore', 'cambodia',
      'sri lanka', 'nepal', 'bhutan', 'maldives',
      'new zealand',
      'sweden', 'norway', 'denmark', 'finland',
      'netherlands', 'belgium', 'switzerland', 'austria', 'poland',
      'czech republic',
      'serbia', 'hungary',
      'portugal', 'greece',
      'ireland', 'scotland', 'wales',

      // ── Major Countries (Bengali) ────────────────────────────
      'যুক্তরাষ্ট্র', 'মার্কিন', 'আমেরিকা',
      'যুক্তরাজ্য', 'ব্রিটেন', 'ইংল্যান্ড',
      'ফ্রান্স',
      'জার্মানি',
      'ইটালি',
      'স্পেন',
      'কানাডা',
      'অস্ট্রেলিয়া',
      'জাপান',
      'দক্ষিণ কোরিয়া', 'উত্তর কোরিয়া',
      'চীন',
      'রাশিয়া',
      'ইউক্রেন', 'কিয়েভ',
      'ভারত', 'দিল্লি',
      'পাকিস্তান', 'ইসলামাবাদ',
      'আফগানিস্তান', 'কাবুল',
      'ইরান', 'তেহরান',
      'ইরাক', 'বাগদাদ',
      'ইসরায়েল', 'তেল আবিব',
      'ফিলিস্তিন', 'গাজা',
      'সৌদি আরব', 'রিয়াদ',
      'কাতার', 'দোহা',
      'তুরস্ক', 'আঙ্কারা',
      'মিসর',
      'লিবিয়া',
      'সিরিয়া', 'দামেস্ক',
      'লেবানন',
      'ইয়েমেন',
      'মিয়ানমার', 'রোহিঙ্গা',
      'মালয়েশিয়া',
      'ইন্দোনেশিয়া',
      'সিঙ্গাপুর',
      'শ্রীলংকা',
      'নেপাল',
      'ভুটান',
      'মালদ্বীপ',
      'ব্রাজিল',
      'আর্জেন্টিনা',

      // ── Key Cities (international) ───────────────────────────
      'washington', 'ওয়াশিংটন',
      'new york', 'নিউ ইয়র্ক',
      'london', 'লন্ডন',
      'paris', 'প্যারিস',
      'berlin', 'বার্লিন',
      'rome', 'রোম',
      'madrid',
      'tokyo', 'টোকিও',
      'seoul',
      'beijing', 'বেইজিং',
      'shanghai',
      'moscow', 'মস্কো',
      'kyiv', 'kiev',
      'delhi', 'new delhi', 'নয়াদিল্লি',
      'mumbai',
      'islamabad',
      'tehran',
      'ankara',
      'riyadh',
      'doha',
      'abu dhabi',
      'dubai',
      'cairo',
      'nairobi',
      'pretoria',
      'ottawa',
      'canberra',

      // ── World Leaders ────────────────────────────────────────
      'biden', 'বাইডেন',
      'trump', 'ট্রাম্প', 'donald trump',
      'kamala harris', 'কামালা হ্যারিস',
      'putin', 'পুতিন', 'vladimir putin',
      'zelensky', 'জেলেনস্কি',
      'modi', 'মোদী', 'narendra modi',
      'xi jinping', 'শি জিনপিং',
      'macron', 'ম্যাক্রোঁ', 'emmanuel macron',
      'scholz', 'olaf scholz',
      'sunak', 'rishi sunak',
      'keir starmer',
      'erdogan', 'এরদোগান',
      'netanyahu', 'নেতানিয়াহু',
      'khamenei', 'খামেনি',
      'mbs', 'crown prince salman', 'মোহাম্মদ বিন সালমান',
      'tamim bin hamad',
      'mamata', 'মমতা',

      // ── International Organizations ──────────────────────────
      'united nations', 'জাতিসংঘ', 'un',
      'un general assembly', 'unga',
      'un security council', 'unsc',
      'nato',
      'eu', 'european union', 'ইউরোপীয় ইউনিয়ন',
      'world bank', 'বিশ্বব্যাংক',
      'imf', 'আন্তর্জাতিক মুদ্রা তহবিল',
      'who', 'বিশ্ব স্বাস্থ্য সংস্থা',
      'wto',
      'saarc', 'সার্ক',
      'asean', 'আসিয়ান',
      'oic', 'ওআইসি',
      'g7', 'g20', 'জি-২০',
      'brics',
      'iaea',
      'unhcr',
      'unicef', 'ইউনিসেফ',
      'world food programme', 'wfp',
      'interpol',
      'icj', 'international court of justice',
      'international criminal court',
      'opec',
      'commonwealth',
      'red cross', 'রেড ক্রস',
      'amnesty international',
      'human rights watch',

      // ── Geopolitical / Diplomatic terms ─────────────────────
      'state department',
      'white house', 'হোয়াইট হাউস',
      'pentagon',
      'kremlin',
      'foreign ministry',
      'embassy', 'দূতাবাস', 'consul',
      'diplomacy', 'কূটনীতি',
      'sanction', 'নিষেধাজ্ঞা', 'sanctions',
      'ceasefire', 'যুদ্ধবিরতি',
      'peace deal', 'শান্তি চুক্তি',
      'peace talks',
      'bilateral', 'দ্বিপাক্ষিক',
      'multilateral',
      'summit', 'শীর্ষ সম্মেলন',
      'joint statement',
      'mou', 'memorandum of understanding',
      'refugee', 'শরণার্থী',
      'asylum',
      'war', 'যুদ্ধ',
      'conflict', 'সংঘাত',
      'airstrike', 'বিমান হামলা',
      'missile', 'মিসাইল',
      'drone attack',
      'nuclear', 'পারমাণবিক',
      'coup', 'অভ্যুত্থান',
      'revolution',
      'protest abroad', 'বিদেশি বিক্ষোভ',
      'geopolitics',
      'trade war',
      'tariff', 'শুল্ক',
      'foreign aid',
      'climate summit', 'cop',
      'paris agreement',
      'kyoto protocol',
      'iran nuclear deal', 'jcpoa',
      'russia-ukraine war', 'রাশিয়া-ইউক্রেন যুদ্ধ',
      'israel-hamas',
      'taiwan strait',
      'south china sea',
      'kashmir',
    ],

    // ----------------------------------------------------------
    //  NATIONAL (Bangladesh-centric)
    // ----------------------------------------------------------
    'national': [
      // ── Country / Capital ────────────────────────────────────
      'bangladesh', 'বাংলাদেশ',
      'dhaka', 'ঢাকা',
      'bd',

      // ── Government & Legislature ─────────────────────────────
      'government', 'সরকার',
      'parliament', 'সংসদ', 'জাতীয় সংসদ', 'national parliament',
      'prime minister', 'প্রধানমন্ত্রী',
      'president', 'রাষ্ট্রপতি',
      'cabinet', 'মন্ত্রিপরিষদ', 'মন্ত্রিসভা',
      'minister', 'মন্ত্রী',
      'ministry', 'মন্ত্রণালয়',
      'secretariat', 'সচিবালয়',
      'secretary', 'সচিব',
      'national security council',
      'speaker', 'স্পিকার',
      'deputy speaker',
      'deputy prime minister',
      'state minister', 'প্রতিমন্ত্রী',
      'adviser', 'উপদেষ্টা',
      'chief adviser', 'প্রধান উপদেষ্টা',
      'interim government', 'অন্তর্বর্তীকালীন সরকার',

      // ── Political Parties ────────────────────────────────────
      'political party', 'রাজনৈতিক দল', 'দল', 'জোট',
      'awami league', 'আওয়ামী লীগ',
      'bnp', 'বিএনপি', 'bangladesh nationalist party',
      'jatiya party', 'জাতীয় পার্টি', 'jp',
      'jamaat-e-islami', 'জামায়াত-ই-ইসলামী', 'জামাত',
      'islami andolan', 'ইসলামী আন্দোলন',
      'jatiya samajtantrik dal', 'জাসদ',
      'workers party', 'ওয়ার্কার্স পার্টি',
      'communist party', 'কমিউনিস্ট পার্টি',
      'bam', 'বাম',
      'toikhelo ando', // placeholder for new parties
      'ncb', 'নাগরিক কমিটি',
      'anti-discrimination movement', 'বৈষম্যবিরোধী আন্দোলন',
      'students movement', 'ছাত্র আন্দোলন',

      // ── Key Political Figures ────────────────────────────────
      'sheikh hasina', 'শেখ হাসিনা',
      'khaleda zia', 'খালেদা জিয়া',
      'tarqeq rahman', 'tareq rahman', 'তারেক রহমান',
      'mirza fakhrul', 'মির্জা ফখরুল',
      'obaidul quader', 'ওবায়দুল কাদের',
      'anisul huq',
      'asaduzzaman khan', 'আসাদুজ্জামান খান',
      'dr yunus', 'মুহাম্মদ ইউনূস', 'muhammad yunus',
      'nahid islam', 'নাহিদ ইসলাম',
      'asif nazrul', 'আসিফ নজরুল',
      'touhid hossain',
      'sk m rafiqul islam',

      // ── Elections & Democracy ────────────────────────────────
      'election', 'নির্বাচন',
      'general election', 'জাতীয় নির্বাচন',
      'by-election', 'উপনির্বাচন',
      'election commission', 'নির্বাচন কমিশন',
      'voter', 'ভোটার',
      'polling', 'ভোটগ্রহণ',
      'ballot',
      'vote rigging',
      'caretaker government', 'তত্ত্বাবধায়ক সরকার',
      'democratic movement', 'গণতান্ত্রিক আন্দোলন',
      'hartaal', 'হরতাল',
      'agitation', 'আন্দোলন',
      'protest', 'বিক্ষোভ',
      'procession', 'মিছিল',
      'rally', 'র‌্যালি', 'সমাবেশ',
      'oust', 'পতন',

      // ── Judiciary / Law ──────────────────────────────────────
      'supreme court', 'সুপ্রিম কোর্ট',
      'high court', 'হাই কোর্ট',
      'chief justice', 'প্রধান বিচারপতি',
      'attorney general', 'অ্যাটর্নি জেনারেল',
      'law minister',
      'anti-corruption commission', 'দুদক', 'acc',
      'cid', 'criminal investigation department',
      'rab', 'র‌্যাব', 'rapid action battalion',
      'police', 'পুলিশ',
      'arrest', 'গ্রেফতার',
      'case filed', 'মামলা',
      'verdict', 'রায়',
      'tribunal', 'ট্রাইব্যুনাল',
      'war crimes tribunal', 'আন্তর্জাতিক অপরাধ ট্রাইব্যুনাল', 'ict',
      'bail', 'জামিন',
      'remand',
      'contempt of court',

      // ── Economy / Business ───────────────────────────────────
      'bangladesh bank', 'বাংলাদেশ ব্যাংক',
      'nbr', 'national board of revenue', 'জাতীয় রাজস্ব বোর্ড',
      'budget', 'বাজেট',
      'gdp',
      'taka', 'টাকা', 'bdt',
      'inflation', 'মূল্যস্ফীতি',
      'forex reserve', 'বৈদেশিক মুদ্রার রিজার্ভ',
      'import', 'রপ্তানি', 'export', 'আমদানি',
      'remittance', 'রেমিট্যান্স', 'প্রবাসী আয়',
      'garment', 'পোশাক', 'rmg', 'readymade garments',
      'bgmea', 'বিজিএমইএ',
      'epz', 'export processing zone',
      'stock market', 'শেয়ার বাজার',
      'dse', 'dhaka stock exchange', 'ঢাকা স্টক এক্সচেঞ্জ',
      'cse', 'chittagong stock exchange',
      'loan', 'ঋণ',
      'npl', 'non-performing loan',
      'privatization',
      'power plant', 'বিদ্যুৎ কেন্দ্র',
      'gas', 'গ্যাস', 'energy crisis',
      'fuel', 'জ্বালানি',
      'prix', 'price hike', 'মূল্যবৃদ্ধি',

      // ── Infrastructure / Development ─────────────────────────
      'padma bridge', 'পদ্মা সেতু',
      'dhaka metro', 'মেট্রোরেল',
      'metro rail', 'মেট্রো রেল',
      'expressway', 'এক্সপ্রেসওয়ে',
      'flyover', 'ফ্লাইওভার',
      'bridge', 'সেতু',
      'power grid',
      'rooppur nuclear', 'রূপপুর পারমাণবিক',
      'karnaphuli tunnel', 'কর্ণফুলী টানেল',
      'matarbari',
      'payra', 'পায়রা',
      'mongla', 'মোংলা',
      'chittagong port', 'চট্টগ্রাম বন্দর',

      // ── Education / Social ───────────────────────────────────
      'university', 'বিশ্ববিদ্যালয়',
      'dhaka university', 'ঢাকা বিশ্ববিদ্যালয়', 'du',
      'buet',
      'ssc', 'hsc', 'psc',
      'examination', 'পরীক্ষা',
      'quota reform', 'কোটা সংস্কার',
      'student politics', 'ছাত্র রাজনীতি',
      'chhatra league', 'ছাত্রলীগ',
      'islami chhatra shibir', 'শিবির',
      'jcd',

      // ── Security / Military ──────────────────────────────────
      'army', 'সেনাবাহিনী',
      'navy', 'নৌবাহিনী',
      'air force', 'বিমান বাহিনী',
      'border guard', 'bdr', 'bgb', 'বিজিবি',
      'military', 'সামরিক',
      'dgfi', 'national security intelligence', 'nsi',
      'coast guard',
      'disaster management', 'দুর্যোগ ব্যবস্থাপনা',

      // ── Health ───────────────────────────────────────────────
      'health ministry', 'স্বাস্থ্য মন্ত্রণালয়',
      'dghs', 'health directorate',
      'dmch', 'dhaka medical', 'ঢাকা মেডিকেল',
      'epidemic', 'মহামারি',
      'dengue', 'ডেঙ্গু',
      'cholera',
      'vaccine', 'টিকা',

      // ── Environment / Disaster ───────────────────────────────
      'flood', 'বন্যা',
      'cyclone', 'ঘূর্ণিঝড়',
      'fire', 'আগুন', 'fire incident',
      'earthquake', 'ভূমিকম্প',
      'landslide', 'ভূমিধস',
      'drought', 'খরা',
      'river erosion', 'নদী ভাঙন',
      'climate change', 'জলবায়ু পরিবর্তন',
      'sundarbans', 'সুন্দরবন',

      // ── Regions of Bangladesh ────────────────────────────────
      'chittagong', 'চট্টগ্রাম',
      'sylhet', 'সিলেট',
      'khulna', 'খুলনা',
      'rajshahi', 'রাজশাহী',
      'rangpur', 'রংপুর',
      'barishal', 'বরিশাল',
      'mymensingh', 'ময়মনসিংহ',
      'cox\'s bazar', 'কক্সবাজার',
      'gazipur', 'গাজীপুর',
      'narayanganj', 'নারায়ণগঞ্জ',
      'cumilla', 'কুমিল্লা',
      'parbatya chattogram', 'পার্বত্য চট্টগ্রাম',
      'chittagong hill tracts',
      'haor', 'হাওর',
      'char area', 'চরাঞ্চল',

      // ── Politics & Governance ────────────────────────────────
      'politics', 'রাজনীতি', 'রাজনৈতিক',
      'election', 'নির্বাচন', 'উপনির্বাচন',
      'parliament', 'সংসদ', 'জাতীয় সংসদ',
      'government', 'সরকার', 'সরকারি', 'বেসরকারি',
      'ministry', 'মন্ত্রণালয়', 'পররাষ্ট্র',
      'cabinet', 'মন্ত্রিসভা',
      'opposition', 'বিরোধী দল',
      'rally', 'সমাবেশ', 'মিছিল', 'বিক্ষোভ',

      // ── Legal & Social ───────────────────────────────────────
      'court', 'আদালত', 'হাইকোর্ট', 'সুপ্রিম কোর্ট',
      'verdict', 'রায়', 'মামলা', 'গ্রেফতার', 'কারাগার',
      'society', 'সমাজ', 'সামাজিক', 'নারী', 'শিশু',
      'justice', 'বিচার', 'তদন্ত', 'নির্যাতন',
      'human rights', 'মানবাধিকার',
      'education', 'শিক্ষা', 'বিশ্ববিদ্যালয়', 'স্কুল', 'কলেজ',
    ],
  };

  // ============================================================
  //  SOFT KEYWORDS  (secondary / tiebreaker signals)
  // ============================================================

  static const List<String> _entertainmentSoftKeywords = [
    'বিনোদন', 'শোবিজ', 'তারকা', 'অভিনেত্রী', 'নায়িকা',
    'পরিচালক', 'সংগীত', 'সঙ্গীত', 'ট্রেলার', 'টিজার',
    'মুক্তি', 'ওটিটি', 'রিয়েলিটি শো', 'সিরিয়াল',
    'celebrity', 'celebrities', 'trailer', 'teaser', 'ott',
    'web series', 'award', 'award show', 'audition',
    'casting call', 'upcoming film', 'new movie',
    'behind the scenes', 'bts exclusive',
    'item song', 'playback', 'choreographer',
    'debut', 'প্রথম ছবি', 'comeback',
    'press conference', 'media',
    'rumour', 'gossip', 'affair',
    'wedding', 'divorce', 'relationship', // celeb news context
    'photoshoot', 'interview exclusive',
  ];

  static const List<String> _sportsSoftKeywords = [
    'vs', 'বনাম',
    'জয়', 'হার', 'draw', 'ড্র',
    'hattrick', 'hat-trick', 'হ্যাটট্রিক',
    'points table', 'পয়েন্ট টেবিল',
    'fixtures', 'ফিক্সচার',
    'knockout', 'round of 16',
    'quarterfinal', 'quarter final', 'কোয়ার্টার ফাইনাল',
    'semi final', 'ম্যাচ জিতেছে',
    'man of the match', 'ম্যান অব দ্য ম্যাচ',
    'player of the series',
    'live score', 'লাইভ স্কোর',
    'press conference', // team press conf
    'training camp', 'ট্রেনিং ক্যাম্প',
    'injury update', 'fit for match',
    'comeback', 'return to form',
    'debut',
    'home series', 'away series',
    'টস', 'toss',
    'ড্রেসিং রুম', 'dressing room',
    'পুরস্কার', // sports award
  ];

  static const List<String> _internationalSoftKeywords = [
    'international',
    'আন্তর্জাতিক',
    'global',
    'গ্লোবাল',
    'বৈশ্বিক',
    'foreign',
    'বিদেশ',
    'বিদেশী',
    'diplomacy',
    'কূটনীতি',
    'bilateral',
    'দ্বিপাক্ষিক',
    'দ্বিপক্ষীয়',
    'summit',
    'শীর্ষ সম্মেলন',
    'embassy',
    'দূতাবাস',
    'foreign ministry',
    'পররাষ্ট্র মন্ত্রণালয়',
    'sanction',
    'নিষেধাজ্ঞা',
    'ceasefire',
    'যুদ্ধবিরতি',
    'geopolitics',
    'overseas',
    'প্রবাসী',
    'immigrant',
    'অভিবাসী',
    'terrorism',
    'সন্ত্রাস',
    'extremism',
    'oil price',
    'তেলের দাম',
    'global economy',
    'currency crisis',
    'cross-border',
    'expat',
    'expatriate',
    'foreign investment',
  ];

  static const List<String> _nationalSoftKeywords = [
    'দেশীয়', 'স্থানীয়',
    'local administration', 'স্থানীয় প্রশাসন',
    'union parishad', 'ইউনিয়ন পরিষদ',
    'city corporation', 'সিটি করপোরেশন', 'সিটি কর্পোরেশন',
    'district administration', 'জেলা প্রশাসন',
    'upazila', 'উপজেলা', 'upazila nirbahi officer',
    'thana', 'থানা',
    'mayor', 'মেয়র',
    'ward commissioner', 'ওয়ার্ড কমিশনার',
    'জেলা পরিষদ', 'দেশের', 'বাংলাদেশে',
    'national', 'জাতীয়',
    'internal affairs',
    'home ministry', 'স্বরাষ্ট্র মন্ত্রণালয়',
    'deputy commissioner', 'ডিসি',
    'superintendent of police', 'এসপি',
    'fire service', 'ফায়ার সার্ভিস',
    'social welfare', 'সমাজকল্যাণ',
    'woman affairs', 'মহিলা বিষয়ক',
    'jute', 'পাট',
    'agriculture', 'কৃষি',
    'farmer', 'কৃষক',
    'fishermen', 'জেলে',
    'tk', // short for Taka in Bengali headlines
  ];

  // ============================================================
  //  DISTRICT / REGION MAPS
  // ============================================================

  static final Map<String, List<String>> _bdDistrictCanonicalKeywords = {
    // Dhaka Division (13)
    'dhaka': ['dhaka', 'ঢাকা'],
    'faridpur': ['faridpur', 'ফরিদপুর'],
    'gazipur': ['gazipur', 'গাজীপুর', 'gazipur city'],
    'gopalganj': ['gopalganj', 'গোপালগঞ্জ'],
    'kishoreganj': ['kishoreganj', 'কিশোরগঞ্জ'],
    'madaripur': ['madaripur', 'মাদারীপুর', 'মাদারিপুর'],
    'manikganj': ['manikganj', 'মানিকগঞ্জ'],
    'munshiganj': ['munshiganj', 'munsiganj', 'মুন্সীগঞ্জ', 'মুন্সিগঞ্জ'],
    'narayanganj': ['narayanganj', 'নারায়ণগঞ্জ'],
    'narsingdi': ['narsingdi', 'নরসিংদী', 'নরসিংদি'],
    'rajbari': ['rajbari', 'রাজবাড়ী'],
    'shariatpur': ['shariatpur', 'shariyatpur', 'শরীয়তপুর', 'শরিয়তপুর'],
    'tangail': ['tangail', 'টাঙ্গাইল', 'টাংগাইল'],
    // Chattogram Division (11)
    'bandarban': ['bandarban', 'বান্দরবান'],
    'brahmanbaria': ['brahmanbaria', 'bramhanbaria', 'ব্রাহ্মণবাড়িয়া'],
    'chandpur': ['chandpur', 'চাঁদপুর', 'চাদপুর'],
    'chattogram': ['chattogram', 'chittagong', 'চট্টগ্রাম'],
    'cumilla': ['cumilla', 'comilla', 'কুমিল্লা'],
    'coxs_bazar': ['coxs bazar', 'cox bazar', 'cox\'s bazar', 'কক্সবাজার'],
    'feni': ['feni', 'ফেনী', 'ফেনি'],
    'khagrachhari': ['khagrachhari', 'khagrachari', 'খাগড়াছড়ি'],
    'lakshmipur': ['lakshmipur', 'laxmipur', 'লক্ষ্মীপুর', 'লক্ষীপুর'],
    'noakhali': ['noakhali', 'নোয়াখালী'],
    'rangamati': ['rangamati', 'রাঙ্গামাটি', 'রাঙামাটি'],
    // Khulna Division (10)
    'bagerhat': ['bagerhat', 'bagherhat', 'বাগেরহাট'],
    'chuadanga': ['chuadanga', 'চুয়াডাঙ্গা'],
    'jashore': ['jashore', 'jessore', 'যশোর'],
    'jhenaidah': ['jhenaidah', 'ঝিনাইদহ'],
    'khulna': ['khulna', 'খুলনা'],
    'kushtia': ['kushtia', 'কুষ্টিয়া'],
    'magura': ['magura', 'মাগুরা'],
    'meherpur': ['meherpur', 'মেহেরপুর'],
    'narail': ['narail', 'নড়াইল'],
    'satkhira': ['satkhira', 'সাতক্ষীরা', 'সাতক্ষিরা'],
    // Rajshahi Division (8)
    'bogura': ['bogura', 'bogra', 'বগুড়া'],
    'joypurhat': ['joypurhat', 'জয়পুরহাট'],
    'naogaon': ['naogaon', 'নওগাঁ', 'নওগা'],
    'natore': ['natore', 'নাটোর'],
    'chapainawabganj': [
      'chapainawabganj',
      'chapai nawabganj',
      'নওয়াবগঞ্জ',
      'নবাবগঞ্জ',
      'চাপাইনবাবগঞ্জ',
    ],
    'pabna': ['pabna', 'পাবনা'],
    'rajshahi': ['rajshahi', 'রাজশাহী'],
    'sirajganj': ['sirajganj', 'সিরাজগঞ্জ'],
    // Rangpur Division (8)
    'dinajpur': ['dinajpur', 'দিনাজপুর'],
    'gaibandha': ['gaibandha', 'গাইবান্ধা'],
    'kurigram': ['kurigram', 'কুড়িগ্রাম'],
    'lalmonirhat': ['lalmonirhat', 'লালমনিরহাট'],
    'nilphamari': ['nilphamari', 'নীলফামারী', 'নীলফামারি'],
    'panchagarh': ['panchagarh', 'পঞ্চগড়'],
    'rangpur': ['rangpur', 'রংপুর'],
    'thakurgaon': ['thakurgaon', 'ঠাকুরগাঁও'],
    // Barishal Division (6)
    'barguna': ['barguna', 'বরগুনা'],
    'barishal': ['barishal', 'barisal', 'বরিশাল'],
    'bhola': ['bhola', 'ভোলা'],
    'jhalokathi': ['jhalokathi', 'jhalokati', 'ঝালকাঠি'],
    'patuakhali': ['patuakhali', 'পটুয়াখালী'],
    'pirojpur': ['pirojpur', 'পিরোজপুর'],
    // Sylhet Division (4)
    'habiganj': ['habiganj', 'হবিগঞ্জ'],
    'moulvibazar': ['moulvibazar', 'maulvibazar', 'মৌলভীবাজার'],
    'sunamganj': ['sunamganj', 'সুনামগঞ্জ'],
    'sylhet': ['sylhet', 'সিলেট'],
    // Mymensingh Division (4)
    'jamalpur': ['jamalpur', 'জামালপুর'],
    'mymensingh': ['mymensingh', 'ময়মনসিংহ'],
    'netrokona': ['netrokona', 'netrakona', 'নেত্রকোনা'],
    'sherpur': ['sherpur', 'শেরপুর'],
  };

  static final List<String> _bdDivisionKeywords = [
    'dhaka division',
    'ঢাকা বিভাগ',
    'chattogram division',
    'chittagong division',
    'চট্টগ্রাম বিভাগ',
    'khulna division',
    'খুলনা বিভাগ',
    'rajshahi division',
    'রাজশাহী বিভাগ',
    'rangpur division',
    'রংপুর বিভাগ',
    'barishal division',
    'barisal division',
    'বরিশাল বিভাগ',
    'sylhet division',
    'সিলেট বিভাগ',
    'mymensingh division',
    'ময়মনসিংহ বিভাগ',
  ];

  static final List<String> _bdDistrictKeywordVariants =
      _bdDistrictCanonicalKeywords.values
          .expand((variants) => variants)
          .toList(growable: false);

  static final List<String> _bdMajorRegionKeywords = [
    'bangladesh',
    'বাংলাদেশ',
    'bd',
    ..._bdDivisionKeywords,
    ..._bdDistrictKeywordVariants,
    'parbatya chattogram',
    'পার্বত্য চট্টগ্রাম',
    'chittagong hill tracts',
    'haor',
    'হাওর',
    'char area',
    'চরাঞ্চল',
  ];

  static final List<String> _bdSubnationalKeywords = [
    ..._bdDivisionKeywords,
    ..._bdDistrictKeywordVariants,
    'parbatya chattogram',
    'পার্বত্য চট্টগ্রাম',
    'chittagong hill tracts',
    'haor',
    'হাওর',
    'char area',
    'চরাঞ্চল',
  ];

  static final List<String> _bdBangladeshKeywords = [..._bdMajorRegionKeywords];

  // ============================================================
  //  DISAMBIGUATION / EXCLUSION RULES
  // ============================================================

  /// Entertainment personalities who must NOT trigger a sports match
  static const List<String> _entertainmentCelebrities = [
    'shakib khan',
    'শাকিব খান',
    'taylor swift',
    'selena gomez',
    'bollywood',
    'বলিউড',
    'hollywood',
    'dhallywood',
    'ঢালিউড',
    'tollywood',
    'টলিউড',
    'kollywood',
  ];

  /// Broad terms that are too generic to independently trigger sports.
  static const Set<String> _sportsAmbiguousKeywords = {
    'team',
    'দল',
    'match',
    'ম্যাচ',
    'league',
    'লীগ',
    'লিগ',
    'player',
    'খেলোয়াড়',
    'score',
    'স্কোর',
    'goal',
    'গোল',
    'tournament',
    'টুর্নামেন্ট',
  };

  /// Broad terms that are too generic to independently trigger entertainment.
  static const Set<String> _entertainmentAmbiguousKeywords = {
    'series',
    'show',
    'performance',
    'পারফরম্যান্স',
    'release',
    'মুক্তি',
    'রিলিজ',
    'media',
    'magazine',
    'model',
    'interview',
  };

  /// Hard entertainment evidence used to avoid false positives from generic
  /// words like "media", "interview", or "release".
  static const List<String> _entertainmentHardKeywords = [
    'showbiz',
    'শোবিজ',
    'celebrity',
    'celebrities',
    'সেলিব্রিটি',
    'অভিনেতা',
    'অভিনেত্রী',
    'actor',
    'actress',
    'movie',
    'film',
    'cinema',
    'সিনেমা',
    'চলচ্চিত্র',
    'নাটক',
    'drama',
    'web series',
    'ওয়েব সিরিজ',
    'trailer',
    'ট্রেলার',
    'teaser',
    'টিজার',
    'album',
    'song',
    'concert',
    'ott',
    'netflix',
    'chorki',
    'hollywood',
    'bollywood',
    'dhallywood',
  ];

  static const List<String> _governanceContextKeywords = [
    'government',
    'সরকার',
    'ministry',
    'মন্ত্রণালয়',
    'parliament',
    'সংসদ',
    'budget',
    'বাজেট',
    'election',
    'নির্বাচন',
    'policy',
    'নীতি',
    'cabinet',
    'মন্ত্রিসভা',
    'court',
    'আদালত',
    'district administration',
    'জেলা প্রশাসন',
    'upazila',
    'উপজেলা',
    'local administration',
    'স্থানীয় প্রশাসন',
  ];

  /// West Bengal → always international
  static const List<String> _westBengalKeywords = [
    'west bengal', 'পশ্চিমবঙ্গ', 'paschim banga',
    'kolkata', 'কলকাতা',
    'mamata', 'মমতা',
    'trinamool', 'তৃণমূল', 'tmc',
    'bjp', 'বিজেপি',
    'congress india', // only when clearly about Indian politics
  ];

  /// Hard international signals that override BD-centric detection
  static const List<String> _internationalHardKeywords = [
    'india',
    'ভারত',
    'usa',
    'america',
    'যুক্তরাষ্ট্র',
    'মার্কিন',
    'uk',
    'britain',
    'যুক্তরাজ্য',
    'china',
    'চীন',
    'russia',
    'রাশিয়া',
    'ukraine',
    'ইউক্রেন',
    'israel',
    'ইসরায়েল',
    'gaza',
    'গাজা',
    'palestine',
    'ফিলিস্তিন',
    'pakistan',
    'পাকিস্তান',
    'japan',
    'জাপান',
    'france',
    'ফ্রান্স',
    'germany',
    'জার্মানি',
    'canada',
    'কানাডা',
    'australia',
    'অস্ট্রেলিয়া',
    'saudi arabia',
    'সৌদি আরব',
    'iran',
    'ইরান',
    'turkey',
    'turkiye',
    'তুরস্ক',
    'united nations',
    'জাতিসংঘ',
    'white house',
    'হোয়াইট হাউস',
    'state department',
    'nato',
    'eu',
    'european union',
    'myanmar',
    'মিয়ানমার',
    'afghanistan',
    'আফগানিস্তান',
    'syria',
    'সিরিয়া',
    'iraq',
    'ইরাক',
    'north korea',
    'উত্তর কোরিয়া',
    'south korea',
    'দক্ষিণ কোরিয়া',
    'taiwan',
    'sri lanka',
    'শ্রীলংকা',
    'nepal',
    'নেপাল',
    'maldives',
    'মালদ্বীপ',
    'bhutan',
    'ভুটান',
  ];

  // ============================================================
  //  TESTING ACCESSORS
  // ============================================================

  @visibleForTesting
  static int get canonicalDistrictCount => _bdDistrictCanonicalKeywords.length;

  @visibleForTesting
  static List<String> get canonicalDistrictIds =>
      List<String>.unmodifiable(_bdDistrictCanonicalKeywords.keys);

  // ============================================================
  //  CORE CATEGORIZATION LOGIC
  // ============================================================

  /// Fast keyword-based categorization
  static CategorizationResult categorizeByKeywords({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();

    // ── STEP 1: Absolute exclusion rules ──────────────────────

    // West Bengal always → international
    if (_hasKeywords(text, _westBengalKeywords)) {
      return const CategorizationResult(
        category: 'international',
        confidence: 0.95,
        source: 'pattern',
        reason: 'West Bengal detected - always international',
      );
    }

    // ── STEP 2: Strong category detection ─────────────────────

    final hasSports = _hasKeywords(text, _strongKeywords['sports']!);
    final hasEntertainment = _hasKeywords(
      text,
      _strongKeywords['entertainment']!,
    );
    final hasInternational = _hasKeywords(
      text,
      _strongKeywords['international']!,
    );
    final hasStrongIntl = _hasKeywords(text, _internationalHardKeywords);
    final sportsCount = _countKeywords(text, _strongKeywords['sports']!);
    final entertainmentCount = _countKeywords(
      text,
      _strongKeywords['entertainment']!,
    );
    final intlCount = _countKeywords(text, _strongKeywords['international']!);
    final nationalCount = _countKeywords(text, _strongKeywords['national']!);
    final sportsSpecificCount = _countNonAmbiguousKeywords(
      text,
      _strongKeywords['sports']!,
      _sportsAmbiguousKeywords,
    );
    final entertainmentSpecificCount = _countNonAmbiguousKeywords(
      text,
      _strongKeywords['entertainment']!,
      _entertainmentAmbiguousKeywords,
    );
    final hasEntertainmentHardEvidence = hasHardEntertainmentEvidence(
      title: title,
      description: description,
      content: content,
    );
    final hasGovernanceContext = _hasKeywords(text, _governanceContextKeywords);
    final bdSignalScore = _bangladeshSignalScoreText(text);
    final intlSignalScore = _internationalSignalScoreText(text);

    // Pure sports (no entertainment contamination)
    if (hasSports &&
        !hasEntertainment &&
        (sportsCount >= 2 ||
            sportsSpecificCount > 0 ||
            _isSportsEventReporting(text))) {
      if (!_hasKeywords(text, _entertainmentCelebrities)) {
        return const CategorizationResult(
          category: 'sports',
          confidence: 0.88,
          source: 'pattern',
          reason: 'Strong sports keywords, no entertainment conflict',
        );
      }
    }

    // Pure entertainment
    if (hasEntertainment &&
        !hasSports &&
        hasEntertainmentHardEvidence &&
        (entertainmentCount >= 2 || entertainmentSpecificCount > 0)) {
      return const CategorizationResult(
        category: 'entertainment',
        confidence: 0.83,
        source: 'pattern',
        reason: 'Strong entertainment keywords, no sports conflict',
      );
    }

    // Overlap: sports AND entertainment → resolve by count
    if (hasSports && hasEntertainment) {
      if (_hasKeywords(text, _entertainmentCelebrities) &&
          !_isSportsEventReporting(text) &&
          hasEntertainmentHardEvidence &&
          !hasGovernanceContext) {
        return const CategorizationResult(
          category: 'entertainment',
          confidence: 0.78,
          source: 'context',
          reason: 'Entertainment celebrity context overrides sports overlap',
        );
      }

      if (_isSportsEventReporting(text)) {
        return const CategorizationResult(
          category: 'sports',
          confidence: 0.78,
          source: 'context',
          reason: 'Sports event reporting overrides entertainment overlap',
        );
      }

      if (sportsSpecificCount > entertainmentSpecificCount) {
        return const CategorizationResult(
          category: 'sports',
          confidence: 0.73,
          source: 'context',
          reason: 'Sports-specific keywords dominate overlap',
        );
      }

      if (entertainmentSpecificCount > sportsSpecificCount &&
          hasEntertainmentHardEvidence) {
        return const CategorizationResult(
          category: 'entertainment',
          confidence: 0.73,
          source: 'context',
          reason: 'Entertainment-specific keywords dominate overlap',
        );
      }

      if (sportsCount > entertainmentCount) {
        return const CategorizationResult(
          category: 'sports',
          confidence: 0.70,
          source: 'context',
          reason: 'Sports count dominates over entertainment',
        );
      }

      return hasEntertainmentHardEvidence
          ? const CategorizationResult(
              category: 'entertainment',
              confidence: 0.70,
              source: 'context',
              reason: 'Entertainment count dominates over sports',
            )
          : const CategorizationResult(
              category: 'sports',
              confidence: 0.69,
              source: 'context',
              reason:
                  'Entertainment overlap lacked hard evidence; sports retained.',
            );
    }

    // ── STEP 3: Bangladesh-centric rules ──────────────────────

    final isBD = _hasKeywords(text, _bdBangladeshKeywords);
    if (isBD) {
      // BD + strong international signal
      if (hasInternational &&
          (hasStrongIntl || intlCount >= nationalCount) &&
          intlSignalScore >= (bdSignalScore + 2)) {
        return const CategorizationResult(
          category: 'international',
          confidence: 0.84,
          source: 'context',
          reason: 'Bangladesh mentioned with strong international context',
        );
      }

      if (hasSports) {
        if (_isSportsEventReporting(text)) {
          return const CategorizationResult(
            category: 'sports',
            confidence: 0.78,
            source: 'context',
            reason: 'Bangladesh sports event reporting',
          );
        }
        return const CategorizationResult(
          category: 'national',
          confidence: 0.80,
          source: 'context',
          reason: 'Bangladesh context with sports aspect = national news',
        );
      }

      if (hasEntertainment &&
          hasEntertainmentHardEvidence &&
          !hasGovernanceContext) {
        return const CategorizationResult(
          category: 'entertainment',
          confidence: 0.78,
          source: 'context',
          reason: 'Bangladesh entertainment news with hard evidence',
        );
      }

      return const CategorizationResult(
        category: 'national',
        confidence: 0.88,
        source: 'pattern',
        reason: 'Bangladesh context, no sports/entertainment indicators',
      );
    }

    // ── STEP 4: Weighted score fallback ───────────────────────

    final sportsScore = _weightedScore(
      text,
      _strongKeywords['sports']!,
      _sportsSoftKeywords,
    );
    final entertainScoreRaw = _weightedScore(
      text,
      _strongKeywords['entertainment']!,
      _entertainmentSoftKeywords,
      softWeight: 0.18,
      hardBonus: hasEntertainmentHardEvidence ? 1.6 : 0.0,
    );
    final entertainScore = hasEntertainmentHardEvidence
        ? entertainScoreRaw
        : (entertainScoreRaw * 0.55);
    final intlScore = _weightedScore(
      text,
      _strongKeywords['international']!,
      _internationalSoftKeywords,
      hardBonus: hasStrongIntl ? 2.0 : 0.0,
    );
    final nationalScore = _weightedScore(
      text,
      _strongKeywords['national']!,
      _nationalSoftKeywords,
    );

    final Map<String, double> scores = {
      'sports': sportsScore,
      'entertainment': entertainScore,
      'international': intlScore,
      'national': nationalScore,
    };

    String winner = 'national';
    double maxScore = 0;
    scores.forEach((cat, score) {
      if (score > maxScore) {
        maxScore = score;
        winner = cat;
      }
    });

    if (maxScore == 0) {
      return const CategorizationResult(
        category: 'national',
        confidence: 0.3,
        source: 'keyword',
        reason: 'No strong keywords - defaulting to national',
      );
    }

    final totalScore = sportsScore + entertainScore + intlScore + nationalScore;
    final confidence = (maxScore / (totalScore + 1.0)).clamp(0.0, 0.9);

    if (winner == 'international' && bdSignalScore > 0) {
      if (intlSignalScore < (bdSignalScore + 2)) {
        return const CategorizationResult(
          category: 'national',
          confidence: 0.72,
          source: 'context',
          reason:
              'Bangladesh governance/local context dominated weak international markers.',
        );
      }
    }

    if (winner == 'entertainment' &&
        (!hasEntertainmentHardEvidence || hasGovernanceContext)) {
      return const CategorizationResult(
        category: 'national',
        confidence: 0.7,
        source: 'context',
        reason:
            'Entertainment soft markers lacked hard evidence in a national/governance context.',
      );
    }

    return CategorizationResult(
      category: winner,
      confidence: confidence,
      source: 'keyword',
      reason:
          '$winner scored ${maxScore.toStringAsFixed(2)} '
          '(${(confidence * 100).toStringAsFixed(0)}% confidence)',
    );
  }

  /// Compute weighted score for a category
  static double _weightedScore(
    String text,
    List<String> strong,
    List<String> soft, {
    double softWeight = 0.4,
    double hardBonus = 0.0,
  }) {
    final strongCount = _countKeywords(text, strong);
    final strongNormalized = strong
        .map((e) => e.toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final softOnly = soft
        .where((kw) {
          final normalized = kw.toLowerCase().trim();
          return normalized.isNotEmpty &&
              !strongNormalized.contains(normalized);
        })
        .toList(growable: false);
    final softCount = _countKeywords(text, softOnly);
    final base = strongCount > 2 ? strongCount * 1.2 : strongCount * 0.9;
    return base + (softCount * softWeight) + hardBonus;
  }

  /// Detect sports event reporting (match results / fixtures)
  static bool _isSportsEventReporting(String text) {
    const sportsEventKeywords = [
      'match report',
      'match highlights',
      'final score',
      'tournament result',
      'won the match',
      'defeated',
      'beat',
      'innings',
      'test cricket',
      'world cup',
      'champion',
      'championship',
      'league standings',
      'cricket board',
      'match preview',
      'match prediction',
      'live cricket',
      'live football',
      'live score',
      'টস জিতে',
      'ব্যাটিং করবে',
      'ফিল্ডিং করবে',
    ];
    return _hasKeywords(text, sportsEventKeywords);
  }

  // ============================================================
  //  SMART CATEGORIZATION (local + optional AI shadow)
  // ============================================================

  static Future<CategorizationResult> categorizeSmartly({
    required String title,
    required String description,
    String? content,
    String language = 'en',
    String? articleId,
    String? feedCategory,
    bool collectAiSignals = true,
    void Function(Map<String, dynamic> insight)? onAiInsight,
  }) async {
    final localResult = categorizeByKeywords(
      title: title,
      description: description,
      content: content,
    );

    final shouldCollect =
        collectAiSignals && _shouldCollectAiKnowledgeForFeed(feedCategory);

    if (shouldCollect && !localResult.isHighConfidence) {
      unawaited(
        collectAiKnowledgeOnly(
          title: title,
          description: description,
          content: content,
          language: language,
          articleId: articleId,
          feedCategory: feedCategory,
          localCategory: localResult.category,
          localConfidence: localResult.confidence,
          onAiInsight: onAiInsight,
        ),
      );
    }

    return localResult;
  }

  static bool _shouldCollectAiKnowledgeForFeed(String? feedCategory) {
    final normalized = (feedCategory ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _aiKnowledgeHomeFeedCategories.contains(normalized);
  }

  static Future<void> collectAiKnowledgeOnly({
    required String title,
    required String description,
    required String localCategory,
    required double localConfidence,
    String? content,
    String language = 'en',
    String? articleId,
    String? feedCategory,
    void Function(Map<String, dynamic> insight)? onAiInsight,
  }) async {
    try {
      final aiCategoryStr = await EnhancedAICategorizer.instance
          .categorizeArticle(
            title: title,
            description: description,
            content: content ?? '',
            language: language,
          );

      final insight = <String, dynamic>{
        'entityType': 'ai_signal',
        'action': 'categorization_shadow',
        'entityId': articleId ?? title.hashCode.toString(),
        'articleId': articleId ?? title.hashCode.toString(),
        'feedCategory': feedCategory ?? 'unknown',
        'language': language,
        'localCategory': localCategory,
        'localConfidence': localConfidence,
        'aiCategory': aiCategoryStr,
        'matched': aiCategoryStr == localCategory,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _aiKnowledgeSamples.add(insight);
      if (_aiKnowledgeSamples.length > _maxAiKnowledgeSamples) {
        _aiKnowledgeSamples.removeRange(
          0,
          _aiKnowledgeSamples.length - _maxAiKnowledgeSamples,
        );
      }

      onAiInsight?.call(insight);
    } catch (e) {
      debugPrint('$_tag AI shadow collection failed: $e');
    }
  }

  @visibleForTesting
  static List<Map<String, dynamic>> get aiKnowledgeSamples =>
      List<Map<String, dynamic>>.unmodifiable(_aiKnowledgeSamples);

  @visibleForTesting
  static bool shouldCollectAiSignalsForFeed(String? feedCategory) =>
      _shouldCollectAiKnowledgeForFeed(feedCategory);

  @visibleForTesting
  static void clearAiKnowledgeSamples() => _aiKnowledgeSamples.clear();

  static Future<String> categorizeLocalWithAiShadow({
    required String title,
    required String description,
    String? content,
    String language = 'en',
    String? articleId,
    String? feedCategory,
    void Function(Map<String, dynamic> insight)? onAiInsight,
  }) async {
    final result = await categorizeSmartly(
      title: title,
      description: description,
      content: content,
      language: language,
      articleId: articleId,
      feedCategory: feedCategory,
      onAiInsight: onAiInsight,
    );
    return result.category;
  }

  // ============================================================
  //  KEYWORD MATCHING PRIMITIVES
  // ============================================================

  static int _countKeywords(String text, List<String> keywords) {
    int count = 0;
    final seen = <String>{};
    for (final kw in keywords) {
      final normalized = kw.toLowerCase().trim();
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      if (_containsKeyword(text, normalized)) count++;
    }
    return count;
  }

  static int _countNonAmbiguousKeywords(
    String text,
    List<String> keywords,
    Set<String> ambiguousKeywords,
  ) {
    int count = 0;
    final seen = <String>{};
    for (final kw in keywords) {
      final normalized = kw.toLowerCase().trim();
      if (normalized.isEmpty ||
          ambiguousKeywords.contains(normalized) ||
          !seen.add(normalized)) {
        continue;
      }
      if (_containsKeyword(text, normalized)) count++;
    }
    return count;
  }

  static bool _hasKeywords(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (_containsKeyword(text, kw)) return true;
    }
    return false;
  }

  /// Word-boundary match for pure ASCII tokens; substring match otherwise
  static bool _containsKeyword(String text, String keyword) {
    if (keyword.isEmpty) return false;
    final normalized = keyword.toLowerCase().trim();
    if (normalized.isEmpty) return false;

    // ── Pattern 1: Alphanumeric (English/Digits) ────────────
    // Use word boundaries. We cache the RegExp to avoid creating it 1000s of times.
    if (_alphanumericPtn.hasMatch(normalized)) {
      final cacheKey = 'b_$normalized';
      final pattern = _regexCache[cacheKey] ??= RegExp(
        r'\b' + RegExp.escape(normalized) + r'\b',
        caseSensitive: false,
      );

      // Basic cache management to prevent memory issues
      if (_regexCache.length > _maxCacheSize) _regexCache.clear();

      return pattern.hasMatch(text);
    }

    // ── Pattern 2: Non-ASCII (Bangla/Other) ────────────────
    // We use a simple contains for performance and to handle Bangla suffixes.
    return text.contains(normalized);
  }

  // ============================================================
  //  PUBLIC SIGNAL HELPERS  (used by feed filtering layers)
  // ============================================================

  static bool isBangladeshCentric({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    return _hasKeywords(text, _bdBangladeshKeywords);
  }

  static int _bangladeshSignalScoreText(String text) {
    final regionCount = _countKeywords(
      text,
      _bdSubnationalKeywords,
    ).clamp(0, 4);
    final nationalSoft = _countKeywords(
      text,
      _nationalSoftKeywords,
    ).clamp(0, 3);
    final nationalStrong = _countKeywords(
      text,
      _strongKeywords['national']!,
    ).clamp(0, 3);
    final hasBd = _hasKeywords(text, _bdBangladeshKeywords) ? 3 : 0;
    return hasBd + regionCount + nationalSoft + nationalStrong;
  }

  static int _internationalSignalScoreText(String text) {
    final hard = _countKeywords(text, _internationalHardKeywords);
    final strong = _countKeywords(text, _strongKeywords['international']!);
    final soft = _countKeywords(text, _internationalSoftKeywords).clamp(0, 3);
    return (hard * 3) + (strong * 2) + soft;
  }

  static int bangladeshSignalScore({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    return _bangladeshSignalScoreText(text);
  }

  static int internationalSignalScore({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    return _internationalSignalScoreText(text);
  }

  static bool hasInternationalDominance({
    required String title,
    required String description,
    String? content,
    int minimumDeltaWhenBangladesh = 2,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    final bdScore = _bangladeshSignalScoreText(text);
    final intlScore = _internationalSignalScoreText(text);

    if (bdScore > 0) {
      return intlScore >= (bdScore + minimumDeltaWhenBangladesh);
    }
    return intlScore >= 4;
  }

  static bool hasSportsKeywords({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    return _hasKeywords(text, _strongKeywords['sports']!);
  }

  static bool hasSportsSoftKeywords({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    return _hasKeywords(text, _sportsSoftKeywords);
  }

  static bool hasStrongSportsEvidence({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();

    if (_isSportsEventReporting(text)) {
      return true;
    }

    final nonAmbiguousSportsCount = _countNonAmbiguousKeywords(
      text,
      _strongKeywords['sports']!,
      _sportsAmbiguousKeywords,
    );
    if (nonAmbiguousSportsCount >= 2) {
      return true;
    }

    final hasSportsSoft = _hasKeywords(text, _sportsSoftKeywords);
    final hasLikelyNonSportsContext = _hasKeywords(text, const <String>[
      'election',
      'নির্বাচন',
      'parliament',
      'সংসদ',
      'minister',
      'মন্ত্রী',
      'court',
      'আদালত',
      'budget',
      'বাজেট',
      'diplomacy',
      'কূটনীতি',
      'foreign ministry',
      'prime minister',
      'প্রধানমন্ত্রী',
    ]);

    if (nonAmbiguousSportsCount >= 1 &&
        hasSportsSoft &&
        !hasLikelyNonSportsContext) {
      return true;
    }

    return false;
  }

  static bool hasEntertainmentKeywords({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    return _hasKeywords(text, _strongKeywords['entertainment']!);
  }

  static bool hasHardEntertainmentEvidence({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    final hardCount = _countKeywords(text, _entertainmentHardKeywords);
    final nonAmbiguousStrong = _countNonAmbiguousKeywords(
      text,
      _strongKeywords['entertainment']!,
      _entertainmentAmbiguousKeywords,
    );
    return hardCount >= 1 || nonAmbiguousStrong >= 2;
  }

  static bool hasEntertainmentSoftKeywords({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    return _hasKeywords(text, _entertainmentSoftKeywords);
  }

  static bool hasInternationalKeywords({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    return _hasKeywords(text, _internationalHardKeywords) ||
        _hasKeywords(text, _strongKeywords['international']!);
  }

  static bool hasInternationalSoftKeywords({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    return _hasKeywords(text, _internationalSoftKeywords);
  }

  static bool hasNationalSoftKeywords({
    required String title,
    required String description,
    String? content,
  }) {
    final text = '$title $description ${content ?? ''}'.toLowerCase();
    return _hasKeywords(text, _nationalSoftKeywords) ||
        _hasKeywords(text, _bdSubnationalKeywords);
  }

  // ============================================================
  //  POST-PROCESSING VALIDATION
  // ============================================================

  /// Fix common categorization mistakes using rule-based post-processing
  static String validateAndFixCategory({
    required String detectedCategory,
    required String title,
    required String description,
    String? imageUrl,
  }) {
    final text = '$title $description'.toLowerCase();
    final hasIntlContext =
        _hasKeywords(text, _internationalHardKeywords) ||
        _hasKeywords(text, _strongKeywords['international']!);
    final hasIntlDominance = hasInternationalDominance(
      title: title,
      description: description,
    );
    final hasHardEntertainment = hasHardEntertainmentEvidence(
      title: title,
      description: description,
    );
    final hasGovernanceContext = _hasKeywords(text, _governanceContextKeywords);

    // Rule 1: Sports keywords override entertainment label
    if (detectedCategory == 'entertainment' &&
        _hasKeywords(text, _strongKeywords['sports']!) &&
        !_hasKeywords(text, _entertainmentCelebrities)) {
      return 'sports';
    }

    // Rule 2: West Bengal always international
    if (_hasKeywords(text, _westBengalKeywords)) {
      return 'international';
    }

    // Rule 3: National only flips to international with clear dominance.
    if (detectedCategory == 'national' && hasIntlContext && hasIntlDominance) {
      return 'international';
    }

    // Rule 3b: Sports misfire on geopolitical/international context
    if (detectedCategory == 'sports' &&
        hasIntlContext &&
        !_hasKeywords(text, _strongKeywords['sports']!)) {
      return 'international';
    }

    // Rule 4: BD district mention forces national (unless sports/entertainment/intl)
    if (_isBangladeshDistrict(text) &&
        !hasIntlContext &&
        detectedCategory != 'sports' &&
        detectedCategory != 'entertainment') {
      return 'national';
    }

    // Rule 5: Reject entertainment when hard proof is absent in governance news.
    if (detectedCategory == 'entertainment' &&
        (!hasHardEntertainment || hasGovernanceContext)) {
      return 'national';
    }

    return detectedCategory;
  }

  static bool _isBangladeshDistrict(String text) {
    for (final d in _bdSubnationalKeywords) {
      if (_containsKeyword(text, d)) return true;
    }
    return false;
  }

  // ============================================================
  //  UI METADATA
  // ============================================================

  static (String emoji, String label, int color) getCategoryMetadata(
    String category,
  ) {
    switch (category) {
      case 'national':
        return ('🇧🇩', 'National', 0xFF0061A4);
      case 'international':
        return ('🌍', 'International', 0xFF1ABC9C);
      case 'sports':
        return ('⚽', 'Sports', 0xFF2980B9);
      case 'entertainment':
        return ('🎬', 'Entertainment', 0xFFD35400);
      default:
        return ('📰', 'News', 0xFF34495E);
    }
  }
}
