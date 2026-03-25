# 📸 Marketing Screenshots Guide - Day 3-4

## Overview

Create 8 professional screenshots for app stores showcasing your best features.

---

## 🎯 Screenshot Strategy

### What Makes Great Screenshots

1. **Show benefits, not just features**
2. **Use real data** (not Lorem Ipsum)
3. **Highlight what's NEW** (offline, sharing)
4. **Bilingual appeal** (EN + বাংলা)
5. **Professional presentation** (frames, captions)

---

## 📱 Required Screenshots (8 Total)

### Screenshot 1: Home Feed Hero

**Purpose:** First impression, show beautiful news feed  
**Screen:** Home screen with articles  
**Settings:**

- Dark mode (more premium look)
- Mix of text/image articles
- Clean, organized layout

**Caption (EN):** "Stay Informed with Bangladesh News"  
**Caption (BN):** "বাংলাদেশের সংবাদে থাকুন আপডেট"

---

### Screenshot 2: Bilingual Feature

**Purpose:** Show language flexibility  
**Setup:** Split screen or side-by-side comparison  
**Settings:**

- Same article in EN and BN
- Language selector visible

**Caption (EN):** "Read in English or বাংলা"  
**Caption (BN):** "ইংরেজি বা বাংলায় পড়ুন"

---

### Screenshot 3: Offline Reading ⭐ NEW

**Purpose:** Showcase download feature  
**Screen:** Offline articles screen  
**Settings:**

- Show downloaded articles list
- Green offline badges visible
- Storage info displayed

**Caption (EN):** "Download & Read Offline Anytime"  
**Caption (BN):** "অফলাইনে যেকোনো সময় পড়ুন"

---

### Screenshot 4: Social Sharing ⭐ NEW

**Purpose:** Show sharing capabilities  
**Screen:** Share sheet open  
**Settings:**

- Article detail with share sheet
- All 6 platforms visible
- Modern, clean UI

**Caption (EN):** "Share News on 6 Platforms"  
**Caption (BN):** "৬টি প্ল্যাটফর্মে শেয়ার করুন"

---

### Screenshot 5: Beautiful Dark Mode

**Purpose:** Show premium themes  
**Screen:** Article detail in dark mode  
**Settings:**

- Bangladesh theme preferred
- Rich colors, good contrast
- Professional look

**Caption (EN):** "Eye-Friendly Dark Mode"  
**Caption (BN):** "চোখ-বান্ধব ডার্ক মোড"

---

### Screenshot 6: Search & Discover

**Purpose:** Show search functionality  
**Screen:** Search results  
**Settings:**

- Search bar with query
- Filtered results
- Clean layout

**Caption (EN):** "Find Any News Instantly"  
**Caption (BN):** "যেকোনো সংবাদ খুঁজুন দ্রুত"

---

### Screenshot 7: Privacy & Data Control

**Purpose:** Show GDPR compliance  
**Screen:** Privacy & Data screen  
**Settings:**

- All options visible
- Professional, trustworthy
- Clear controls

**Caption (EN):** "Your Data, Your Control"  
**Caption (BN):** "আপনার তথ্য, আপনার নিয়ন্ত্রণ"

---

### Screenshot 8: Premium Experience (Optional)

**Purpose:** Show value proposition  
**Screen:** Settings or premium features  
**Settings:**

- Premium theme visible
- No ads mention
- Clean interface

**Caption (EN):** "Premium Experience Available"  
**Caption (BN):** "প্রিমিয়াম অভিজ্ঞতা পাওয়া যায়"

---

## 🛠️ How to Take Screenshots

### Method 1: Using Android Emulator (Recommended)

**Step 1: Set Up Emulator**

```bash
# Start emulator
flutter emulators --launch <emulator_id>

# Or use Android Studio AVD Manager
```

**Step 2: Prepare Perfect Data**

- Log in with test account
- Add some favorites
- Download 2-3 articles for offline
- Set dark mode
- Open app to desired screen

**Step 3: Take Screenshots**

- Emulator → ... menu → Take screenshot
- Or use Android Studio: View → Tool Windows → Running Devices → Screenshot
- Save as PNG, high quality

**Step 4: Organize Files**

```
screenshots/
  raw/
    01_home_feed.png
    02_bilingual.png
    03_offline.png
    04_sharing.png
    05_dark_mode.png
    06_search.png
    07_privacy.png
    08_premium.png
```

