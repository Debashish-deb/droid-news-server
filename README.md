# BD News Reader

## Overview

BD News Reader is a comprehensive Flutter-based news application that delivers real-time news updates from Bangladesh and international sources. The app features a modern, intuitive interface with support for multiple themes, offline reading, and personalized news feeds.

### Key Features

- 📰 Real-time news updates from multiple RSS feeds
- 🌙 Multiple theme modes (Light, Dark, Bangladesh, AMOLED)
- 🌐 Bilingual support (English & Bengali)
- 📱 Offline reading with intelligent caching
- ⭐ Favorites and reading history
- 🔍 Search functionality
- 📖 Newspaper and magazine sections
- 🎯 Daily quizzes
- 🔐 User authentication via Firebase
- 💎 Premium features with in-app purchases

## Prerequisites

- **Flutter SDK**: 3.7.0 or higher
- **Dart SDK**: 3.7.0 or higher
- **Android Studio / VS Code** with Flutter/Dart plugins
- **Firebase Project**: Set up for authentication and cloud services
- **API Keys**: Required for news and weather services

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd droid
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment Variables

Create a `.env` file in the project root (copy from `.env.example`):

```bash
cp .env.example .env
```

Edit `.env` and add your API keys:

```env
APP_NAME=BD News Reader
NEWS_API_KEY=your_news_api_key_here
WEATHER_API_KEY=your_weather_api_key_here
```

### 4. Firebase Configuration

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add Android and iOS apps to your Firebase project
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Place configuration files in their respective directories:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
5. Run Firebase configuration generator:

```bash
flutterfire configure
```

### 5. Code Generation

Generate required code for Hive models:

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

## Running the App

### Development Mode

```bash
flutter run
```

### Specific Platform

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

## Building for Production

### Android (APK)

```bash
flutter build apk --release
```

### Android (App Bundle)

```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Project Structure

```
lib/
├── core/               # Core functionality
│   ├── constants.dart
│   ├── routes.dart
│   ├── theme.dart
│   ├── theme_provider.dart
│   └── utils/
├── data/               # Data layer
│   ├── models/
│   └── services/
├── features/           # Feature modules
│   ├── about/
│   ├── favorites/
│   ├── home/
│   ├── news/
│   ├── profile/
│   ├── settings/
│   └── ...
├── l10n/               # Internationalization
├── widgets/            # Shared widgets
└── main.dart           # App entry point
```

## Architecture

The app follows a feature-first architecture with clear separation of concerns:

- **Core**: Common utilities, themes, routing, and constants
- **Data**: Models and services for data fetching and caching
- **Features**: Self-contained feature modules with their own screens and widgets
- **State Management**: Provider for global state, StatefulWidget for local state

### Key Technologies

- **State Management**: Provider
- **Navigation**: go_router
- **Local Storage**: Hive
- **Networking**: http, dio
- **Caching**: flutter_cache_manager
- **Authentication**: Firebase Auth
- **Analytics**: Firebase Analytics (optional)
- **UI**: Material Design 3

## Testing

### Run All Tests

```bash
flutter test
```

### Run Specific Tests

```bash
flutter test test/unit/news_article_test.dart
```

### Code Coverage

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Linting

Run static analysis:

```bash
dart analyze .
```

Fix auto-fixable issues:

```bash
dart fix --apply
```

## Localization

The app supports English and Bengali. To add a new language:

1. Add translation file in `l10n/app_<locale>.arb`
2. Run code generation: `flutter gen-l10n`
3. Supported locales are defined in `l10n.yaml`

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style Guidelines

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `dart format` before committing
- Ensure all linter rules pass
- Add tests for new features
- Update documentation as needed

## Troubleshooting

### Common Issues

**Issue**: Build fails with "SDK version" error  
**Solution**: Ensure Flutter SDK version is 3.7.0 or higher

**Issue**: Firebase authentication not working  
**Solution**: Verify `google-services.json` and `GoogleService-Info.plist` are correctly placed

**Issue**: RSS feeds not loading  
**Solution**: Check internet connectivity and ensure RSS feed URLs are accessible

**Issue**: Hive errors on first run  
**Solution**: Run `flutter clean` and `flutter pub get`, then rebuild

## License

This project is proprietary software. All rights reserved © 2025 DreamSD Group.

## Support

For support and inquiries:

- **Email**: <customerservice@dsmobiles.com>
- **Website**: [www.dsmobiles.com](https://www.dsmobiles.com)

## Acknowledgments

- Flutter team for the amazing framework
- All open-source package contributors
- News sources for providing RSS feeds

---

**Version**: 1.0.1+24  
**Last Updated**: November 2025
