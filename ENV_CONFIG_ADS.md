# Environment Configuration for Ads

## Required .env Variables

Add the following variables to your `.env` file:

```bash
# Interstitial Ad Unit IDs
# For testing, use Google's test ad unit ID (already set as default in code)
INTERSTITIAL_AD_UNIT_ID_TEST=ca-app-pub-3940256099942544/1033173712

# For production, replace with your actual AdMob interstitial ad unit ID
# Get this from your AdMob account: https://apps.admob.com
INTERSTITIAL_AD_UNIT_ID=your-production-ad-unit-id-here

# Note: The code will automatically use test ID if no production ID is set
```

## How to Get Your Production Ad Unit ID

1. Go to [AdMob Console](https://apps.admob.com)
2. Select your app (or create a new app if needed)
3. Navigate to **Ad units**
4. Create a new **Interstitial** ad unit
5. Copy the ad unit ID (format: `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY`)
6. Replace `your-production-ad-unit-id-here` with your actual ID

## Testing

During development, the app will use the test ad unit ID to show test ads.
These test ads look real but won't generate actual revenue or affect your AdMob account.

## Ad Display Behavior

- **Free Users**: See interstitial ads every 3rd article and on manual refresh (with 2-minute cooldown)
- **Premium Users**: Never see ads (automatic bypass via PremiumService)