### Method 2: Real Device

- Connect device via USB
- Enable USB debugging
- Use `adb screenshot` command
- Or use device's native screenshot (Power + Volume Down)

---

## 🎨 Screenshot Polish (Day 4)

### Tools Needed

- **Device Frame:** mockuphone.com or smartmockups.com
- **Caption Editor:** Canva or Figma
- **Background:** Subtle gradient

### Template Specs

- **Size:** 1080 x 1920 px (9:16 ratio)
- **Device Frame:** Pixel or Samsung
- **Background:** Green (#006A4E) to Red (#F42A41) gradient (subtle)
- **Caption Font:** Roboto Bold, 48px
- **Caption Position:** Bottom, 100px from edge
- **Margin:** 80px all sides

### Polishing Steps

1. **Add Device Frame:**
   - Upload raw screenshot to mockup tool
   - Choose modern phone frame
   - Center device
   - Export as PNG

2. **Add Caption:**
   - Open in Canva/Figma
   - Add text layer at bottom
   - Use Roboto Bold font
   - Add subtle shadow for readability
   - Bilingual: EN on left, BN on right

3. **Add Background:**
   - Subtle gradient (green to red, 10% opacity)
   - Or solid color with slight texture
   - Don't overpower the screenshot

4. **Final Check:**
   - Text readable at small sizes?
   - Colors not too bright?
   - Professional look?
   - Consistent across all 8?

---

## ✅ Quality Checklist

Before finalizing each screenshot:

- [ ] High resolution (1080x1920 minimum)
- [ ] Device frame looks modern
- [ ] Caption is clear and readable
- [ ] UI looks clean (no loading states)
- [ ] Colors are vibrant but not garish
- [ ] Text is legible at thumbnail size
- [ ] Shows actual app functionality
- [ ] Bilingual captions included
- [ ] Consistent style across all

---

## 📐 Technical Specifications

### Google Play

- **Phone:** 1080 x 1920 px (minimum)
- **Tablet:** 1920 x 1080 px (optional)
- **Format:** PNG or JPG
- **Count:** 2-8 screenshots
- **File size:** Max 8MB each

### App Store (iOS)

- **iPhone:** 1242 x 2688 px (6.5")
- **iPad:** 2048 x 2732 px (12.9")
- **Format:** PNG or JPG
- **Count:** 1-10 screenshots

---

## 🚀 Quick Start Commands

```bash
# 1. Run app with good data
flutter run --release

# 2. Navigate to each screen
# (Home, Offline, Share, etc.)

# 3. Take screenshots
# (Use emulator menu or adb)

# 4. Organize files
mkdir -p screenshots/raw screenshots/final

# 5. Polish in Canva/Figma
# (Add frames, captions, backgrounds)
```

---

## 💡 Pro Tips

1. **Use Dark Mode:** Looks more premium
2. **Real Content:** Use actual Bangladesh news
3. **Show Activity:** Not empty states
4. **Highlight NEW:** Offline & sharing are your differentiators
5. **Keep Consistent:** Same device frame, caption style
6. **Test Small:** Screenshots look good as thumbnails?

---

## 📊 Screenshot Priority

**Must Have (Core 5):**

1. Home Feed (hero shot)
2. Offline Reading (NEW!)
3. Social Sharing (NEW!)
4. Bilingual (unique)
5. Dark Mode (premium)

**Nice to Have (Optional 3):**
6. Search
7. Privacy
8. Premium

Start with the must-haves, then add more if time permits.

---

## ⏱️ Time Estimate

- **Day 3 Morning:** Set up, take raw screenshots (2 hours)
- **Day 3 Afternoon:** Organize, first polish pass (2 hours)
- **Day 4 Morning:** Final polish, captions (2 hours)
- **Day 4 Afternoon:** Review, export final PNGs (1 hour)

**Total: 7 hours over 2 days**

---

## 🎯 Success Criteria

Your screenshots are ready when:

- ✅ All 8 look professional
- ✅ Captions are bilingual
- ✅ Frames are consistent
- ✅ Features are clearly shown
- ✅ You'd download based on screenshots alone

**Then move to Day 5: App Store Optimization!**

---

Let me know when you're ready to start taking screenshots, and I can guide you through each one!
