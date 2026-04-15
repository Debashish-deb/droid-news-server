import 'package:bdnewsreader/infrastructure/services/ml/categorization_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategorizationHelper Regression', () {
    test(
      'TC-CAT-000: Canonical Bangladesh district set contains all 64 districts',
      () {
        expect(CategorizationHelper.canonicalDistrictCount, 64);
      },
    );

    test('TC-CAT-001: West Bengal news is always international', () {
      final result = CategorizationHelper.categorizeByKeywords(
        title: 'Mamata addresses rally in Kolkata',
        description: 'West Bengal election campaign intensifies this week.',
      );

      expect(result.category, 'international');
      expect(result.confidence, greaterThanOrEqualTo(0.9));
    });

    test(
      'TC-CAT-002: Bangladesh mention with strong global context stays international',
      () {
        final result = CategorizationHelper.categorizeByKeywords(
          title: 'India and Bangladesh hold bilateral talks in Dhaka',
          description:
              'Indian foreign minister discusses regional security and trade.',
        );

        expect(result.category, 'international');
      },
    );

    test('TC-CAT-003: Domestic Bangladesh governance remains national', () {
      final result = CategorizationHelper.categorizeByKeywords(
        title: 'Bangladesh parliament passes national budget',
        description:
            'Dhaka session led by ministers focuses on domestic policy.',
      );

      expect(result.category, 'national');
    });

    test('TC-CAT-003B: Barishal regional news is recognized as national', () {
      final result = CategorizationHelper.categorizeByKeywords(
        title: 'Flood preparedness increased in Barishal',
        description: 'Local administration in বরিশাল issued emergency notice.',
      );

      expect(result.category, 'national');
    });

    test(
      'TC-CAT-003C: Hill tracts regional news is recognized as national',
      () {
        final result = CategorizationHelper.categorizeByKeywords(
          title: 'Road expansion approved in Rangamati and Bandarban',
          description:
              'পার্বত্য চট্টগ্রাম infrastructure project starts this quarter.',
        );

        expect(result.category, 'national');
      },
    );

    test(
      'TC-CAT-004: International label is not downgraded to national by Dhaka mention',
      () {
        final fixed = CategorizationHelper.validateAndFixCategory(
          detectedCategory: 'international',
          title: 'US envoy visits Dhaka for strategic talks',
          description: 'White House officials discuss regional cooperation.',
        );

        expect(fixed, 'international');
      },
    );

    test(
      'TC-CAT-005: Short-token false positives do not mark local news as international',
      () {
        final hasInternational = CategorizationHelper.hasInternationalKeywords(
          title: 'Showbiz event draws crowd in Dhaka',
          description: 'Local theater performance receives praise.',
        );

        expect(hasInternational, isFalse);
      },
    );

    test(
      'TC-CAT-006: Transliteration variants for districts are treated as national context',
      () {
        final result = CategorizationHelper.categorizeByKeywords(
          title: 'Water level rises in Jessore and Barisal river basins',
          description:
              'Local officials in Jhalokati and Netrokona issue warnings.',
        );

        expect(result.category, 'national');
      },
    );

    test(
      'TC-CAT-007: Smart categorization does not allow AI to override local rules',
      () async {
        const title = 'Bangladesh parliament approves new policy in Dhaka';
        const description =
            'Cabinet and ministry officials discussed domestic reforms.';

        final local = CategorizationHelper.categorizeByKeywords(
          title: title,
          description: description,
        );
        final smart = await CategorizationHelper.categorizeSmartly(
          title: title,
          description: description,
          collectAiSignals: false,
        );

        expect(smart.category, local.category);
      },
    );

    test(
      'TC-CAT-008: AI shadow collection is enabled only for home feed categories',
      () {
        expect(
          CategorizationHelper.shouldCollectAiSignalsForFeed('latest'),
          true,
        );
        expect(
          CategorizationHelper.shouldCollectAiSignalsForFeed('home'),
          true,
        );
        expect(
          CategorizationHelper.shouldCollectAiSignalsForFeed('mixed'),
          true,
        );

        expect(
          CategorizationHelper.shouldCollectAiSignalsForFeed('national'),
          false,
        );
        expect(
          CategorizationHelper.shouldCollectAiSignalsForFeed('international'),
          false,
        );
        expect(CategorizationHelper.shouldCollectAiSignalsForFeed(null), false);
      },
    );

    test('TC-CAT-009: Bengali entertainment soft markers are detected', () {
      final hasSoft = CategorizationHelper.hasEntertainmentSoftKeywords(
        title: 'নতুন সিনেমার ট্রেলার প্রকাশ, শোবিজ তারকাদের উচ্ছ্বাস',
        description: 'ওটিটি প্ল্যাটফর্মে মুক্তি পাবে জনপ্রিয় অভিনেত্রীর ছবি',
      );

      expect(hasSoft, isTrue);
    });

    test(
      'TC-CAT-010: Bengali entertainment headline categorizes as entertainment',
      () {
        final result = CategorizationHelper.categorizeByKeywords(
          title: 'চঞ্চল চৌধুরীর নতুন সিরিয়াল ওটিটিতে মুক্তি',
          description: 'ট্রেলার প্রকাশের পর শোবিজে আলোচনা তুঙ্গে',
        );

        expect(result.category, 'entertainment');
      },
    );

    test(
      'TC-CAT-011: Sports soft markers are detected and categorized correctly',
      () {
        final hasSoftSports = CategorizationHelper.hasSportsSoftKeywords(
          title: 'দুই দলের বনাম ম্যাচে হ্যাটট্রিক, পয়েন্ট টেবিলে বড় পরিবর্তন',
          description: 'নকআউট পর্বের আগে ফিক্সচার চূড়ান্ত',
        );
        final result = CategorizationHelper.categorizeByKeywords(
          title: 'দুই দলের বনাম ম্যাচে হ্যাটট্রিক',
          description: 'পয়েন্ট টেবিলে শীর্ষে ওঠার লড়াই চলছে',
        );

        expect(hasSoftSports, isTrue);
        expect(result.category, 'sports');
      },
    );

    test(
      'TC-CAT-012: International soft markers are detected and categorized correctly',
      () {
        final hasSoftInternational =
            CategorizationHelper.hasInternationalSoftKeywords(
              title: 'দ্বিপাক্ষিক কূটনীতি নিয়ে শীর্ষ সম্মেলন',
              description: 'পররাষ্ট্র মন্ত্রণালয় ও দূতাবাস যৌথ বিবৃতি দিয়েছে',
            );
        final result = CategorizationHelper.categorizeByKeywords(
          title: 'দ্বিপাক্ষিক কূটনীতি নিয়ে শীর্ষ সম্মেলন',
          description: 'দূতাবাস ও পররাষ্ট্র মন্ত্রণালয় বৈঠক করেছে',
        );

        expect(hasSoftInternational, isTrue);
        expect(result.category, 'international');
      },
    );

    test('TC-CAT-013: National soft markers are detected', () {
      final hasSoftNational = CategorizationHelper.hasNationalSoftKeywords(
        title: 'উপজেলা প্রশাসনের সভায় জেলা পরিষদের সুপারিশ',
        description: 'ইউনিয়ন পরিষদ ও সিটি করপোরেশনের সমন্বয় জোরদার',
      );

      expect(hasSoftNational, isTrue);
    });

    test(
      'TC-CAT-014: Entertainment celebrity context wins over sports overlap',
      () {
        final result = CategorizationHelper.categorizeByKeywords(
          title: 'শাকিব খান নতুন সিনেমার ট্রেলার প্রকাশ করলেন',
          description: 'শোবিজে অভিনেতার নতুন ছবির মুক্তি নিয়ে আলোচনা',
        );

        expect(result.category, 'entertainment');
      },
    );

    test(
      'TC-CAT-015: Sports event reporting wins when sports and entertainment terms overlap',
      () {
        final result = CategorizationHelper.categorizeByKeywords(
          title: 'World Cup match report: Messi scores in final',
          description: 'Post-match show celebrates championship win.',
        );

        expect(result.category, 'sports');
      },
    );

    test(
      'TC-CAT-016: Generic team/government wording does not force sports category',
      () {
        final result = CategorizationHelper.categorizeByKeywords(
          title: 'Government team visits flood-affected district',
          description: 'Local administration formed a response team in Dhaka.',
        );

        expect(result.category, 'national');
      },
    );

    test(
      'TC-CAT-017: ICC acronym in cricket context does not trigger international signal',
      () {
        final hasInternational = CategorizationHelper.hasInternationalKeywords(
          title: 'ICC announces new T20 schedule',
          description: 'Bangladesh cricket board welcomes the update.',
        );

        expect(hasInternational, isFalse);
      },
    );

    test(
      'TC-CAT-018: Governance story with interview/media wording stays national',
      () {
        final result = CategorizationHelper.categorizeByKeywords(
          title: 'জাতীয় সংসদে বাজেট নিয়ে সাক্ষাৎকার দিলেন অর্থমন্ত্রী',
          description:
              'সরকারি নীতিমালা ও স্থানীয় প্রশাসনের ভূমিকা নিয়ে আলোচনা',
        );

        expect(result.category, 'national');
      },
    );

    test(
      'TC-CAT-019: Bangladesh mention needs strong dominance to become international',
      () {
        final result = CategorizationHelper.categorizeByKeywords(
          title:
              'ঢাকায় বাংলাদেশ-ভারত বৈঠকে কৃষি ও জ্বালানি সহায়তা নিয়ে আলোচনা',
          description:
              'বাংলাদেশ সরকারের অগ্রাধিকার ও স্থানীয় বাস্তবায়ন পরিকল্পনা তুলে ধরা হয়',
        );

        expect(result.category, 'national');
      },
    );

    test('TC-CAT-020: Entertainment label requires hard showbiz evidence', () {
      final result = CategorizationHelper.categorizeByKeywords(
        title: 'মন্ত্রণালয়ের প্রেস কনফারেন্সে মিডিয়ার প্রশ্ন',
        description: 'নীতিমালা বাস্তবায়ন নিয়ে সাক্ষাৎকার দিয়েছেন সচিব',
      );

      expect(result.category, 'national');
    });
  });
}
