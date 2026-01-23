# API Documentation

## Overview

This document outlines the core services and providers in the application.

## Core Services

### `SyncService`

Handles synchronization between local database and remote server.

- `pushSettings()`: Pushes local settings to cloud.
- `pullSettings()`: Pulls settings from cloud.

### `SecurityService`

Manages application security.

- `initialize()`: Checks for root/jailbreak.
- `secureWrite(key, value)`: Encrypted storage.
- `authenticateWithBiometrics()`: Biometric login with fallback.

### `PaymentService`

Handles In-App Purchases.

- `purchaseStream`: Listens for purchase updates.
- `verifyPurchase()`: Validates receipts via Cloud Functions.

## Providers

### `ThemeProvider`

Manages application theme (Light, Dark, Bangladesh).

### `LanguageProvider`

Manages localization (English, Bengali).

## Error Handling

Global error handling via `ErrorHandler` and `FirebaseCrashlytics`.
