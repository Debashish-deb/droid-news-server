# BD News Reader (Enterprise Edition)

[![Flutter](https://img.shields.io/badge/Flutter-3.41.1%2B-blue.svg)](https://flutter.dev)
[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](https://dsmobiles.com)
[![Version](https://img.shields.io/badge/version-4.0.0-gold.svg)](https://github.com/DreamSD-Group/droid-news-server)

**BD News Reader** is a next-generation news intelligence platform. It defines the standard for secure, offline-first mobile architecture by combining **On-Device AI**, **Zero-Trust Security**, and **Event Sourced Data Sync**.

---

## 🚀 Key Features (v4.0.0 Enterprise Gold)

### 🔐 Zero-Trust Security (New)

- **Device Trust Engine**: Real-time validation of device integrity (Root/Emulator detection).
- **Secure Identity**: Hardware-backed Session binding ensuring one user = one trusted device.
- **Fraud Detection**: High-velocity signal collection to prevent abuse.

### 🔄 Enterprise Data Layer (New)

- **Event Sourcing**: Every action (Read, Favorite) is an immutable event in a transactional Journal.
- **Drift/SQLite**: Replaced legacy NoSQL with relational SQLCipher-encrypted storage for 100% data consistency.
- **Conflict Resolution**: Vector Clock primitives for distributed data handling.

### 🧠 On-Device AI Personalization

- **Smart Ranking**: Quantized TF-IDF engine ranks news based on your reading history without sending data to the cloud.
- **Smart Clustering**: Automatically groups related stories in real-time.

### 👓 Premium Experience

- **Ad-Free Mode**: Network-level blocking of ad trackers.
- **Magazine UI**: Intelligent typography and focus mode.

---

## 🛠️ Tech Stack

- **Core**: Flutter 3.41.1+, Dart 3.10+
- **Architecture**: Clean Architecture (Modules: `platform`, `domain`, `infrastructure`, `presentation`)
- **State Management**: Riverpod 2.6+
- **Persistence**: Drift (SQLite) + Hive (Cache)
- **Platform**: `lib/platform` independent Core Services
- **AI**: Custom Dart Vector Space Model

---

## 🏁 Getting Started

### Prerequisites

- Flutter SDK >= 3.41.1
- Android Studio Chipmunk+ / Xcode 14+

### Installation

1. **Clone & Install**

    ```bash
    git clone <repo>
    cd droid
    flutter pub get
    ```

2. **Generate Enterprise Code** (Drift & Freezed)

    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

    *Note: This is required to generate the `AppDatabase` and `Feature` classes.*

3. **Run the App**

    ```bash
    flutter run
    ```

---

## 📚 Documentation

**[READ THE BOOK](docs/Technical_Reference_Book.md)**

For a complete breakdown of the Enterprise Architecture (Identity, Entitlements, Sync Engine), refer to the **[Technical Reference Book](docs/Technical_Reference_Book.md)** in the `docs/` folder. This document serves as the definitive comprehensive guide for the project.

---

**© 2026 DreamSD Group.** All Rights Reserved.
