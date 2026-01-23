# Privacy Policy Hosting Guide

## Option 1: GitHub Pages (Free, Recommended)

### Steps

1. Create repository `bdnewsreader-legal` on GitHub
2. Create `index.html` with privacy policy content
3. Enable GitHub Pages in repository settings
4. URL will be: `https://yourusername.github.io/bdnewsreader-legal/privacy.html`

### Quick Setup

```bash
# Create repo and files
mkdir bdnewsreader-legal
cd bdnewsreader-legal
git init

# Convert markdown to HTML (simple version)
cat > privacy.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - BD News Reader</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
        }
        h1 { color: #333; }
        h2 { color: #555; margin-top: 30px; }
    </style>
</head>
<body>
    <!-- Paste privacy policy content here -->
</body>
</html>
EOF

# Push to GitHub
git add .
git commit -m "Add privacy policy"
git remote add origin https://github.com/yourusername/bdnewsreader-legal.git
git push -u origin main

# Enable GitHub Pages in repo settings → Pages → Source: main branch
```

---

## Option 2: Firebase Hosting (Free)

### Steps

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize hosting
firebase init hosting

# Create public/privacy.html with content
mkdir public
# Copy HTML version of privacy policy to public/privacy.html

# Deploy
firebase deploy --only hosting

# URL: https://your-project.firebase app.com/privacy.html
```

---

## Option 3: Simple HTML File on Any Web Server

### Create `privacy.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - BD News Reader</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
            color: #333;
        }
        h1 {
            color: #006A4E;
            border-bottom: 3px solid #F42A41;
            padding-bottom: 10px;
        }
        h2 {
            color: #555;
            margin-top: 30px;
        }
        a {
            color: #006A4E;
        }
        .update-date {
            color: #666;
            font-style: italic;
        }
    </style>
</head>
<body>
    <h1>Privacy Policy</h1>
    <p class="update-date">Last Updated: January 12, 2026</p>
    
    <!-- Copy privacy policy content from docs/PRIVACY_POLICY.md -->
    
    <h2>Introduction</h2>
    <p>BD News Reader ("we", "our", "us") respects your privacy...</p>
    
    <!-- Continue with rest of privacy policy -->
    
    <hr>
    <p><small>BD News Reader v1.0 © 2026</small></p>
</body>
</html>
```

Upload to: `www.yourdomain.com/privacy.html`

---

## Update App to Use Hosted URL

### In `lib/features/settings/privacy_data_screen.dart`

```dart
Future<void> _openPrivacyPolicy() async {
  // Replace with your actual hosted URL
  const url = 'https://yourusername.github.io/bdnewsreader-legal/privacy.html';
  // OR
  // const url = 'https://your-project.firebaseapp.com/privacy.html';
  // OR
  // const url = 'https://www.yourdomain.com/privacy.html';
  
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalBrowser);
  }
}

Future<void> _openTermsOfService() async {
  const url = 'https://yourusername.github.io/bdnewsreader-legal/terms.html';
  
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalBrowser);
  }
}
```

---

## Recommended: GitHub Pages

**Pros:**

- ✅ Free
- ✅ Fast setup (5 minutes)
- ✅ Custom domain support
- ✅ HTTPS included
- ✅ No maintenance

**Steps:**

1. Create GitHub repo
2. Add `privacy.html` and `terms.html`
3. Enable Pages in settings
4. Update URLs in app
5. Done!

**Example URL Structure:**

```
https://yourusername.github.io/bdnewsreader-legal/
├── privacy.html
└── terms.html
```

---

## Testing

After hosting:

1. Open URL in browser - should display policy
2. Test from app - tap "Privacy Policy" in settings
3. Should open in external browser
4. Verify on both Android and iOS

---

## App Store Requirements

Both Google Play and App Store require:

- Privacy policy must be publicly accessible
- URL must be provided during submission
- Policy must describe all data collection
- Must be easily accessible from app

**Your privacy policy URL will be needed when submitting to app stores!**
