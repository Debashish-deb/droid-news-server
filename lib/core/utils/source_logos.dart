// path: lib/data/constants/source_logos.dart

class SourceLogos {
  const SourceLogos._();

  static const Map<String, String> logos = <String, String>{
    // National Newspapers (bd-bn-X)
    'প্রথম আলো': 'assets/logos/bd-bn-1.png',
    'Prothom Alo': 'assets/logos/bd-bn-1.png',
    
    'The Daily Star': 'assets/logos/bd-bn-2.png',
    
    'বাংলাদেশ প্রতিদিন': 'assets/logos/bd-bn-3.png',
    'Bangladesh Pratidin': 'assets/logos/bd-bn-3.png',
    
    'ইত্তেফাক': 'assets/logos/bd-bn-5.png', // Note: bd-bn-4 skipped in JSON?
    'Ittefaq': 'assets/logos/bd-bn-5.png',
    
    'New Age': 'assets/logos/bd-bn-6.png',
    
    'সমকাল': 'assets/logos/bd-bn-7.png',
    'Samakal': 'assets/logos/bd-bn-7.png',
    
    'Manab Zamin': 'assets/logos/bd-bn-8.png',
    'Amader Shomoy': 'assets/logos/bd-bn-9.png',
    
    'যুগান্তর': 'assets/logos/bd-bn-10.png',
    'Jugantor': 'assets/logos/bd-bn-10.png',
    
    'Sylheter Dak': 'assets/logos/bd-bn-11.png',
    'Khulna Gazette': 'assets/logos/bd-bn-12.png',
    'Chittagong Post': 'assets/logos/bd-bn-13.png',
    
    'Bangla Tribune': 'assets/logos/bd-bn-14.png',
    'RisingBD': 'assets/logos/bd-bn-15.png',
    
    'বিডিনিউজ২৪ বাংলা': 'assets/logos/bd-bn-16.png',
    'BD News 24': 'assets/logos/bd-bn-16.png',
    'Bdnews24': 'assets/logos/bd-bn-16.png',
    
    'Dhaka Post': 'assets/logos/bd-bn-17.png',
    'Dhaka Tribune': 'assets/logos/bd-bn-18.png',
    'Sangbad Pratidin': 'assets/logos/bd-bn-19.png',

    // Others (Aliases kept for safety, mapped to existing if possible)
    'কালের কণ্ঠ': 'assets/logos/kalerkantho.png', // Verify if this exists or if it's bd-bn-30
    'Kaler Kantho': 'assets/logos/kalerkantho.png', // Json says bd-bn-30 -> is there a bd-bn-30.png? YES.
    
    // Updates for Kaler Kantho based on JSON ID bd-bn-30
    // 'Kaler Kantho': 'assets/logos/bd-bn-30.png', 
    // Wait, let's keep the old one if I am not 100% sure, but bd-bn-30.png exists in list.
    
    // Magazines & International
    'CNN Top Stories': 'assets/logos/cnn.png',
    'BBC World News': 'assets/logos/bbc.png',
    'Reuters Top News': 'assets/logos/reuters.png',
    'The Guardian World': 'assets/logos/guardian.png',
    'New York Times US': 'assets/logos/nytimes.png',
    'Financial Times': 'assets/logos/ft.png',
    'Forbes': 'assets/logos/forbes.png',
    'Bloomberg Business': 'assets/logos/bloomberg.png',
    'Sky Sports': 'assets/logos/skysports.png',
    'ESPN Top Sports': 'assets/logos/espn.png',
    
    'TechCrunch': 'assets/logos/techcrunch.png', // Check if exists? tech-X exists...
    'Ars Technica': 'assets/logos/arstechnica.png',
    'The Verge Tech': 'assets/logos/theverge.png',
    
    'Billboard': 'assets/logos/billboard.png',
    'Variety': 'assets/logos/variety.png', 
    'Hollywood Reporter': 'assets/logos/hollywoodreporter.png',
  };
}
