# AdMob Monetization Setup Guide

## 🎯 Quick Start (30 minutes)

### Step 1: Get AdMob App ID (5 min)

1. Go to [AdMob Console](https://apps.admob.com)
2. Sign in with Google account
3. Click **"Apps"** → **"Add App"**
4. Select **"Yes, it's listed on a supported app store"** (or No if pre-launch)
5. Enter:
   - Platform: Android / iOS
   - App name: "BD News Reader"
   - (If listed) Link to store listing
6. **Copy the App ID** (format: `ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`)

---

### Step 2: Create Ad Units (10 min)

#### Banner Ads

1. In AdMob Console → Apps → Your App → Ad units
2. Click **"Add Ad Unit"**
3. Select **"Banner"**
4. Name: "Home Feed Banner"
5. **Copy the Ad Unit ID** (format: `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`)

#### Interstitial Ads

1. Add Ad Unit → **"Interstitial"**
2. Name: "Article Read Interstitial"
3. **Copy the Ad Unit ID**

#### (Optional) Native Ads

1. Add Ad Unit → **"Native"**
2. Name: "Feed Native Ad"
3. **Copy the Ad Unit ID**

---

### Step 3: Configure App (10 min)

#### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<manifest...>
    <application...>
        <!-- AdMob App ID -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
    </application>
</manifest>
```

#### iOS (`ios/Runner/Info.plist`)

```xml
<dict>
    <!-- AdMob App ID -->
    <key>GADApplicationIdentifier</key>
    <string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>
</dict>
```

---

### Step 4: Update Ad Unit IDs in Code

#### Create `lib/core/config/ad_config.dart`

```dart
class AdConfig {
  // AdMob App IDs
  static const String androidAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';
  static const String iosAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';
  
  // Banner Ad Unit IDs
  static const String androidBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String iosBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  
  // Interstitial Ad Unit IDs
  static const String androidInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String iosInterstitialId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  
  // Native Ad Unit IDs (optional)
  static const String androidNativeId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String iosNativeId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  
  // Get platform-specific IDs
  static String get bannerId {
    return Platform.isAndroid ? androidBannerId : iosBannerId;
  }
  
  static String get interstitialId {
    return Platform.isAndroid ? androidInterstitialId : iosInterstitialId;
  }
  
  static String get nativeId {
    return Platform.isAndroid ? androidNativeId : iosNativeId;
  }
  
  // Test mode (use test IDs during development)
  static const bool useTestAds = false; // Set to false for production
  
  // Test Ad IDs (provided by Google)
  static const String testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testNativeId = 'ca-app-pub-3940256099942544/2247696110';
}
```

---

### Step 5: Test Ads (5 min)

```dart
// Set useTestAds = true in AdConfig
// Run app
flutter run

// You should see test ads with "Test Ad" label
// Click the ads to verify they work
```

**Important:** Never click your own production ads! Use test IDs during development.

---

## 💰 Monetization Strategy

### Recommended Ad Placement

#### 1. Banner Ads

**Where:** Bottom of feed, every 10th item
**Frequency:** 1 every 5-10 articles
**Revenue:** $0.20-$0.50 per 1000 impressions (CPM)

#### 2. Interstitial Ads  

**When:** After reading 2-3 articles
**Frequency:** Max 1 every 3-5 minutes
**Revenue:** $2-$5 per 1000 impressions (CPM)

#### 3. Native Ads (Optional)

**Where:** Inline with feed (looks like article cards)
**Frequency:** 1 every 15-20 items
**Revenue:** $1-$3 per 1000 impressions (CPM)

### Don't Over-Monetize ⚠️

- Too many ads = poor user experience = uninstalls
- Balance revenue with retention
- Offer ad-free premium option

---

## 📊 Expected Revenue

### Assumptions

- 10,000 DAU (daily active users)
- 5 ad impressions per user per day
- Average eCPM: $1.50

**Calculation:**

```
Daily Revenue = (10,000 users × 5 impressions × $1.50 CPM) / 1000
              = $75/day
              = ~$2,250/month
```

### Revenue Tiers

| DAU | Monthly Revenue (est.) |
|-----|------------------------|
| 1,000 | $225 |
| 5,000 | $1,125 |
| 10,000 | $2,250 |
| 50,000 | $11,250 |
| 100,000 | $22,500 |

---

## 🎁 Premium Subscription (Optional)

### Benefits

✓ Ad-free experience
✓ Unlimited offline saves
✓ Priority notifications
✓ Early access to new features
✓ Support app development

### Pricing

- **Monthly:** $2.99/month
- **Yearly:** $24.99/year (save 30%)

### Implementation

Already exists in app! Just need to configure:

1. Set up products in Play Console
2. Set up products in App Store Connect
3. Test purchase flow
4. Enable premium features

---

## 🧪 Testing Checklist

- [ ] Test ads load in development (test IDs)
- [ ] Banner ads display correctly
- [ ] Interstitial ads show after reading articles
- [ ] Ads don't cover important content
- [ ] Premium users see no ads
- [ ] Ads respect user consent (GDPR)
- [ ] Revenue tracking in AdMob Console

---

## 📈 Optimization

### Monitor These Metrics

- **eCPM:** Earnings per 1000 impressions
- **Fill Rate:** % of ad requests filled
- **CTR:** Click-through rate
- **Impression RPM:** Revenue per 1000 impressions

### Improve Revenue

1. **Mediation:** Add multiple ad networks (Facebook, Unity, AppLovin)
2. **Ad Review Center:** Block low-quality ads
3. **Targeting:** Enable personalized ads (with consent)
4. **Placement:** A/B test ad positions
5. **Format Testing:** Try different ad sizes

---

## 🔐 Privacy & Compliance

### GDPR (Europe)

- Show consent dialog before loading ads
- Allow users to opt-out of personalized ads
- Provide privacy policy

### CCPA (California)

- Provide "Do Not Sell My Data" option
- Update privacy policy

**Recommended:** Use [Funding Choices](https://fundingchoices.google.com) for GDPR consent

---

## 🚀 Production Launch

### Before Publishing

1. Set `useTestAds = false` in `AdConfig`
2. Update all ad unit IDs to production IDs
3. Test one more time with real (but limited) ads
4. Submit to app stores

### After Launch

1. Monitor AdMob console daily
2. Check for policy violations
3. Optimize ad placement based on data
4. Consider adding more ad networks

---

## 💡 Pro Tips

1. **Don't show ads on first app open** - let users explore first
2. **Frequency cap interstitials** - max 1 every 5 minutes
3. **Respect premium users** - strictly no ads for paid users
4. **Test on real devices** - emulators don't show  real ads
5. **Monitor retention** - if it drops, reduce ad frequency

---

## 🆘 Troubleshooting

**Ads not showing:**

- Check internet connection
- Verify ad unit IDs are correct
- Ensure AdMob app is approved
- Check for policy violations in AdMob console

**Low revenue:**

- Increase ad impressions (carefully)
- Enable mediation
- Try different ad formats
- Check ad quality in AdMob

**App rejected:**

- Review app store ad policies
- Ensure ads don't interfere with content
- Add proper disclosures

---

**AdMob Console:** <https://apps.admob.com>  
**Documentation:** <https://developers.google.com/admob/flutter>

**Ready to monetize! 💰**
