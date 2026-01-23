# State Management Architecture

## Current State (Baseline)

### Overview

The app currently uses a **hybrid state management approach** with both **Provider** (legacy) and **Riverpod** (modern) implementations running in parallel.

### Provider Files

#### Theme Management (Dual Implementation)

1. **Legacy**: `lib/core/theme_provider.dart`
   - Uses `package:provider` (ChangeNotifier)
   - Manages `AppThemeMode` (system, light, dark, bangladesh, amoled)
   - Stores theme in SharedPreferences
   - Also handles reader preferences (line height, contrast)
   - Glass color calculations

2. **Riverpod**: `lib/presentation/providers/theme_providers.dart`
   - Modern Riverpod implementation
   - Provides `currentThemeModeProvider`, `glassColorProvider`, etc.
   - Type-safe, compile-time checked

**Current Pattern**:

- `main.dart` syncs Riverpod → Legacy Provider when theme changes
- Most screens still use Legacy Provider
- `AppDrawer` migrated to Riverpod (test case for migration)

**Files Using Legacy ThemeProvider** (20 total):

- `lib/main.dart` (sync logic)
- `lib/features/home/widgets/news_card.dart`
- `lib/features/quiz/daily_quiz_widget.dart` (6 instances)
- `lib/features/profile/profile_screen.dart`
- `lib/features/history/history_widget.dart`
- `lib/features/common/animated_background.dart`
- `lib/features/news_detail/animated_background.dart`
- `lib/features/news/newspaper_screen.dart` (2 instances)
- `lib/features/magazine/magazine_screen.dart`
- `lib/features/magazine/widgets/magazine_card.dart`
- `lib/features/news_detail/news_detail_screen.dart`
- `lib/features/profile/animated_background.dart`

#### Language Management (Dual Implementation)

1. **Legacy**: `lib/core/language_provider.dart`
   - ChangeNotifier pattern
   - Manages app locale

2. **Riverpod**: `lib/presentation/providers/language_providers.dart`
   - Modern implementation
   - Provides `currentLocaleProvider`

#### Other Providers

- `lib/core/news_provider.dart` - News fetching and caching
- `lib/presentation/providers/app_settings_providers.dart` - App settings
- `lib/presentation/providers/subscription_providers.dart` - Premium features
- `lib/presentation/providers/tab_providers.dart` - Bottom nav state
- `lib/presentation/providers/shared_providers.dart` - Shared state

**Total Provider Files**: 9

### Manager Layer

#### Current Managers (4 files)

1. **NetworkQualityManager** (`lib/core/network_quality_manager.dart`)
   - Detects network quality (WiFi, 4G, 3G, 2G)
   - Provides adaptive timeouts
   - Singleton pattern

2. **UnifiedSyncManager** (`lib/core/unified_sync_manager.dart`)
   - Syncs user data with Firebase
   - Manages favorites, reading history, settings
   - Complex orchestration logic

3. **FavoritesManager** (`lib/core/utils/favorites_manager.dart`)
   - Manages favorite articles
   - Firebase integration

4. **NetworkManager** (`lib/core/utils/network_manager.dart`)
   - Network connectivity status
   - Stream-based updates

**Overlap**: NetworkManager + NetworkQualityManager have related responsibilities

### Service Layer

Key services:

- `SecurityService` - Security features (biometrics, encryption)
- `RssService` - RSS feed fetching
- `AuthService` - Firebase authentication
- `PremiumService` - In-app purchases

---

## Problems with Current Architecture

### 1. Dual Providers

- **Complexity**: Two implementations for theme & language
- **Synchronization**: Requires manual sync in `main.dart`
- **Confusion**: Which provider to use?
- **Maintenance**: Changes must be made in two places

### 2. Manager Layer Overhead

- **Unnecessary abstraction**: Managers often just wrap services
- **Performance**: Extra layer adds latency
- **Complexity**: Hard to trace data flow

### 3. Provider → Manager → Service Pattern

**Current**:

```
Widget → Provider → Manager → Service → API
```

**Should be**:

```
Widget → Provider → Service → API
(or even Widget → Service directly when no state needed)
```

---

## Target Architecture (Post-Migration)

### Single State Management: Riverpod Only

**Theme**:

- ❌ Remove `lib/core/theme_provider.dart`
- ✅ Keep `lib/presentation/providers/theme_providers.dart`
- ✅ Migrate all 20 files to Riverpod

**Language**:

- ❌ Remove `lib/core/language_provider.dart`
- ✅ Keep `lib/presentation/providers/language_providers.dart`

### Simplified Manager Layer

**Consolidate 4 → 2**:

**Before**:

- NetworkQualityManager
- NetworkManager
- UnifiedSyncManager  
- FavoritesManager

**After**:

- `AppNetworkService` (combines network + quality detection)
- `AppDataService` (combines sync + favorites)

### Clear Responsibilities

**Providers**: State management only

- Theme state
- Language state
- Tab state
- Subscription state

**Services**: Business logic + API calls

- Network service (connectivity + adaptive timeouts)
- Data service (sync + favorites)
- Security service
- RSS service
- Auth service

**Widgets**: UI only

- Consume providers via `ref.watch()`
- Call services directly when no state needed

---

## Migration Strategy

### Phase 1: Theme Migration (Weeks 3-4)

1. Convert NewsCard to Riverpod
2. Convert quiz widgets (6 instances)
3. Convert profile/history screens
4. Convert animated backgrounds
5. Remove sync logic from main.dart
6. Delete legacy ThemeProvider

### Phase 2: Language Migration (Week 5)

1. Audit language provider usage
2. Migrate all consumers to Riverpod
3. Delete legacy LanguageProvider

### Phase 3: Manager Consolidation (Weeks 7-8)

1. Create `AppNetworkService`
2. Create `AppDataService`
3. Migrate consumers
4. Delete old managers

### Benefits

- **-40% provider code**
- **Cleaner architecture**
- **Type safety throughout**
- **Easier to maintain**
- **Better performance**

---

## Decision Log

### Why Riverpod over Provider?

1. **Type safety**: Compile-time checking
2. **No BuildContext**: Can use outside widgets
3. **Better testing**: Easy to mock
4. **Performance**: Fine-grained reactivity
5. **Future-proof**: Active development

### Why Remove Manager Layer?

1. **YAGNI**: Most managers are thin wrappers
2. **Performance**: Fewer layers = faster
3. **Clarity**: Direct service calls are clearer
4. **Maintenance**: Less code to maintain

### Why Gradual Migration?

1. **Risk mitigation**: Test each step
2. **Zero downtime**: App works during migration
3. **Rollback safety**: Can revert if issues
4. **Learning**: Team learns Riverpod patterns
