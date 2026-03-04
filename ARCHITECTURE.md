# AI Khata — Full App Architecture & Screen Reference

> **What this document is:** A complete, screen-by-screen, flow-by-flow reference for the entire AI Khata app — Flutter front-end, Node.js back-end, AI system, database schema, and all the rules that hold it together. If you want to understand what happens when a user taps anything, this is the document.
>
> Last updated: **3 March 2026**

---

## Table of Contents

1. [What the App Does](#1-what-the-app-does)
2. [Tech Stack](#2-tech-stack)
3. [Design System](#3-design-system)
4. [Project Structure](#4-project-structure)
5. [Navigation & Routing](#5-navigation--routing)
6. [State Management](#6-state-management)
7. [API Client & Auth Token Flow](#7-api-client--auth-token-flow)
8. [Screen-by-Screen Reference](#8-screen-by-screen-reference)
   - [8.1 Login / Register](#81-login--register)
   - [8.2 Onboarding (3 Screens)](#82-onboarding-3-screens)
   - [8.3 Dashboard — Home Tab](#83-dashboard--home-tab)
   - [8.4 Smart Advice Tab](#84-smart-advice-tab)
   - [8.5 Inventory Tab](#85-inventory-tab)
   - [8.6 Bills Screen](#86-bills-screen)
   - [8.7 Bill Scanner Screen](#87-bill-scanner-screen)
   - [8.8 Manual Bill Entry Screen](#88-manual-bill-entry-screen)
   - [8.9 Ledger / Records Screen](#89-ledger--records-screen)
9. [Backend Architecture](#9-backend-architecture)
   - [9.1 Server Setup](#91-server-setup)
   - [9.2 Route Map](#92-route-map)
   - [9.3 Auth Module](#93-auth-module)
   - [9.4 Stores Module](#94-stores-module)
   - [9.5 Bills Module](#95-bills-module)
   - [9.6 Ledger Module](#96-ledger-module)
   - [9.7 Analytics Module](#97-analytics-module)
   - [9.8 Stocks & Order Items Modules](#98-stocks--order-items-modules)
   - [9.9 AI Module](#99-ai-module)
10. [The AI System (Deep Dive)](#10-the-ai-system-deep-dive)
    - [10.1 Insight Types](#101-insight-types)
    - [10.2 When AI Runs](#102-when-ai-runs)
    - [10.3 Worker: refreshInsights.js](#103-worker-refreshinsightsjs)
    - [10.4 Anti-Hallucination Rules](#104-anti-hallucination-rules)
    - [10.5 Gemini Prompt (Context-Aware Guidance)](#105-gemini-prompt-context-aware-guidance)
    - [10.6 The Golden Rule: App Never Calls AI](#106-the-golden-rule-app-never-calls-ai)
    - [10.7 RAG Memory System](#107-rag-memory-system)
    - [10.8 RAG Learning Phase](#108-rag-learning-phase)
    - [10.9 Relationship Discovery](#109-relationship-discovery)
    - [10.10 Experience Engine (Retrieval + Generation)](#1010-experience-engine-retrieval--generation)
    - [10.11 RAG Data Flow End-to-End](#1011-rag-data-flow-end-to-end)
    - [10.12 Confidence & Frequency Model](#1012-confidence--frequency-model)
11. [Database Schema](#11-database-schema)
12. [Key Business Rules & Constraints](#12-key-business-rules--constraints)

---

## 1. What the App Does

AI Khata is a **smart bookkeeping app for small Indian shopkeepers** (kirana owners, pharmacists, etc.). The core premise: a shop owner scans or types a bill, and the app automatically tracks sales, manages stock levels, and delivers AI-generated business advice — all without needing any accounting knowledge.

**Core daily loop:**

```
Add a Bill (scan / type) → Ledger updated → AI analyses data overnight →
Shop owner sees advice on what to order, what to expect next month,
which festivals are coming — and acts on it with one tap.
```

**Three tabs, three jobs:**

- **Home** → See today's numbers and the most urgent AI actions
- **Smart Advice** → Context-aware guidance cards: stock health, trends, festival prep — all data-driven, no numerical predictions
- **Inventory** → See what's in stock, what to order, confirm orders

---

## 2. Tech Stack

### Flutter App

| Layer        | Technology                                                  |
| ------------ | ----------------------------------------------------------- |
| UI Framework | Flutter (Material 3, dark theme)                            |
| Navigation   | `go_router` v2 with `ShellRoute`                            |
| State        | `provider` — `MultiProvider`, `ChangeNotifierProxyProvider` |
| HTTP         | `dio` with JWT interceptor + silent refresh                 |
| Storage      | `shared_preferences` (session tokens)                       |
| Image pick   | `image_picker` (camera + gallery)                           |
| Config       | `flutter_dotenv` (base URL from `.env`)                     |
| Fonts        | Inter (via Google Fonts)                                    |

### Backend

| Layer      | Technology                                           |
| ---------- | ---------------------------------------------------- |
| Runtime    | Node.js / Express                                    |
| Database   | PostgreSQL (via `pg` connection pool)                |
| Container  | Docker Compose                                       |
| Port       | 3000 (internal), exposed on host                     |
| AI Model   | Amazon Nova (primary), Groq / Llama 3.1 (fallback) |
| AI Workers | Node.js `worker_threads` (non-blocking)              |
| Auth       | JWT (access + refresh token pair)                    |

---

## 3. Design System

### Colour Palette

The app uses a **light theme** (`AppTheme.light`). Accessed via `theme: AppTheme.light` in `MaterialApp`.

```dart
// lib/core/theme.dart — AppTheme static consts
primary         = #F57C00  // Saffron orange — all CTAs, active states, icons
primarySurface  = #FFF3E0  // Warm white-orange tint behind primary elements

background      = #FFFFFF  // App background
surface         = #F5F5F5  // Input fields, secondary containers
card            = #FFFFFF  // All cards and bottom sheets
cardElevated    = #F0F0F0  // Slightly elevated card variant
divider         = #E8E8E8  // Hairline separators

textPrimary     = #1A1A1A  // Main body text, headings
textSecondary   = #757575  // Supporting text, labels
textHint        = #BDBDBD  // Placeholder, disabled text

success         = #2ECC71  // Income, healthy stock, done states
warning         = #F4B400  // Low stock, medium urgency
error           = #FF5252  // Out of stock, expense, high urgency alerts
```

### Typography

All text uses **Inter**. Weights used in practice:

- `w800` — Large monetary values, hero numbers
- `w700` — Card titles, section headers, button labels
- `w600` — Status labels, secondary headers
- `w500` — Regular card content
- Normal — Hint text, descriptions

### Component Language

- **Border radius:** 8–20dp depending on component size (inputs: 12, cards: 16–20, sheets: top 24)
- **All major cards** have a subtle left border (3.5dp) coloured by status when in a list
- **Bottom sheets** use `AppTheme.card` background, top handle bar, keyboard-aware padding
- **Buttons:** `ElevatedButton` for primary actions (saffron fill), `OutlinedButton` for secondary, `FilledButton` for confirmations
- **Status chips** always use `color.withOpacity(0.1)` background + `color` text (never solid fill)

### Emoji & Icon Policy

Emojis are **not used** in the UI. All status indicators and decorative markers use Material `Icon` widgets with semantic colour:

| Purpose             | Widget                            | Icon                                 |
| ------------------- | --------------------------------- | ------------------------------------ |
| Urgency — high      | `Icon` + `AppTheme.error`         | `Icons.warning_rounded`              |
| Urgency — medium    | Coloured dot `Container`          | `BoxShape.circle`                    |
| Best seller         | `Icon` + `AppTheme.warning`       | `Icons.star_rounded`                 |
| Low stock           | `Icon` + `AppTheme.warning`       | `Icons.warning_amber_rounded`        |
| Healthy stock       | `Icon` + `AppTheme.success`       | `Icons.check_circle_outline_rounded` |
| Forecast up         | `Icon` + `AppTheme.success`       | `Icons.trending_up_rounded`          |
| Forecast down       | `Icon` + `AppTheme.textSecondary` | `Icons.trending_down_rounded`        |
| Tip / insight       | `Icon` + `AppTheme.textSecondary` | `Icons.lightbulb_outline_rounded`    |
| Event / festival    | `Icon` + `AppTheme.primary`       | `Icons.event_rounded`                |
| Section — events    | `Icon`                            | `Icons.event_outlined`               |
| Section — forecast  | `Icon`                            | `Icons.analytics_outlined`           |
| Section — inventory | `Icon`                            | `Icons.inventory_2_outlined`         |

---

## 4. Project Structure

```
ai_khata/lib/
├── main.dart                   ← App entry, providers, go_router config
├── core/
│   ├── theme.dart              ← AppTheme (all colours, ThemeData)
│   ├── api_client.dart         ← Dio singleton, JWT interceptor, refresh logic
│   └── constants.dart          ← Route name constants (AppConstants)
└── features/
    ├── auth/
    │   └── auth_service.dart   ← AuthService (ChangeNotifier, session management)
    ├── onboarding/
    │   └── onboarding_screens.dart
    ├── dashboard/
    │   └── dashboard_screen.dart   ← Shell + home content (1208 lines)
    ├── insights/
    │   └── insights_screen.dart    ← Smart Advice tab — guidance cards (stock_check, pattern, event_context, info)
    ├── stocks/
    │   ├── stock_screen.dart       ← Inventory tab (968 lines)
    │   └── order_list_provider.dart← OrderListProvider (ChangeNotifier)
    ├── bills/
    │   └── bills_screens.dart      ← Bills list + scanner + manual (953 lines)
    └── ledger/
        └── ledger_screen.dart      ← Transaction history (346 lines)

AI_Khata_backend/src/
├── index.js          ← Express app, route mounting, server startup
├── config/
│   ├── database.js   ← pg Pool
│   ├── env.js        ← dotenv loader
│   ├── nova.js       ← callNova() with Groq fallback
│   ├── groq.js       ← Groq/Llama client
│   ├── init.sql      ← Full DB schema (CREATE TABLE IF NOT EXISTS)
│   └── initDb.js     ← One-off schema runner
├── auth/             ← JWT auth (login, register, refresh, logout, middleware)
├── stores/           ← Store setup
├── bills/            ← OCR upload + manual entry
├── ledger/           ← Ledger entries CRUD
├── analytics/        ← Sales trend + product ranking queries
├── ai/               ← Insights cache GET + jobs endpoints + scheduler
├── stocks/           ← Stock items CRUD
├── order_items/      ← Order list CRUD
├── utils/
│   └── stockSync.js        ← Shared inventory-sync logic (manual bills + OCR)
└── workers/
    ├── refreshInsights.js  ← AI worker (single guidance prompt from DB data)
    ├── ocrWorker.js        ← Bill OCR → ledger + stock sync
    ├── forecastWorker.js   ← (legacy/unused — refreshInsights handles this)
    └── inventoryWorker.js  ← (legacy/unused — refreshInsights handles this)
```

---

## 5. Navigation & Routing

All routing is handled by **go_router** configured in `main.dart`.

### Route Tree

```
/login                          → LoginScreen (no auth required)

/onboarding/type                → StoreTypeScreen
/onboarding/details             → StoreDetailsScreen  (storeType passed as extra)
/onboarding/done                → OnboardingDoneScreen

/dashboard                      ← ShellRoute (bottom nav bar, 3 tabs)
  ├── /                         → DashboardHomeContent  (tab index 0)
  ├── /dashboard/advice         → InsightsScreen         (tab index 1)
  └── /dashboard/inventory      → StockScreen            (tab index 2)

  (secondary routes — pushed over shell, bottom nav hidden)
  ├── /dashboard/bills          → BillsScreen
  ├── /dashboard/records        → LedgerScreen
  ├── /dashboard/bills/scan     → BillScannerScreen
  └── /dashboard/bills/manual   → BillManualEntryScreen
```

### Redirect Logic

The go_router `redirect` runs on every navigation:

```
Not logged in (no token)                → /login
Logged in, onboarding NOT complete      → /onboarding/type
Logged in, onboarding complete,
  currently on /login or /onboarding/*  → /dashboard
Otherwise                               → no redirect (allow through)
```

### Bottom Navigation Bar (ShellRoute)

Three tabs, rendered inside the `DashboardScreen` shell:

| Index | Icon                   | Label     | Screen                 |
| ----- | ---------------------- | --------- | ---------------------- |
| 0     | `home_rounded`         | Home      | `DashboardHomeContent` |
| 1     | `auto_awesome_rounded` | Advice    | `InsightsScreen`       |
| 2     | `inventory_2_rounded`  | Inventory | `StockScreen`          |

Tapping a tab sets `context.go()` to the corresponding route. Secondary routes (bills, records, scan, manual) are pushed on top of the shell — the shell detects these routes and hides the bottom nav bar, showing a back button instead.

---

## 6. State Management

### `AuthService` (ChangeNotifier)

Lives at the top of the provider tree. Persists session across app restarts via `SharedPreferences`.

**Fields:**

```dart
String? _token            // JWT access token
String? _userName         // Display name
String? _storeId          // UUID of the user's store
String? _storeType        // 'grocery' | 'pharmacy' | etc.
bool    _onboardingComplete
```

**Methods:**

| Method                          | What it does                                                                                                                                                                                                       |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `loadFromPrefs()`               | Called at app start. Reads all fields from SharedPrefs. Sets `_onboardingComplete = true` if `store_id` is present.                                                                                                |
| `login(name, password)`         | POST `/auth/login`. On success: saves `auth_token`, `refresh_token`, `user_id`, `user_name`, `store_id`, `store_type` to SharedPrefs. Sets `_onboardingComplete = true` if `data['store']` is present in response. |
| `register(name, password)`      | POST `/auth/register`. Saves tokens + user info, but `_onboardingComplete = false` (no store yet).                                                                                                                 |
| `completeOnboarding(storeData)` | POST `/stores/setup` with `{name, region, type}`. Saves `store_id` + `store_type` to SharedPrefs. Sets `_onboardingComplete = true`.                                                                               |
| `logout()`                      | Calls `prefs.clear()`. Resets all fields to null/false. Notifies listeners (go_router redirect fires → `/login`).                                                                                                  |

---

### `OrderListProvider` (ChangeNotifier)

Created as a `ChangeNotifierProxyProvider<AuthService, OrderListProvider>`. Every time `AuthService.storeId` changes, `setStoreId()` is called automatically.

**Data model:**

```dart
class OrderItem {
  String? id;       // UUID from backend (null until POST returns)
  String name;      // Product name (also the dedup key)
  String unit;      // 'kg', 'pcs', 'L', etc.
  String reason;    // Why it's on the list (shown as subtitle)
  int    qty;       // How many to order
}
```

**Key behaviour:**

- All mutations are **optimistic** — UI updates immediately, then the API call fires. On network error, the local change is reverted.
- `add()`: inserts locally → POST `/order-items` → replaces local item with the server version (gets a real UUID).
- `remove(name)`: removes by name → DELETE `/order-items/:id`.
- `updateQty(name, qty)`: if qty ≤ 0, calls `remove()`. Otherwise PATCH `/order-items/:id {qty}`.
- `updateUnit(name, unit)`: PATCH `/order-items/:id {unit}`.
- `markAllOrdered()`: clears list locally → DELETE `/order-items?storeId=X` (bulk delete all).
- `contains(name)`: case-sensitive name lookup — used by all "Add to Order" buttons across the app to show "In list" / "Added" state.

---

## 7. API Client & Auth Token Flow

### Dio Singleton (`ApiClient.instance`)

```
ApiClient
 ├── _dio          ← main client (all app requests)
 │    ├── BaseOptions: baseUrl (from .env), connectTimeout 15s, receiveTimeout 30s
 │    ├── RequestInterceptor: reads 'auth_token' from SharedPrefs → adds 'Authorization: Bearer {token}' header
 │    └── ResponseInterceptor (401 handler):
 │         • If _isRefreshing == true → queue the request for retry
 │         • Set _isRefreshing = true
 │         • Call _refreshDio.post('/auth/refresh', data: {refreshToken})
 │         • On success: save new access + refresh tokens → retry original request
 │         • On failure: clear prefs + notifyListeners on AuthService → redirect to /login
 │         • Reset _isRefreshing = false
 └── _refreshDio   ← bare client (no interceptors, used only for token refresh)
```

**Why two Dio instances?** To prevent infinite loops. If the refresh call itself got a 401 (expired refresh token), the interceptor on `_refreshDio` would not fire again — the error propagates cleanly and logs the user out.

---

## 8. Screen-by-Screen Reference

---

### 8.1 Login / Register

**Route:** `/login`

**What the user sees:**

- App name / logo at the top
- Name + password text fields
- Login button
- "Register" text link (switches between login and register form)

**Login flow:**

1. User enters name + password, taps Login
2. `AuthService.login()` fires → POST `/auth/login`
3. Response saves tokens + `store_id` to SharedPrefs
4. `AuthService` notifies listeners
5. go_router redirect fires:
   - If `store_id` present → `/dashboard`
   - If no `store_id` → `/onboarding/type`

**Register flow:**

1. User enters name + password, taps Register
2. `AuthService.register()` fires → POST `/auth/register`
3. Tokens saved, `_onboardingComplete = false`
4. go_router redirects to `/onboarding/type`

---

### 8.2 Onboarding (3 Screens)

#### Screen 1 — StoreTypeScreen (`/onboarding/type`)

**Purpose:** Identify the type of shop so the AI can give relevant advice.

**Layout:** A 2-column × 4-row grid of store type cards:

| Emoji | Type             | Stored value  |
| ----- | ---------------- | ------------- |
| 🛒    | Grocery / Kirana | `grocery`     |
| 💊    | Pharmacy         | `pharmacy`    |
| 📱    | Electronics      | `electronics` |
| 👗    | Clothing         | `clothing`    |
| 🍽️    | Restaurant       | `restaurant`  |
| 🔧    | Hardware         | `hardware`    |
| 📚    | Stationery       | `stationery`  |
| 🏪    | General Store    | `general`     |

- Tapping a card selects it (animated saffron border appears, opacity fade on others)
- A "Continue" button appears once a type is selected
- Navigates to `/onboarding/details` passing `storeType` as `extra`

---

#### Screen 2 — StoreDetailsScreen (`/onboarding/details`)

**Layout:** Two text fields + a submit button

- **Shop Name** — required. Validated on submit.
- **City** — optional.
- **"Get Started 🚀"** button

**Submit flow:**

1. Form validated
2. `AuthService.completeOnboarding({name, city, type})` called
3. POST `/stores/setup` with `{name, region: city, type}`
4. Response saves `store_id` and `store_type` to SharedPrefs
5. `_onboardingComplete = true`
6. Navigate to `/onboarding/done`

---

#### Screen 3 — OnboardingDoneScreen (`/onboarding/done`)

**Layout:** Centred screen

- Large green circle with ✓ checkmark icon
- Headline: "Your shop is ready!"
- Subtitle: "Start adding bills and the app will track your sales automatically."
- "Open My Shop" button → navigates to `/dashboard`

This is the only time the user sees this screen. After this, the app always opens directly to `/dashboard`.

---

### 8.3 Dashboard — Home Tab

**Route:** `/dashboard` (tab index 0)

This is the **primary screen** of the app. The user lands here every time they open the app. It is designed around a "decision-first" philosophy: the most urgent thing to do appears at the top.

#### Data Loading

Two parallel fetches happen on `initState`:

**`_loadStats()`:**

```
GET /analytics/sales-trends?days=30  → today total, yesterday total, monthly total
GET /analytics/product-rankings?days=30&limit=1  → top-selling product name
```

**`_loadUrgentAlerts()`:**

```
GET /ai/insights  → parses inventory.alerts (high + medium urgency)
                 → parses festival[0] (upcoming festivals)
                 → builds _suggestions list for Action Center
```

The suggestions list is built as:

- High urgency alerts → `{title: "⚠️ {product} running out fast", body: "...", urgency: "high", ctaRoute: "/dashboard/inventory"}`
- Medium urgency alerts → `{urgency: "medium", ...}`
- Upcoming festivals → `{urgency: "opportunity", ...}`

#### AppBar

- **Left:** Time-aware greeting:
  - 5:00–11:59 → "Good morning, {name}"
  - 12:00–17:59 → "Good afternoon, {name}"
  - 18:00–4:59 → "Good evening, {name}"
- **Subtitle:** If `_urgentCount > 0`: "{N} things need attention" · If clean: "Everything looks good ✓"
- **Right:** Logout button → shows confirmation AlertDialog → `AuthService.logout()`

#### The 7 Home Sections (in order, top to bottom)

---

**Section 1 — Urgent Banner (`_UrgentBanner`)**

Shown **only** when there are `urgency: "high"` inventory alerts.

```
┌─────────────────────────────────────────────────────────┐
│ 🔴  2 items running out fast — check inventory →        │
└─────────────────────────────────────────────────────────┘
```

- Background: `AppTheme.error.withOpacity(0.12)`
- Full-width tap → navigates to `/dashboard/inventory`
- Disappears when all high-urgency items are resolved

---

**Section 2 — Primary Add Bill Card (`_PrimaryAddBillCard`)**

Always visible. This is the most important CTA on the entire screen.

```
┌─────────────────────────────────────────────────────────┐
│ ➕ Add a Bill                                           │
│                                                         │
│  ┌──────────────────┐  ┌──────────────┐               │
│  │ 📷  Scan Bill    │  │ ✏️  Type In  │               │
│  └──────────────────┘  └──────────────┘               │
└─────────────────────────────────────────────────────────┘
```

- "Scan Bill" (primary saffron fill) → navigates to `/dashboard/bills/scan`
- "Type In" (saffron outline) → navigates to `/dashboard/bills/manual`

---

**Section 3 — Today's Performance Card (`_TodayPerformanceCard`)**

Three stats side by side:

- **Today:** ₹{X} in green
- **Yesterday:** ₹{X} in secondary text
- **This Month:** ₹{X} in white

---

**Section 4 — AI Action Center (`_ActionCenterCard`)**

A swipeable `PageView` of suggestion cards. Labelled "Your AI Assistant" with count "{N} actions for today".

Each card shows:

```
🔴  [Title — e.g. "Rice running low"]
    [Body — "You have about 2 days of stock left. Order now."]
    [→ View]  ← CTA button, routes to relevant screen
```

Page indicators show "1 of N". User swipes left/right to see all suggestions.

Urgency → emoji mapping:

- `high` → 🔴
- `medium` → 🟡
- `opportunity` (festival) → 💰

If no AI data has loaded yet (spinner), the card shows a loading state.

---

**Section 5 — Quick Health Row (`_QuickHealthRow`)**

Two chips side by side:

- **Top product chip:** e.g. "🏆 Basmati Rice"
- **Alert count chip:** e.g. "⚠️ 3 alerts" (red) or "✓ All good" (green)

---

**Section 6 — Medium Alerts List**

One `_HomeAlertTile` per medium-urgency inventory alert. Each tile shows:

- Product name
- Days remaining estimate
- "Order Now" chip → tapping navigates to `/dashboard/inventory` (To Order tab)

(High-urgency alerts appear in the banner above, not here.)

---

**Section 7 — Records Row**

Two equal-width tiles:

| Tile         | Icon           | Label     | Route                |
| ------------ | -------------- | --------- | -------------------- |
| Bills        | `receipt_long` | "Bills"   | `/dashboard/bills`   |
| Transactions | `book`         | "Records" | `/dashboard/records` |

---

### 8.4 Smart Advice Tab — Context-Aware Guidance

**Route:** `/dashboard/advice` (tab index 1)  
**File:** `lib/features/insights/insights_screen.dart`

> **Critical rule:** This screen is a **read-only view** of the AI guidance cache. Pull-to-refresh only re-reads from the database. The app has no way to trigger a new AI generation.

> **Design philosophy:** No numerical predictions. No sales forecasts. No revenue estimates. Only qualitative, data-driven, shopkeeper-friendly guidance cards.

#### Data Loading

```
GET /ai/insights?storeId={X}&storeType={Y}
→ returns: { guidance: { mode, guidance[] }, generatedAt }
```

The `generatedAt` timestamp is shown as a humanised "Updated Xm/h ago" badge at the top.

#### Mode: NORMAL vs EVENT

- **NORMAL** — Default. No festival banner.
- **EVENT** — When an upcoming festival is ≤ 10 days away. A **"Festival Mode"** banner appears at the top:
  - Gradient shifts to red-tinted when critical-urgency items exist, amber otherwise
  - Shows the AI-generated `summary` line (e.g., "Holi is tomorrow — here's what will fly off the shelves")
  - Urgency count badges: **"🔴 2 Need Now"** (critical) and **"🟠 3 Stock Up"** (high) — only shown when counts > 0
  - The banner reads data from the `event_context` card's `items[].urgency` field

#### Four Card Types

The `guidance[]` array contains objects with `type` field. The app renders them in order:

---

**📦 Stock Health (`_StockCheckCard`, type: `stock_check`)**

```
┌─────────────────────────────────────────────────────────────┐
│  📦  Stock Health                      [2 low] [1 watch]   │
│  ───────────────────────────────────────────────────────── │
│  ✅ Rice                                        [Good]     │
│     Enough supply based on recent sales                     │
│                                                             │
│  ⚠️ Oil                                        [Watch]    │
│     3-4 days left at this pace                              │
│     → Keep an eye, may need restocking soon                │
│                                                             │
│  🔴 Sugar                                       [Low]      │
│     Selling fast, very little left                          │
│     → Restock soon                                          │
└─────────────────────────────────────────────────────────────┘
```

- Header shows summary badges counting LOW and WATCH items
- Each item row: status icon (green ✅ / amber ⚠️ / red 🔴) + product name + status badge
- Below product name: AI-generated `reason` (short) + `action` (in status colour with → prefix)
- Max 8 items per card
- Status values: `GOOD` (green), `WATCH` (amber), `LOW` (red)

---

**📈 Trend (`_PatternCard`, type: `pattern`)**

```
┌─────────────────────────────────────────────────────────────┐
│  📈  Trend                                                  │
│                                                             │
│  Rice demand has been picking up over the last two weeks.   │
│                                                             │
│  💡 Keep enough stock ready to avoid missing sales          │
└─────────────────────────────────────────────────────────────┘
```

- Simple observation + actionable tip
- 0–2 pattern cards per guidance response
- Action is shown in a rounded saffron chip with lightbulb icon

---

**🔥 Festival Demand (`_EventContextCard`, type: `event_context`)**

Only appears when `mode == "EVENT"` (festival ≤ 10 days away).

```
┌─────────────────────────────────────────────────────────────┐
│  🔥  Holi — Stock Up                                        │
│  ───────────────────────────────────────────────────────── │
│  ‼️ Milk                               [🔴 Order Now] [Order]│
│     Holi sweets need lots of milk — stock 3x usual          │
│     → Order extra today                                     │
│                                                             │
│  📈 Sugar                              [🟠 Stock Up] [Order] │
│     Heavy use for sweets and thandai — stock 2x usual       │
│     → Restock before weekend rush                           │
│                                                             │
│  ℹ️ Snacks                              [🟡 Extra]  [Order] │
│     Slightly higher demand expected for gatherings          │
│     → Keep a bit more than usual                            │
│                                                             │
│  ✨ Gulal                               [✨ New]    [Order]  │
│     Customers will look for colours — stock a small batch   │
│     → Source from local supplier                            │
└─────────────────────────────────────────────────────────────┘
```

- Header gradient: red-tinted when critical items exist, amber otherwise
- Header icon: 🔥 fire icon for critical urgency, 📅 event icon otherwise
- Items sorted by urgency: **critical → high → moderate**
- Each item row has a tinted background matching its urgency colour
- **Urgency badges** replace the old classification badges:
  - **🔴 Order Now** (`critical`, red) — will stock out, order TODAY
  - **🟠 Stock Up** (`high`, amber) — stock 2-3× normal quantity
  - **🟡 Extra** (`moderate`, saffron) — stock a bit more than usual
  - **✨ New** (opportunity) — product not in inventory, suggested as optional
- **`demand_note`** (new field) — displayed in urgency colour below product name. Explains _why_ demand will surge and how much extra to stock.
- **`action`** — secondary line with → prefix in muted colour
- "Order" button quantity scales with urgency: critical=30, high=20, moderate=10
- Each row has an "Order" / "✓ Added" toggle tied to `OrderListProvider`

---

**ℹ️ Info (`_GuidanceInfoCard`, type: `info`)**

```
┌─────────────────────────────────────────────────────────────┐
│  ℹ️  Keep adding bills. Guidance improves as your shop     │
│      data grows.                                            │
└─────────────────────────────────────────────────────────────┘
```

- Grey surface background, info icon + text
- Appears when data is insufficient, or as a general tip

#### Empty State

When no guidance exists yet:

```
        ✨
  Smart Advice Is On Its Way
  Keep adding bills — advice refreshes
  automatically once a day.
```

No buttons, no loading indicator. The user just needs to keep adding bills.

---

### 8.5 Inventory Tab

**Route:** `/dashboard/inventory` (tab index 2)  
**File:** `lib/features/stocks/stock_screen.dart`

Two-tab layout controlled by a `TabController`:

```
┌─────────────────────────────────────────────────┐
│   In Stock   │   To Order [3]                  │
└─────────────────────────────────────────────────┘
```

The "To Order" tab shows a badge with the count of items from `OrderListProvider`.

---

#### Tab 1: In Stock

**Data:** `GET /stocks?storeId={X}` on `initState` + pull-to-refresh.

**Summary row** at the top (always visible):

```
[ 14 items ]  [ 🔴 2 out of stock ]  [ 🟡 3 running low ]
```

or if everything is fine:

```
[ 14 items ]  [ 🟢 All healthy ]
```

**Sort order:** Out of stock (0 qty) → Low stock (1–5 qty) → Good (>5 qty)

**`_InStockItemCard`:**

```
┌│────────────────────────────────────────────────┐
 │  Basmati Rice                                  │
 │  [ 3 kg ]  Running low                         │
 │                                    ─  qty  +   │
 │                                    [ 🛒 Order ]│
└│────────────────────────────────────────────────┘
```

- Left border colour: red (0 qty) / orange (1–5) / green (>5)
- `−` and `+` buttons immediately call `PUT /stocks/:id` with new quantity
- "Order" chip: appears only when stock is low/out. Adds to `OrderListProvider` with reason "Out of stock" or "Running low". Changes to "✓ In list" (green) if already in the order list.
- For items with healthy stock: shows edit ✏️ and delete 🗑️ buttons instead.

**FAB:** "Add Item" → opens `_AddEditStockSheet`

**`_AddEditStockSheet` (modal bottom sheet):**

Fields:

- Product Name \* (disabled when editing — name is the unique key)
- Quantity \* + Unit (side by side)
- Cost Price ₹ (optional — used by AI for reorder cost estimates)

On save:

- **New item:** `POST /stocks {storeId, productName, quantity, unit, costPrice}`
- **Edit:** `PUT /stocks/:id {same fields}`
- UNIQUE constraint on `(store_id, product_name)` — prevents duplicate entries

Delete flow: tap 🗑️ → confirm AlertDialog → `DELETE /stocks/:id` → reload list.

---

#### Tab 2: To Order

**Data:** Directly from `OrderListProvider.items` (no additional fetch — already loaded).

**`_OrderItemCard`:**

```
┌──────────────────────────────────────────────────┐
│  Sugar                                           │
│  Running out fast                                │
│                          [ − ] 10 [ + ] [kg ✏]  ×  │
└──────────────────────────────────────────────────┘
```

- Product name + reason subtitle
- Qty stepper: `−` decrements (calls `updateQty`), `+` increments
- Unit chip: tapping opens an AlertDialog with a text field to edit the unit (e.g. "kg" → "bags")
- `×` remove button

**Bottom action bar:**

```
🛒 3 items to order

[ Clear List ]     [ ✅ Ordered — Update Stock ]
```

- **"Clear List":** confirm dialog → `provider.markAllOrdered()` → `DELETE /order-items?storeId=X` (clears list without touching stock)
- **"Ordered — Update Stock":** loops through each order item, finds matching stock item by name (case-insensitive), calls `PUT /stocks/:id` with `quantity = currentQty + orderQty`, then calls `provider.markAllOrdered()`. Shows SnackBar: "Stock updated! X items added." or "Order list cleared."

**Empty state:**

```
🛒
Nothing to order yet
When stock runs low or a sale is coming,
recommended items will appear here.
You can also tap "Order" on any low stock item.
```

---

### 8.6 Bills Screen

**Route:** `/dashboard/bills` (secondary, no bottom nav)  
**File:** `lib/features/bills/bills_screens.dart`

**Data:** `GET /bills` on `initState` + pull-to-refresh.

Shows a list of all bills. Pull-to-refresh reloads. FAB opens a bottom sheet with two options:

- "📷 Scan a Bill" → `/dashboard/bills/scan`
- "✏️ Type it in" → `/dashboard/bills/manual`

**`_BillCard`:**

```
┌──────────────────────────────────────────────────┐
│  City Wholesale Market        ₹1,250             │
│  15 Jan 2025                  [ Done ]           │
└──────────────────────────────────────────────────┘
```

Status badge colours:
| Status | Label | Colour |
|---|---|---|
| `COMPLETED` | Done | Green |
| `PROCESSING` | Reading... | Orange |
| `FAILED` | Failed | Red |
| `UPLOADED` / other | Pending | Grey |

**Empty state:** Illustration + "No bills yet. Tap + to add your first bill."

---

### 8.7 Bill Scanner Screen

**Route:** `/dashboard/bills/scan`

**Flow:**

```
1. Land on screen
   └─ Shows picker prompt:
      [ 📷 Camera ]   [ 🖼️ Gallery ]

2. User picks image (via image_picker, quality 85%)
   └─ Image preview shown
      [ ↺ Use a different image ]
      [ ☁️ Save this Bill ]

3. User taps "Save this Bill"
   └─ Sends POST /bills/upload (multipart/form-data)
         body: { image: File, storeId: UUID }
   └─ Button shows: "Reading your bill..." with spinner

4a. Success:
    └─ Green banner: "✓ Bill uploaded! Taking you back..."
    └─ After 2 seconds, navigates to /dashboard/bills

4b. Failure:
    └─ Red banner: "Upload failed. Please try again."
    └─ User can tap "Save this Bill" again
```

On the backend, `/bills/upload` creates a bill record with `status: UPLOADED`, then dispatches the `ocrWorker` which processes the image with Amazon Nova Vision, extracts line items, creates a ledger entry, and updates the bill to `COMPLETED`.

---

### 8.8 Manual Bill Entry Screen

**Route:** `/dashboard/bills/manual`

**Form layout (scrollable):**

```
┌──────────────────────────────────────────────────┐
│  [ ↓ Sale (Income) ]  [ ↑ Purchase (Expense) ]   │  ← animated toggle
├──────────────────────────────────────────────────┤
│  Where did you buy / sell? (shop name) *         │
├──────────────────────────────────────────────────┤
│  📅  Date: 15/01/2025  ›                        │
├──────────────────────────────────────────────────┤
│  ₹  Total Amount  (auto-calculated)             │
├──────────────────────────────────────────────────┤
│  Items Sold / Items Purchased  [+ Pick Item]    │
│  (shows spinner while inventory loads)           │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ 📦 Basmati Rice                    ₹500 [✕]│  │
│  │  Qty (kg)  │  Price per item (₹)         │   │
│  │  ℹ New item · 10 kg will be added        │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  [ 💾 Save Bill ]                               │
└──────────────────────────────────────────────────┘
```

**Transaction type toggle:**

- "Sale (Income)" (↓ arrow, green fill when selected) — section label: "Items Sold"
- "Purchase (Expense)" (↑ arrow, red fill when selected) — section label: "Items Purchased"
- Animated with 200ms duration. Changing type clears line items.

**Date picker:** System `DatePicker`. Defaults to today.

**Total field:** Auto-calculated from `SUM(qty × unitPrice)` as items are filled in. Editable override.

#### Inventory loading

On `initState`, fetches `GET /stocks?storeId=X` to populate the item picker. A loading spinner replaces the "Pick Item" button until stock is loaded.

#### Item Picker (`_ItemPickerSheet`)

A `DraggableScrollableSheet` (65%–92% of screen height) with:

- **Search field** (autofocused) — live filters inventory by product name
- **Item list** — each row shows product name + stock quantity (e.g. "12 kg in stock"); already-added items are hidden
- **Footer button** — "Add \"[query]\" as new item" / "Add a new item not in inventory"
  - Opens an AlertDialog to type the name and unit

Two callbacks are distinct:

- Tapping an inventory row → `onSelected(name, unit)` → `_onItemSelected(fromInventory: true)`
- Typing a new item in the footer dialog → `onNewItem(name, unit)` → `_onItemSelected(fromInventory: false)`

#### New-item flow during a Sale

When `fromInventory: false` AND `transactionType == 'income'` (sale):

```
"[Item] is not in your inventory"
How many do you currently have in stock?

[ Current stock field ]

[ Skip ]   [ Add to Inventory ]
```

- **Skip**: adds item with `initialStock = 0` (stock row created, will immediately go to 0 after sale)
- **Add to Inventory**: stores the entered count as `initialStock`

New items during a **purchase** skip this dialog entirely — stock is created automatically by `syncStockAfterBill`.

#### `_InventoryItemRow` widget

Each selected item renders as a card with:

- Item icon + name header
- Line total shown when > 0 (auto-updates)
- `Qty (unit)` + `Price per item ₹` inline text fields
- Remove `✕` button
- Info badge: _"New item · X units will be added to inventory"_ if `initialStock != null`
- `onChanged` → triggers `_recalcTotal()` on parent

#### Submit flow

```
1. Validate: at least 1 line item, merchant not empty
2. For each new item with initialStock > 0:
     POST /stocks { storeId, productName, quantity: initialStock, unit }
3. POST /bills/manual
     { storeId, merchant, date, total, transactionType,
       lineItems: [{ name, qty, unitPrice, unit }] }
     → server runs syncStockAfterBill inside the transaction
4. SnackBar: "Bill saved & inventory updated!"
5. Navigate to /dashboard/bills
```

---

### 8.9 Ledger / Records Screen

**Route:** `/dashboard/records` (secondary, no bottom nav)  
**File:** `lib/features/ledger/ledger_screen.dart`

**Data:** `GET /ledger/entries?limit=200` — loads up to 200 most recent entries.

**Search bar** (always visible at top): live filter on merchant name OR date string.

**List: grouped by calendar date, newest first.**

Group header:

```
Today                               +₹2,350
Yesterday                           -₹800
14 Jan 2025                         +₹1,100
```

Group day total is colour-coded (green for net positive, red for net negative). Label uses friendly names (Today / Yesterday / "D Mon YYYY").

**`_EntryCard`:**

```
┌│──────────────────────────────────────────────────┐
 │  [ ↓ Income ]   City Wholesale       +₹1,250    │
 │  ─────────────────────────────────────────────   │
 │  · Basmati Rice          2 × ₹250               │
 │  · Sugar                 5 × ₹40                │
 │  · Toor Dal             10 × ₹85                │
 │  +2 more items                                   │
└│──────────────────────────────────────────────────┘
```

- Left border colour: green (income) / red (expense)
- Type badge: "↓ Income" (green on green tint) or "↑ Expense" (red on red tint)
- Shows up to 3 line items; if more: "+X more items" in secondary text
- Pull-to-refresh reloads from API

**Empty state:**

```
📖
No records yet
Add a bill and it will appear here
```

---

## 9. Backend Architecture

### 9.1 Server Setup

`src/index.js`:

- Express app
- Parses JSON + multipart (for bill image uploads)
- Mounts all route modules (see below)
- Calls `startInsightsScheduler()` at startup (scheduler begins counting down to next 06:00/14:00/22:00 UTC run)
- Global error handler middleware
- Listens on `process.env.PORT || 3000`

---

### 9.2 Route Map

All routes require JWT authentication (`authenticate` middleware) unless noted.

| Method | Route                         | Auth | Purpose                                               |
| ------ | ----------------------------- | ---- | ----------------------------------------------------- |
| POST   | `/auth/register`              | ❌   | Create account, returns tokens                        |
| POST   | `/auth/login`                 | ❌   | Login, returns tokens + store info                    |
| POST   | `/auth/refresh`               | ❌   | Exchange refresh token for new access token           |
| POST   | `/auth/logout`                | ✅   | Invalidate refresh token                              |
| POST   | `/stores/setup`               | ✅   | Create store (onboarding step 2)                      |
| GET    | `/bills`                      | ✅   | List bills — JOINs merchant, amount, type, item count |
| GET    | `/bills/:id`                  | ✅   | Bill detail + nested `entry.lineItems[]`              |
| GET    | `/bills/:id/status`           | ✅   | Poll OCR processing status                            |
| POST   | `/bills/upload`               | ✅   | Upload bill image (multipart), starts OCR job         |
| POST   | `/bills/manual`               | ✅   | Manual bill entry → ledger + stock sync (atomic)      |
| GET    | `/ledger/entries`             | ✅   | List ledger entries (`?limit=200`)                    |
| GET    | `/analytics/sales-trends`     | ✅   | Daily sales for last N days                           |
| GET    | `/analytics/product-rankings` | ✅   | Top N products by sales velocity                      |
| GET    | `/analytics/activity`         | ✅   | Hour/day-of-week transaction heatmap                  |
| GET    | `/ai/insights`                | ✅   | Read cached AI insights (pure DB read)                |
| GET    | `/ai/jobs/:id`                | ✅   | Check OCR job status                                  |
| GET    | `/ai/jobs/:id/result`         | ✅   | Get OCR job result                                    |
| GET    | `/stocks`                     | ✅   | List stock items for store                            |
| POST   | `/stocks`                     | ✅   | Add new stock item                                    |
| PUT    | `/stocks/:id`                 | ✅   | Update stock item (qty, unit, price)                  |
| DELETE | `/stocks/:id`                 | ✅   | Remove stock item                                     |
| GET    | `/order-items`                | ✅   | List order items for store                            |
| POST   | `/order-items`                | ✅   | Add item to order list                                |
| PATCH  | `/order-items/:id`            | ✅   | Update qty or unit                                    |
| DELETE | `/order-items/:id`            | ✅   | Remove one order item                                 |
| DELETE | `/order-items`                | ✅   | Clear all order items for a store (`?storeId=X`)      |

---

### 9.3 Auth Module

- Passwords hashed with bcrypt
- Issues JWT access token (short-lived) + refresh token (long-lived)
- Refresh tokens stored in DB; invalidated on logout
- `authenticate` middleware: reads `Authorization: Bearer {token}` header, verifies JWT, attaches `req.user = { userId, storeId }`

---

### 9.4 Stores Module

Single endpoint: `POST /stores/setup`. Creates a record in `stores` table. Returns `storeId` which is stored in the app's SharedPreferences. The `type` column drives which festival recommendations and AI prompts are relevant.

---

### 9.5 Bills Module

**Shared utility: `utils/stockSync.js`**

Both OCR and manual bill flows use the same `syncStockAfterBill(client, userId, storeId, transactionType, lineItems)` function, which runs **inside the active DB transaction**:

```
transactionType === 'expense' (purchase)
  → INSERT stock_item with qty  ON CONFLICT DO UPDATE quantity += qty

transactionType === 'income' (sale)
  → INSERT stock_item with qty=0  ON CONFLICT DO NOTHING  (guarantee row exists)
  → UPDATE SET quantity = GREATEST(0, quantity - sold)
```

This means: if a bill creation fails, the inventory is never touched (atomically safe).

**OCR flow (`POST /bills/upload`):**

1. Image saved to local disk (`/app/uploads`)
2. `bills` record created with `status: UPLOADED`, `source: 'ocr'`
3. `ocrWorker` dispatched (worker thread)
4. Worker sends image to Amazon Nova Vision with updated prompt:
   - Extracts: merchant, date, total, **`transactionType` (income/expense)**, and per-item **`unit`**
5. Inside a DB transaction: creates `ledger_entry` + `line_items` (with `unit`) + calls `syncStockAfterBill`
6. Updates bill `status → COMPLETED`
7. If worker fails anywhere: ROLLBACK + `status → FAILED`

**Manual flow (`POST /bills/manual`):**

1. Validates: `merchant`, `date`, `total` required; `lineItems` must be a non-empty array; `transactionType` must be `'income'` or `'expense'`
2. Inside a DB transaction:
   - Creates `bills` record (`source: 'manual'`, `status: COMPLETED`)
   - Creates `ledger_entry` with all provided fields
   - Creates `line_items` (stores `unit` per item)
   - Calls `syncStockAfterBill`
3. COMMIT

**`GET /bills`** — returns bills enriched with ledger data:

```sql
SELECT b.*, le.merchant, le.transaction_date, le.total_amount,
       le.transaction_type, COUNT(li.id)::int AS item_count
FROM bills b
LEFT JOIN ledger_entries le ON le.bill_id = b.id
LEFT JOIN line_items li ON li.ledger_entry_id = le.id
WHERE b.user_id = $1  [AND b.store_id = $2]
GROUP BY b.id, le.merchant, le.transaction_date, le.total_amount, le.transaction_type
ORDER BY b.created_at DESC LIMIT 50
```

**`GET /bills/:id`** — returns the bill with nested entry and line items:

```json
{
  "id": "...",
  "status": "COMPLETED",
  "entry": {
    "merchant": "City Wholesale",
    "transaction_type": "expense",
    "total_amount": "1250.00",
    "lineItems": [
      {
        "product_name": "Rice",
        "quantity": 5,
        "unit": "kg",
        "unit_price": 50,
        "total_price": 250
      }
    ]
  }
}
```

---

### 9.6 Ledger Module

`GET /ledger/entries` — fetches entries with their associated `line_items` (JOIN query). Returns newest first. The `?limit=200` cap prevents oversized responses. Each entry includes:

```json
{
  "id": "uuid",
  "merchant": "City Wholesale",
  "transaction_date": "2025-01-15T...",
  "total_amount": "1250.00",
  "transaction_type": "income",
  "line_items": [
    {
      "product_name": "Basmati Rice",
      "quantity": 2,
      "unit_price": 250,
      "total_price": 500
    }
  ]
}
```

---

### 9.7 Analytics Module

**`GET /analytics/sales-trends?days=30`:**

```sql
SELECT date_trunc('day', transaction_date) AS day, SUM(total_amount) AS total
FROM ledger_entries
WHERE user_id = $1 AND transaction_date >= NOW() - INTERVAL '{days} days'
GROUP BY day ORDER BY day ASC
```

Returns an array of `{day, total}` objects. The Flutter app uses this to compute today, yesterday, and monthly totals.

**`GET /analytics/product-rankings?days=30&limit=1`:**

```sql
SELECT li.product_name, SUM(li.total_price) AS revenue
FROM line_items li JOIN ledger_entries le ON ...
WHERE le.user_id = $1 AND le.transaction_date >= NOW() - INTERVAL '{days} days'
GROUP BY li.product_name ORDER BY revenue DESC LIMIT {limit}
```

Returns top N products. The Flutter app uses `limit=1` to show the top product on the home screen.

---

### 9.8 Stocks & Order Items Modules

Both are standard CRUD modules. Notable rules:

- `stock_items` has a UNIQUE constraint on `(store_id, product_name)` — duplicate product names in the same store are rejected
- `order_items` has a UNIQUE constraint on `(user_id, name)` — same product can only appear once in the order list
- All stock operations require `storeId` in the request body/query for ownership validation

---

### 9.9 AI Module

See full detail in [Section 10](#10-the-ai-system-deep-dive).

**`GET /ai/insights`** is a pure database read. It calls `getInsights(userId, storeId)` which runs:

```sql
SELECT type, data, generated_at FROM ai_insights WHERE store_id = $1 ORDER BY generated_at DESC
```

Returns `{ guidance: { mode, guidance[] }, generatedAt }`.

This endpoint also calls `checkAndRefreshIfNeeded()` **in the background** — if the data is stale, a new AI generation starts without blocking the response. The response always returns whatever is currently in the cache.

---

## 10. The AI System (Deep Dive)

The AI system has two layers that work together:

1. **RAG Memory Layer** — a PostgreSQL-backed store of learned shop behaviour (product patterns, product-pair relationships, shop identity insights). This layer grows silently with every transaction and is never visible to the user.
2. **Guidance Generation Layer** — a Node.js worker that reads from RAG memory + live DB data, builds a rich context, and calls Gemini once per store to produce structured guidance cards.

All stores, regardless of transaction count, use the same **experience engine path** (RAG-driven). The app always sees the same response shape.

---

### 10.1 Insight Types

| Type     | DB `type` column | What it contains                                                                          |
| -------- | ---------------- | ----------------------------------------------------------------------------------------- |
| Guidance | `guidance`       | Full structured response: `{ mode, philosophy, guidance[] }` with experience engine cards |

> **Replaced:** The old `forecast` and `festival` types were replaced by a single `guidance` type. The traditional `generateGuidance()` Gemini-direct path (which produced `pattern`, `event_context`, `info` cards) has been removed — all stores now use the experience engine. Legacy rows (`forecast`, `festival`, `inventory`) are cleaned up automatically on next refresh.

Stored in the `ai_insights` table with `UNIQUE(store_id, type)` — exactly one `guidance` row per store, updated in place.

#### Experience Engine Card Types

| Card type              | When generated                                     | Flutter widget          |
| ---------------------- | -------------------------------------------------- | ----------------------- |
| `stock_check`          | Always — if any item is LOW or WATCH               | `_StockCheckCard`       |
| `dead_stock`           | Items in inventory with no/slowing sales (28 days) | `_DeadStockCard`        |
| `sales_expansion`      | Cross-sell & missing complementary products found  | `_SalesExpansionCard`   |
| `momentum_pattern`     | Rising or opportunity products detected            | `_MomentumPatternCard`  |
| `festival_preparation` | Festival within 10 days (experience-backed)        | `_EventContextCard`     |
| `festival_experience`  | Festival within 10 days (memory-driven)            | `_EventContextCard`     |
| `shop_intelligence`    | Always — summary of shop memory maturity           | `_ShopIntelligenceCard` |

#### Response modes

| Mode                | When set                         |
| ------------------- | -------------------------------- |
| `EXPERIENCE_NORMAL` | No festival within 10 days       |
| `EXPERIENCE_EVENT`  | Upcoming festival ≤ 10 days away |

---

### 10.2 When AI Runs

AI generation is **never triggered by the app**. It runs under two conditions:

**Condition 1 — Scheduler (time-based):**

- Runs at **06:00, 14:00, and 22:00 UTC** (every 8 hours)
- On each run: queries all active stores (stores with at least 1 ledger entry, max 50)
- Dispatches a `refreshInsights.js` worker per store, staggered 10 seconds apart to avoid Gemini rate limits

**Condition 2 — Ledger threshold (activity-based):**

- When `GET /ai/insights` is called, `checkAndRefreshIfNeeded()` runs in the background
- It checks: current ledger entry count vs `ledger_count_at_generation` from the DB
- If the difference is **≥ 20**, a new refresh is triggered immediately

**Also:** If a store has **no insights at all**, a refresh is triggered on the first `GET /ai/insights` call.

**Calendar day check:** Even if the scheduler hasn't run yet today, if the oldest insight's `generated_at` is from a **previous UTC calendar day**, a refresh is triggered immediately on the next API call. This ensures insights are always updated at least once per day for active users.

---

### 10.3 Worker: `refreshInsights.js`

This is the only file that calls Gemini (via the experience engine). It runs in a Node.js worker thread.

**Execution flow:**

1. **Update shop memory** — replays the last 7 days of transactions through the learning pipeline (always runs, no minimum transaction count)

2. **Gather data from DB** (all in parallel):
   - `getInventory()` — all stock items for the store: `{ product, quantity, unit }`
   - `getRecentSales()` — top 20 products by sales in the last 28 days, each classified as `rising`, `stable`, `slowing`, or `new` by comparing last-14-day qty to prior-14-day qty
   - `getShopActivity()` — this-week vs last-week transaction count → `recentBusiness` (`growing`/`steady`/`slowing`/`quiet`/`starting`) + top 3 busiest days of week
   - `getClosestFestival()` — the nearest festival within 45 days from `festivalCalendar.js` → `{ name, daysAway }`

3. **Build input JSON** — assembled into the structure the experience engine expects:

   ```json
   {
     "storeType": "grocery",
     "todayDate": "2026-03-01",
     "inventory": [{ "product": "Rice", "quantity": 12, "unit": "kg" }],
     "recentSales": [{ "product": "Rice", "trend": "stable" }],
     "shopActivity": { "recentBusiness": "steady", "busyDays": ["Saturday"] },
     "upcomingFestival": { "name": "Holi", "daysAway": 6 }
   }
   ```

4. **Always use RAG-driven experience engine** — calls `generateExperienceGuidance(storeId, storeType, input)` unconditionally. The experience engine reads from `shop_memory`, `product_relationships`, and `experience_insights` to build structured guidance cards.

5. **Relationship discovery** — always runs `discoverProductRelationships(storeId, 90)` after guidance generation to keep product pairs up to date.

6. **Validate & upsert** — checks response has `mode` + `guidance[]`; falls back gracefully to an info card.

7. **Clean up legacy rows** — deletes old `forecast`/`festival`/`inventory` types from `ai_insights`.

**Fallback when no data:** If both inventory and recentSales are empty, the worker skips the AI call and stores a fallback: `{ mode: "EXPERIENCE_NORMAL", philosophy: "experience_driven", guidance: [{ type: "info", insight: "Keep adding bills..." }] }`

**`upsertInsight(type, data, ledgerCount)`:**

- Checks if data is valid (not null, not `{}`, not `[]`, not an error object)
- If valid: `INSERT ... ON CONFLICT(store_id, type) DO UPDATE` — atomically replaces the cache
- If invalid: **does nothing** — preserves the existing good cache

This means: **a failed or empty AI response never overwrites working cached data.**

---

### 10.4 Anti-Hallucination Rules

The guidance system uses **data-first logic** — the engine only reasons from what the shop actually stocks and sells. Key constraints:

1. **Database is truth** — all card content is derived from `shop_memory`, `product_relationships`, `experience_insights`, and the live inventory/sales snapshot. No hallucinated generic store advice.
2. **Dead stock is fact-checked** — `dead_stock` items are those literally present in `stock_items` with quantity > 0 but absent from `line_items` in the past 28 days (or flagged as `slowing` in trend analysis). No guessing.
3. **Relationship suggestions are evidence-based** — `sales_expansion` and swap ideas in `dead_stock` only appear when actual co-purchase data (`product_relationships` strength ≥ 0.30) backs them up.
4. **No numerical predictions** — qualitative language only (`"demand is picking up"`, not `"demand increased 23%"`).
5. **Festival guidance is grounded** — festival cards only appear when a festival is ≤ 10 days away AND relationship memory supports it.

---

### 10.5 Experience Engine Cards (Guidance Structure)

The experience engine (`synthesizeExperienceGuidance`) builds cards in a fixed priority order:

```
Order 0 — stock_check     (always first, most actionable)
Order 1 — dead_stock      (capital tied up in non-moving items + swap ideas)
Order 2 — sales_expansion (cross-sell & missing complementary products)
Order 3 — momentum_pattern (rising/opportunity products)
Order 4 — festival_preparation / festival_experience (only if festival ≤ 10 days)
Order 5 — shop_intelligence (always last, memory maturity summary)
```

#### `stock_check` card

```json
{
  "type": "stock_check",
  "items": [
    {
      "product": "Paracetamol 500mg",
      "status": "LOW",
      "reason": "Running critically low — one of your top sellers",
      "action": "Order immediately"
    }
  ]
}
```

Statuses: `GOOD` / `WATCH` / `LOW` / `EXCELLENT` / `PRIORITY` / `MISSING`
Thresholds differ for strength products (tighter: ≤ 3 = LOW, ≤ 10 = WATCH) vs active products (≤ 2 = LOW, ≤ 7 = WATCH) vs inactive (≤ 0 = LOW, ≤ 5 = WATCH). Card is skipped if all items are GOOD.

#### `dead_stock` card

```json
{
  "type": "dead_stock",
  "insight": "Items not moving — free up capital by swapping with faster-selling products",
  "deadItems": [
    {
      "product": "Aspirin 300mg",
      "quantity": 45,
      "unit": "strips",
      "status": "no_sales"
    }
  ],
  "swapIdeas": [
    {
      "product": "Cetirizine 10mg",
      "reason": "Customers buying Paracetamol often want Cetirizine",
      "trigger": "Paracetamol 500mg"
    }
  ]
}
```

`status`: `no_sales` (zero transactions in 28 days) or `slowing` (declining trend). Swap ideas come from `missingComplementary` relationships + rising/new products not yet stocked.

#### `sales_expansion` card

```json
{
  "type": "sales_expansion",
  "insight": "Revenue growth opportunities from your customer patterns",
  "crossSell": [
    {
      "trigger": "Milk",
      "suggest": "Curd",
      "reason": "72% of customers buying Milk also want Curd",
      "action": "Display together"
    }
  ],
  "missingItems": [
    {
      "existing": "Bread",
      "missing": "Butter",
      "opportunity": "...",
      "action": "Consider stocking Butter"
    }
  ]
}
```

#### `momentum_pattern` card

```json
{
  "type": "momentum_pattern",
  "insight": "New momentum detected in Vitamin C, Zinc — rising demand",
  "action": "Stock up before demand peaks",
  "products": [{ "product": "Vitamin C", "trend": "rising" }]
}
```

#### `shop_intelligence` card

```json
{
  "type": "shop_intelligence",
  "insight": "Your shop has developed strong behavioral patterns (42 product memories, 18 relationships). Current momentum: growing",
  "memoryStrength": "experienced",
  "businessMomentum": "growing",
  "nextActions": [
    "Explore cross-sell for your top 3 pairs",
    "Review dead stock quarterly"
  ]
}
```

---

### 10.6 The Golden Rule: App Never Calls AI

This is enforced at every layer:

- **`GET /ai/insights`** route returns cached data only; `checkAndRefreshIfNeeded()` runs in the background without blocking the response
- **`POST /ai/insights/refresh`** was deliberately removed from the routes file (comment left as documentation)
- **`InsightsScreen._onPullRefresh()`** only calls `_loadInsights()` (a GET), never posts to any AI endpoint
- **`DashboardHomeContent._loadUrgentAlerts()`** only reads from `/ai/insights` GET

**DEV-only exception — Force Refresh:**

`POST /ai/insights/force-refresh?storeId=&storeType=` (authenticated) — exposed in the Flutter `InsightsScreen` as a red ⚡ DEV button. It:

1. `DELETE FROM ai_insights WHERE store_id=$1` — clears the cache
2. Clears the in-flight lock (`refreshInFlight.delete(storeId)`)
3. Calls `triggerInsightsRefresh()` to spawn a fresh worker immediately

This endpoint exists only for development/testing and should be removed before production.

---

### 10.7 RAG Memory System

The RAG memory system is a set of three PostgreSQL tables (defined in `src/config/rag_memory.sql`) that accumulate shop-specific knowledge over time. This is what makes AI Khata's guidance _shop-specific_ rather than generic: the AI does not guess what a kirana typically sells — it knows what _this_ kirana actually sells, in what combinations, on which days.

#### Three Memory Tables

**`shop_memory`** — Individual product and operational behaviour

| Column        | Type         | Purpose                                                               |
| ------------- | ------------ | --------------------------------------------------------------------- |
| `store_id`    | UUID FK      | Scopes all memory to one store                                        |
| `memory_type` | VARCHAR(50)  | `product_behavior`, `operational_rhythm`, `seasonal_pattern`, etc.    |
| `context`     | VARCHAR(255) | Product name, `Monday_morning`, festival name, etc.                   |
| `memory_data` | JSONB        | The learned pattern (avg qty, day, performance indicator, etc.)       |
| `confidence`  | DECIMAL(3,2) | How reliable this pattern is (0.30 → 1.0). Grows by +0.05 each repeat |
| `frequency`   | INTEGER      | How many times this pattern was observed                              |

Unique constraint: `(store_id, memory_type, context)` — one memory cell per pattern.

**`product_relationships`** — Which products are bought together

| Column              | Type         | Purpose                                                                             |
| ------------------- | ------------ | ----------------------------------------------------------------------------------- |
| `product_a/b`       | VARCHAR(255) | The two products in the relationship                                                |
| `relationship_type` | VARCHAR(50)  | `frequently_together`, `sequential`, `complementary`, `seasonal_pair`, `substitute` |
| `strength`          | DECIMAL(3,2) | Relationship strength (0–1)                                                         |
| `occurrences`       | INTEGER      | How many times this pair was observed                                               |
| `context`           | VARCHAR(255) | Optional: festival/month context for seasonal pairs                                 |

**`experience_insights`** — High-level shop identity conclusions

| Column             | Type         | Purpose                                                                                            |
| ------------------ | ------------ | -------------------------------------------------------------------------------------------------- |
| `insight_category` | VARCHAR(50)  | `shop_identity`, `customer_preference`, `strength_product`, `opportunity_gap`, `seasonal_strength` |
| `title`            | VARCHAR(255) | Short label for the insight                                                                        |
| `description`      | TEXT         | Human-readable summary of the finding                                                              |
| `evidence`         | JSONB        | Supporting data (top products, pair strengths, etc.)                                               |
| `confidence`       | DECIMAL(3,2) | How confident the system is in this insight                                                        |
| `impact`           | VARCHAR(50)  | `low` / `medium` / `high`                                                                          |

---

### 10.8 RAG Learning Phase

Memory is written in three ways, each triggered at a different stage:

#### Trigger A — Real-time (every new ledger entry)

`bills/service.js` and `ledger/service.js` call `learnFromNewTransaction(ledgerEntryId)` in `src/ai/transactionLearner.js` immediately after a transaction is committed. The learner:

1. Fetches the transaction + its line items from the DB
2. Calls `learnFromTransaction(userId, storeId, transactionData)` in `shopMemory.js`, which fans out into three parallel writes:

```
learnFromTransaction()
 ├── learnProductBehavior()      — for each line item:
 │    • avgQty, avgPrice, dayOfWeek, isWeekend, performanceIndicator
 │    • upsertShopMemory(storeId, 'product_behavior', productName, data)
 ├── learnProductRelationships() — for every pair of items in the transaction:
 │    • updateRelationshipStrength(storeId, A, B, 'frequently_together', month)
 │    • updateRelationshipStrength(storeId, B, A, 'frequently_together', month)  ← bidirectional
 └── learnOperationalRhythm()   — for the transaction as a whole:
      • dayOfWeek, timeOfDay (morning/afternoon/evening), peak indicator
      • upsertShopMemory(storeId, 'operational_rhythm', 'Monday_morning', data)
```

3. Checks `checkTriggerDeepLearning(storeId)` — if total transaction count hits a milestone (20, 50, 100, 200, 500), triggers deeper analysis asynchronously via `setImmediate()`:
   - `discoverProductRelationships(storeId, 90)` — runs analytical SQL across 90 days
   - `generateExperienceInsights(storeId)` — synthesises high-level shop identity conclusions

#### Trigger B — Refresh worker (every AI refresh cycle)

`refreshInsights.js` calls `updateShopMemory()` which replays the last 7 days of transactions (up to 50) through the learning pipeline. This always runs — there is no minimum transaction count. This acts as a catch-up for any missed real-time triggers and keeps memory fresh.

#### Trigger C — Scheduled relationship discovery

When `refreshInsights.js` runs, it also fires `discoverProductRelationships(storeId, 90)` after every guidance generation (no ledger threshold). This re-runs the full analytical SQL suite across 90 days of history to catch patterns that incremental learning may have missed.

---

### 10.9 Relationship Discovery

`src/ai/relationshipIntelligence.js` runs four types of market-basket analysis using pure SQL against `ledger_entries` + `line_items`. All four run in parallel inside `discoverProductRelationships()`.

#### Type 1 — Frequent Pairs (`frequently_together`)

SQL approach: market basket analysis with minimum support threshold.

```sql
-- Simplified concept
product_pairs AS (
  SELECT t1.product_name AS product_a,
         t2.product_name AS product_b,
         COUNT(DISTINCT t1.transaction_id) AS transaction_count,
         COUNT(*) / total_transactions AS support
  FROM transaction_products t1
  JOIN transaction_products t2 ON t1.transaction_id = t2.transaction_id
  WHERE t1.product_name < t2.product_name   -- deduplicate (A,B) vs (B,A)
  GROUP BY t1.product_name, t2.product_name
  HAVING COUNT(*) >= 3
)
```

- **Strength** = `MIN(support × 2, 0.95)` — scales support to 0–1 range
- Minimum: ≥ 3 co-occurrences, ≥ 3 shared transactions

#### Type 2 — Sequential Patterns (`sequential`)

SQL approach: `ROW_NUMBER()` window function over purchases partitioned by merchant, looking for product B appearing in the _next_ transaction within 7 days.

- Uses `merchant` field as a customer proxy
- Minimum: ≥ 2 sequential occurrences
- **Strength** = `MIN(sequenceCount / 5, 0.85)`

#### Type 3 — Complementary Items (`complementary`)

SQL approach: basket analysis with a **lift** calculation — items where the combined purchase rate is higher than would be expected by chance.

- Filters to products with ≥ 5 individual sales (ensures statistical significance)
- Minimum lift: 1.5
- **Strength** = `MIN(lift / 3, 0.90)`

#### Type 4 — Seasonal Pairs (`seasonal_pair`)

SQL approach: groups pairs by calendar month and finds pairs that consistently co-occur in _the same month_ across multiple years.

- Minimum: ≥ 2 seasonal co-occurrences
- **Strength** = `MIN(coOccurrences / 4, 0.80)`

After all four run, results are deduplicated (same pair from multiple discovery methods → highest strength wins) and stored via `storeRelationship()` using `ON CONFLICT DO UPDATE`.

---

### 10.10 Experience Engine (Retrieval + Generation)

`src/ai/experienceEngine.js` is the bridge between raw memory and AI guidance. It always runs inside `refreshInsights.js` — there is no transaction count threshold.

#### Priority Hierarchy

The engine assembles context in strict priority order — higher-priority signals override lower-priority ones:

| Priority    | Source                     | What it contributes                                        |
| ----------- | -------------------------- | ---------------------------------------------------------- |
| 1 (highest) | RAG Memory (`shop_memory`) | Strength products, operational rhythm, behavioral patterns |
| 2           | Product Relationships      | Expansion opportunities (have A, missing B)                |
| 3           | Current context            | Business rhythm, sales trends, festival intelligence       |
| 4 (lowest)  | Inventory state            | Stock status — supporting context only, not the driver     |

#### `generateExperienceGuidance()` flow

```
generateExperienceGuidance(storeId, storeType, input)
 ├── P1: generateMemoryBasedRecommendations(storeId, inventory, input)
 │    ├── getProductExperience()        → products with confidence > 0.60, freq ≥ 3
 │    ├── getProductRelationships()     → pairs with strength ≥ 0.30
 │    ├── getExperienceInsights()       → high-level shop identity cards
 │    ├── identifyStrengthProducts()    → top 5 by confidence
 │    ├── identifyExpansionOpportunities() → pairs where shop has A but not B (strength > 0.50)
 │    └── calculateMemoryStrength()    → overall RAG maturity score
 ├── P2: generateSalesExpansionGuidance(storeId, inventory, input)
 │    └── uses product_relationships to build cross-sell suggestions
 ├── P3: generateContextualIntelligence(storeId, input)
 │    ├── analyzeBusinessRhythm()       → momentum, peak days, opportunity window
 │    ├── analyzeSalesTrends()          → rising / slowing / new products
 │    └── getFestivalRelationshipGuidance() (only if daysAway ≤ 10)
 ├── P4: analyzeInventoryState()        → strength product stock status
 └── synthesizeExperienceGuidance()    → builds final context → calls Gemini
```

#### What Gemini receives when RAG is active

In addition to the standard `input` object (inventory, recentSales, shopActivity, upcomingFestival), Gemini also receives the assembled RAG context:

```json
{
  "shopMemory": {
    "strengthBased": [
      { "product": "Milk", "reason": "Consistently sells in high volumes", "confidence": 0.85 }
    ],
    "expansionBased": [
      { "trigger": "Milk", "opportunity": "Curd", "strength": 0.72,
        "suggestion": "Consider stocking Curd to increase basket size" }
    ],
    "experienceInsights": [
      { "category": "shop_identity", "title": "Core Product Strengths",
        "description": "This shop consistently performs well with: Milk, Rice, Sugar" }
    ],
    "memoryStrength": { "overallStrength": 0.63, "isExperienced": true }
  },
  "salesExpansion": { ... },
  "contextualGuidance": { "businessRhythm": { "momentum": "growing" }, ... }
}
```

This context allows Gemini to say things like _"Curd is missing from your inventory — your customers who buy Milk often also want Curd"_ instead of generic restock advice.

#### Fallback path

```
All stores       → generateExperienceGuidance() (full RAG context, always)
RAG call fails   → stores info card: { mode: 'EXPERIENCE_NORMAL', guidance: [{ type: 'info' }] }
```

---

### 10.11 RAG Data Flow End-to-End

```
 User adds a bill (OCR or manual)
       │
       ▼
 Bill saved → ledger_entry created → line_items created
       │
       ├──► learnFromNewTransaction(ledgerEntryId)        [real-time, async]
       │         │
       │         ├── learnProductBehavior()     ──► shop_memory (product_behavior rows)
       │         ├── learnProductRelationships() ──► product_relationships rows
       │         └── learnOperationalRhythm()   ──► shop_memory (operational_rhythm rows)
       │                   │
       │                   └── if milestone (20/50/100…):
       │                         discoverProductRelationships() ──► product_relationships
       │                         generateExperienceInsights()   ──► experience_insights
       │
       └──► checkAndRefreshIfNeeded()  [if ≥20 new entries since last refresh]


 Every 8 hours (or threshold hit):
 refreshInsights.js worker
       │
       ├── updateShopMemory()  (last 7 days replay, always)  ──► shop_memory
       │
       ├── generateExperienceGuidance()  (all stores, always)
       │         │
       │         ├── READ shop_memory, product_relationships, experience_insights
       │         ├── ASSEMBLE rich context (RAG priority 1→4)
       │         │     0. buildStockCheckCard()  → stock_check
       │         │     1. buildDeadStockCard()   → dead_stock
       │         │     2. salesExpansion         → sales_expansion
       │         │     3. contextualGuidance     → momentum_pattern
       │         │     4. festivalGuidance       → festival_preparation / festival_experience
       │         │     5. shopIntelligence       → shop_intelligence
       │         └── CALL Gemini → structured guidance cards
       │
       ├── discoverProductRelationships(storeId, 90)  (always) ──► product_relationships
       │
       └── upsertInsight('guidance', result) ──► ai_insights table


 App calls GET /ai/insights
       │
       └── returns cached ai_insights row
             (enriched with live stock quantities before returning)
```

---

### 10.12 Confidence & Frequency Model

Every memory cell has two independent maturity metrics:

| Metric       | Starting value | Growth per observation | Cap  | Meaning                            |
| ------------ | -------------- | ---------------------- | ---- | ---------------------------------- |
| `confidence` | 0.30           | +0.05                  | 1.0  | Statistical reliability of pattern |
| `frequency`  | 1              | +1                     | none | Raw observation count              |

After **5+ observations**, the `memory_data` JSONB is merged (new data appended via `||`) rather than replaced — preserving historical context.

Usage thresholds applied in the engine:

| Threshold                       | Effect                                               |
| ------------------------------- | ---------------------------------------------------- |
| `confidence > 0.60 && freq ≥ 3` | Product qualifies as a "strength product"            |
| `strength > 0.50`               | Relationship is shown as an expansion opportunity    |
| `strength > 0.70 && occur ≥ 3`  | Pair qualifies as a "strong pairing" insight         |
| `memoryStrength.isExperienced`  | `exp ≥ 10 entries && relationships ≥ 5` → RAG mature |

The **overall memory strength** score used to assess RAG maturity:

$$\text{overallStrength} = (\text{avgConfidence} \times 0.4) + \left(\min\left(\frac{\text{avgFrequency}}{10}, 1\right) \times 0.3\right) + (\text{avgRelStrength} \times 0.3)$$

---

## 11. Database Schema

```sql
-- Users
users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at    TIMESTAMP DEFAULT NOW()
)

-- Stores
stores (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  name       VARCHAR(255) NOT NULL,
  region     VARCHAR(100),
  type       VARCHAR(50) DEFAULT 'general'
             CHECK (type IN ('grocery','pharmacy','electronics',
                             'clothing','restaurant','general')),
  created_at TIMESTAMP DEFAULT NOW()
)

-- Bills (one per physical receipt/entry)
bills (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  store_id   UUID REFERENCES stores(id),
  image_url  TEXT,
  ocr_text   TEXT,
  source     VARCHAR(20) DEFAULT 'ocr' CHECK (source IN ('ocr','manual')),
  status     VARCHAR(50) DEFAULT 'UPLOADED'
             CHECK (status IN ('UPLOADED','PROCESSING','COMPLETED','FAILED')),
  created_at TIMESTAMP DEFAULT NOW()
)

-- Ledger Entries (financial transactions)
ledger_entries (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID REFERENCES users(id) ON DELETE CASCADE,
  store_id         UUID REFERENCES stores(id),
  bill_id          UUID REFERENCES bills(id),
  merchant         VARCHAR(255),
  transaction_date TIMESTAMP NOT NULL,
  total_amount     DECIMAL(10,2) NOT NULL,
  transaction_type VARCHAR(20) NOT NULL DEFAULT 'income',
  notes            TEXT,
  created_at       TIMESTAMP DEFAULT NOW(),
  updated_at       TIMESTAMP DEFAULT NOW()
)

-- Line Items (individual products within a ledger entry)
line_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_entry_id   UUID REFERENCES ledger_entries(id) ON DELETE CASCADE,
  product_name      VARCHAR(255) NOT NULL,
  quantity          DECIMAL(10,2) NOT NULL DEFAULT 1,
  unit_price        DECIMAL(10,2) NOT NULL,
  total_price       DECIMAL(10,2) NOT NULL,
  unit              VARCHAR(50) DEFAULT 'units'   -- added Feb 2026
)

-- AI Jobs (OCR processing queue)
ai_jobs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
  store_id     UUID REFERENCES stores(id),
  job_type     VARCHAR(50) NOT NULL CHECK (job_type IN ('forecast','inventory','festival','ocr')),
  config       JSONB NOT NULL DEFAULT '{}',
  status       VARCHAR(50) DEFAULT 'QUEUED'
               CHECK (status IN ('QUEUED','PROCESSING','COMPLETED','FAILED')),
  error        TEXT,
  created_at   TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP
)

-- AI Results (output from AI jobs)
ai_results (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id     UUID REFERENCES ai_jobs(id) ON DELETE CASCADE,
  data       JSONB NOT NULL,
  confidence DECIMAL(3,2),
  created_at TIMESTAMP DEFAULT NOW()
)

-- AI Insights Cache (served to app; never written by app)
ai_insights (
  id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id                   UUID REFERENCES stores(id) ON DELETE CASCADE,
  type                       VARCHAR(50) NOT NULL
                             CHECK (type IN ('guidance','forecast','inventory','festival')),  -- guidance is the active type; others are legacy
  data                       JSONB NOT NULL,
  generated_at               TIMESTAMP DEFAULT NOW(),
  ledger_count_at_generation INTEGER DEFAULT 0,
  UNIQUE (store_id, type)    -- exactly one row per insight type per store
)

-- Stock Items (current inventory)
stock_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     UUID REFERENCES stores(id) ON DELETE CASCADE,
  user_id      UUID REFERENCES users(id) ON DELETE CASCADE,
  product_name VARCHAR(255) NOT NULL,
  quantity     DECIMAL(10,2) NOT NULL DEFAULT 0,
  unit         VARCHAR(50) DEFAULT 'units',
  cost_price   DECIMAL(10,2),
  updated_at   TIMESTAMP DEFAULT NOW(),
  created_at   TIMESTAMP DEFAULT NOW(),
  UNIQUE (store_id, product_name)   -- one entry per product per store
)

-- Order Items (persistent "to buy" list)
order_items (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  store_id   UUID REFERENCES stores(id) ON DELETE CASCADE,
  name       VARCHAR(255) NOT NULL,
  unit       VARCHAR(50) DEFAULT 'units',
  reason     TEXT DEFAULT '',
  qty        INTEGER NOT NULL DEFAULT 1 CHECK (qty > 0),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE (user_id, name)    -- a product can only appear once in the order list
)

-- RAG Memory Tables (src/config/rag_memory.sql)

-- Learned product and operational behaviour per store
shop_memory (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     UUID REFERENCES stores(id) ON DELETE CASCADE,
  memory_type  VARCHAR(50) NOT NULL
               CHECK (memory_type IN (
                 'product_behavior', 'product_relationship',
                 'seasonal_pattern', 'customer_behavior', 'operational_rhythm'
               )),
  context      VARCHAR(255) NOT NULL,   -- product name, 'Monday_morning', etc.
  memory_data  JSONB NOT NULL,
  confidence   DECIMAL(3,2) DEFAULT 0.50,  -- grows +0.05 per observation, max 1.0
  frequency    INTEGER DEFAULT 1,
  last_seen    TIMESTAMP DEFAULT NOW(),
  created_at   TIMESTAMP DEFAULT NOW(),
  updated_at   TIMESTAMP DEFAULT NOW(),
  UNIQUE (store_id, memory_type, context)
)

-- Products frequently bought together
product_relationships (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id          UUID REFERENCES stores(id) ON DELETE CASCADE,
  product_a         VARCHAR(255) NOT NULL,
  product_b         VARCHAR(255) NOT NULL,
  relationship_type VARCHAR(50) NOT NULL
                    CHECK (relationship_type IN (
                      'frequently_together', 'sequential', 'complementary',
                      'seasonal_pair', 'substitute'
                    )),
  strength          DECIMAL(3,2) DEFAULT 0.50,
  occurrences       INTEGER DEFAULT 1,
  context           VARCHAR(255),       -- festival / month for seasonal pairs
  last_occurrence   TIMESTAMP DEFAULT NOW(),
  created_at        TIMESTAMP DEFAULT NOW(),
  UNIQUE (store_id, product_a, product_b, relationship_type, context)
)

-- High-level shop identity & behaviour conclusions
experience_insights (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id          UUID REFERENCES stores(id) ON DELETE CASCADE,
  insight_category  VARCHAR(50) NOT NULL
                    CHECK (insight_category IN (
                      'shop_identity', 'customer_preference', 'strength_product',
                      'opportunity_gap', 'seasonal_strength'
                    )),
  title             VARCHAR(255) NOT NULL,
  description       TEXT NOT NULL,
  evidence          JSONB,
  confidence        DECIMAL(3,2) DEFAULT 0.50,
  impact            VARCHAR(50) DEFAULT 'medium' CHECK (impact IN ('low','medium','high')),
  created_at        TIMESTAMP DEFAULT NOW(),
  updated_at        TIMESTAMP DEFAULT NOW(),
  UNIQUE (store_id, insight_category, title)
)

-- Tracks how memory suggestions are used (feedback loop, future use)
memory_usage (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    UUID REFERENCES stores(id) ON DELETE CASCADE,
  memory_id   UUID REFERENCES shop_memory(id) ON DELETE CASCADE,
  usage_type  VARCHAR(50) NOT NULL
              CHECK (usage_type IN (
                'suggestion_used', 'suggestion_ignored',
                'pattern_confirmed', 'pattern_violated'
              )),
  context     JSONB,
  created_at  TIMESTAMP DEFAULT NOW()
)

-- Key Indexes
CREATE INDEX idx_ledger_user_date     ON ledger_entries(user_id, transaction_date);
CREATE INDEX idx_line_items_product   ON line_items(product_name);
CREATE INDEX idx_bills_user_status    ON bills(user_id, status);
CREATE INDEX idx_ai_insights_store    ON ai_insights(store_id, type);
CREATE INDEX idx_stock_items_store    ON stock_items(store_id);
CREATE INDEX idx_stores_user          ON stores(user_id);
-- RAG indexes
CREATE INDEX idx_shop_memory_store_type       ON shop_memory(store_id, memory_type);
CREATE INDEX idx_shop_memory_confidence       ON shop_memory(confidence DESC);
CREATE INDEX idx_product_relationships_store  ON product_relationships(store_id);
CREATE INDEX idx_product_relationships_strength ON product_relationships(strength DESC);
CREATE INDEX idx_experience_insights_store    ON experience_insights(store_id);
```

---

## 12. Key Business Rules & Constraints

### Authentication

- Sessions persist across app restarts via SharedPreferences
- Token refresh is silent — the user never sees a re-login prompt unless the refresh token itself is expired
- One store per user (the onboarding flow sets a single `store_id` for the session)

### Bill Entry

- OCR bills → async processing; the `BillsScreen` status badges reflect the async state
- Manual bills → synchronous; ledger entry created immediately
- Both paths trigger the `checkAndRefreshIfNeeded()` AI threshold check

### Stock Management

- Product name is the unique key within a store (`UNIQUE(store_id, product_name)`) — you cannot have two "Rice" entries
- Cost price is optional but improves AI reorder cost estimates
- Quantities can be decimal (10.5 kg), but display rounds to integer when `qty % 1 == 0`
- Stock is updated automatically whenever a bill is created (manual or OCR). The update runs **inside the bill's DB transaction** — if the bill fails, stock is not changed.
  - Purchase (expense): `quantity += sold` per line item
  - Sale (income): `quantity = GREATEST(0, quantity - sold)` per line item (never goes negative)
- **"Ordered — Update Stock"**: loops through each order item and calls `POST /stocks` (upsert by product name). This **creates** new stock items if they don't exist yet, and **sets** quantity for existing ones. It does not increment — it sets the quantity to the ordered amount.
- New items sold during bill entry that aren't in inventory trigger a stock-count dialog. The app pre-creates the stock row (`POST /stocks` with `initialStock`), then the bill sync decrements from it.

### Order List

- Fully persistent via the backend — survives app restarts, reinstalls (as long as the account exists)
- All mutations are optimistic: UI updates instantly, reverts on network failure
- A product can only appear once (UNIQUE constraint). Calling `add()` for an existing product is a no-op (the `contains()` check prevents duplicates in the UI, but the backend also enforces uniqueness)
- **"Clear List"** button: confirm dialog → `DELETE /order-items?storeId=X` — empties list **without** touching stock quantities
- **"Ordered — Update Stock"** button: `POST /stocks` (upsert) for every order item (creates new stock rows if needed, sets quantity to ordered qty), then `DELETE /order-items?storeId=X` to clear the list. Shows SnackBar with count.

### AI System

- The app is **read-only** with respect to AI — it can only call `GET /ai/insights`
- AI refresh is triggered by time (3× daily) or activity (every 20 new ledger entries), never by the user
- Bad/empty AI responses are silently discarded; the cache is never overwritten with junk data
- **Unified experience engine**: all stores always use `generateExperienceGuidance()` (RAG-driven). The old inventory-only Gemini path has been removed. Cards produced: `stock_check`, `dead_stock`, `sales_expansion`, `momentum_pattern`, `festival_preparation`, `festival_experience`, `shop_intelligence`
- **No numerical predictions**: the AI is explicitly forbidden from returning sales numbers, percentages, forecasts, or revenue estimates — qualitative reasoning only
- **Dead stock detection**: items in inventory with quantity > 0 but zero transactions in 28 days (or `slowing` trend) appear in the `dead_stock` card with swap suggestions from relationship data
- **Festival guidance**: when a festival is ≤ 10 days away, mode switches to `EXPERIENCE_EVENT` and a festival card is generated using shop relationship memory
- AI workers are staggered 10 seconds apart when multiple stores refresh at the same time (scheduler runs)
- In-flight deduplication: `refreshInFlight` Set prevents two simultaneous refreshes for the same store
- **DEV force-refresh**: `POST /ai/insights/force-refresh` clears the cache and immediately spawns a new worker; exposed in Flutter as a red ⚡ button for testing only

### RAG Memory System

- Memory is **per-store** — all three RAG tables are scoped by `store_id`. One store's patterns never influence another store.
- Memory cells use **upsert semantics** (`ON CONFLICT DO UPDATE`). The system never deletes memory rows — frequency and confidence only ever increase.
- After 5+ observations, `memory_data` JSONB is **merged** (new `||` old) rather than replaced, preserving historical context.
- Real-time learning (`learnFromNewTransaction`) is **fire-and-forget** — errors are caught and logged but never block the bill-save flow.
- Deep learning (`discoverProductRelationships`, `generateExperienceInsights`) runs via `setImmediate()` at transaction count milestones (20, 50, 100, 200, 500) — it is non-blocking and never affects response time of a bill save.
- The `refreshInsights.js` worker replays the last 7 days of transactions on every run as a catch-up mechanism (no minimum transaction count). Memory is eventually consistent even if real-time triggers fail.
- Relationship discovery requires minimum co-occurrence thresholds (≥3 for frequent pairs, ≥2 for sequential/seasonal) before a relationship is stored — prevents noise from one-off coincidences.
- Relationship discovery (`discoverProductRelationships`) runs on every refresh cycle — there is no `ledgerCount` threshold for it.
- The `memory_usage` table exists for future feedback-loop work (confirming or violating patterns based on shop owner actions) but is not yet wired to any active logic.

### UX Philosophy

- The home screen is **decision-first** — urgent actions appear above neutral information
- `OrderListProvider` is wired across the entire app — "Add to Order" buttons anywhere (Advice tab, Inventory tab, Home alerts) all write to the same persistent list
- Pull-to-refresh on all list screens always re-fetches from the API — there is no local-only cache
- The empty state for Smart Advice deliberately has no action button — the correct response is to keep adding bills, not to manually trigger AI
