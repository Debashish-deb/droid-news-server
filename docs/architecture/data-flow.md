# Data Flow Architecture

## Current Data Flow Patterns

### News Fetching Flow

```
User Opens App
    ↓
HomeScreen (widget)
    ↓
NewsProvider (provider)
    ↓
RssService (service)
    ↓
RetryHelper (util)
    ↓
HTTP Client (with SSL pinning)
    ↓
RSS Feed (external)
    ↓
Parse in Isolate
    ↓
NewsArticle models
    ↓
Cache in memory
    ↓
Display in NewsCard
```

**Key Components**:

- `NewsProvider`: State management, caching
- `RssService`: RSS fetching, parsing
- `RetryHelper`: Retry logic (3 attempts)
- `NetworkQualityManager`: Adaptive timeouts
- `CachedNetworkImage`: Image caching

---

### Theme Change Flow

```
User Changes Theme (Settings)
    ↓
Settings Widget
    ↓
ThemeNotifier.setTheme() (Riverpod)
    ↓
Save to SharedPreferences
    ↓
Notify listeners
    ↓
main.dart Consumer watches change
    ↓
Sync to Legacy Provider (temporary!)
    ↓
MaterialApp rebuilds
    ↓
All screens update theme
```

**Problem**: Dual sync is a band-aid. Should be single source of truth.

---

### Authentication Flow

```
User Clicks Login
    ↓
LoginScreen
    ↓
AuthService.login()
    ↓
Firebase Authentication
    ↓
Get user profile
    ↓
Sync user data (UnifiedSyncManager)
    ↓
Update favorites (FavoritesManager)
    ↓
Store in SecureStorage
    ↓
Navigate to home
```

**Orchestration**: Too many managers involved

---

### Favorites Flow

```
User Favorites Article
    ↓
NewsCard.onFavorite()
    ↓
FavoritesManager.toggleFavorite()
    ↓
Update local state
    ↓
Sync to Firebase
    ↓
UnifiedSyncManager.syncFavorites()
    ↓
Update ProfileScreen
```

**Issue**: FavoritesManager + UnifiedSyncManager overlap

---

## Simplified Target Flow

### News Fetching (Simplified)

```
HomeScreen
    ↓
ref.watch(newsProvider)
    ↓
RssService.fetchNews()
    ↓
HTTP + Retry
    ↓
NewsArticle[]
```

**Removed**: Unnecessary manager layers

---

### Theme Change (Simplified)

```
Settings
    ↓
ref.read(themeNotifier).setTheme()
    ↓
SharedPreferences
    ↓
ALL screens auto-update (Riverpod)
```

**Removed**: Legacy Provider, sync logic

---

### Favorites (Simplified)

```
NewsCard
    ↓
AppDataService.toggleFavorite()
    ↓
Firebase + Local Cache
    ↓
Stream updates UI
```

**Removed**: Separate favorites manager

---

## Data Sources

### Local Storage

- **SharedPreferences**: Theme, language, settings
- **Flutter Secure Storage**: Auth tokens, sensitive data
- **In-Memory Cache**: News articles, images

### Remote

- **Firebase Authentication**: User auth
- **Firebase Firestore**: User data, favorites
- **RSS Feeds**: News content
- **Firebase Storage**: User images

---

## Caching Strategy

### News Articles

- **In-memory**: Current session
- **Offline**: Show cached on network failure
- **TTL**: Refresh every 30 minutes

### Images

- **CachedNetworkImage**: Disk + memory cache
- **Adaptive quality**: Lower quality on slow networks

### User Data

- **Optimistic UI**: Update immediately, sync in background
- **Conflict resolution**: Last write wins

---

## Error Handling

### Network Errors

```
HTTP Request
    ↓
Timeout? → Retry (max 3)
    ↓
Still failing? → Show cached data
    ↓
No cache? → Show error UI
```

### Authentication Errors

```
Auth Request
    ↓
Invalid token? → Refresh token
    ↓
Still invalid? → Force re-login
    ↓
Show login screen
```

### Sync Errors

```
Sync Request
    ↓
Conflict? → Merge strategies
    ↓
Network error? → Queue for later
    ↓
Show sync status to user
```

---

## Performance Optimization Points

### Critical Paths (Optimize First)

1. **Cold start** → Home screen
2. **News refresh** → Display articles
3. **Theme change** → Update UI
4. **Navigation** → Screen transitions

### Optimization Techniques

- **Lazy loading**: Defer heavy operations
- **Isolates**: Parse RSS in background
- **Caching**: Aggressive caching
- **Const widgets**: Avoid rebuilds
- **Image optimization**: Memory limits
