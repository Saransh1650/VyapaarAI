# AI Khata — Full App Architecture & Screen Reference

> **What this document is:** A complete, screen-by-screen, flow-by-flow reference for the entire AI Khata app — Flutter front-end, Node.js back-end, AI system, database schema, and all the rules that hold it together. If you want to understand what happens when a user taps anything, this is the document.

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
    - [10.1 Three Insight Types](#101-three-insight-types)
    - [10.2 When AI Runs](#102-when-ai-runs)
    - [10.3 Worker: refreshInsights.js](#103-worker-refreshinsightsjs)
    - [10.4 Anti-Hallucination Rule](#104-anti-hallucination-rule)
    - [10.5 Gemini Prompts (summarised)](#105-gemini-prompts-summarised)
    - [10.6 The Golden Rule: App Never Calls AI](#106-the-golden-rule-app-never-calls-ai)
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
- **Smart Advice** → Detailed AI insights: forecast, inventory health, festival prep
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
| AI Model   | Google Gemini (primary), Groq / Llama 3.1 (fallback) |
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
    │   └── insights_screen.dart    ← Smart Advice tab (1220 lines)
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
│   ├── gemini.js     ← callGemini() with Groq fallback
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
└── workers/
    ├── refreshInsights.js  ← AI worker (forecast + inventory + festival)
    ├── ocrWorker.js        ← Bill OCR processing
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

### 8.4 Smart Advice Tab

**Route:** `/dashboard/advice` (tab index 1)  
**File:** `lib/features/insights/insights_screen.dart`

> **Critical rule:** This screen is a **read-only view** of the AI insights cache. Pull-to-refresh only re-reads from the database. The app has no way to trigger a new AI generation.

#### Data Loading

```
GET /ai/insights?storeId={X}&storeType={Y}
→ returns: { forecast, inventory, festival[], generatedAt }
```

The `generatedAt` timestamp is shown as a humanised "Updated Xm/h ago" badge at the top.

#### Three Sections

---

**📅 Coming up for your shop**

Shown only when `festival[]` is non-empty. One `_UpcomingEventCard` per festival.

Each card has:

```
┌────────────────────────────────────────────────────────────┐
│  🪔  Diwali                      ┌─────────────┐          │
│      ┌──────────────┐            │ Could earn  │          │
│      │ In 12 days   │            │  +₹24K      │          │
│      └──────────────┘            │  extra      │          │
│                                  └─────────────┘          │
│  ✨ You still have a few days to prepare. Customers       │
│     will be looking for things like Diyas and Sweets.     │
│     Stock up now and you won't miss the sales.            │
│                                                            │
│  What to stock up on:                                      │
│  ┌──────────────────────────────────────────────────────┐ │
│  │ TOP  Diyas           ↑30%              [+ Order]    │ │
│  │      Sweets                            [+ Order]    │ │
│  └──────────────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────────┐     │
│  │  Add all to order list →                         │     │
│  └──────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────┘
```

- Event emoji is determined by festival name (🪔 for Diwali, 🌈 for Holi, 🌙 for Eid, etc.)
- Days away badge: "Today!" / "Tomorrow" / "In X days" / "Next week"
- Urgency: ≤7 days → warning orange border; >7 days → primary saffron border
- "Could earn +₹{X}K" badge (calculated as `recs.length × 4800 / 1000`)
- AI advisor pitch (human tone, specific to products)
- Product rows: top pick gets "TOP" tag + highlighted background; others are quieter
- Each product row has individual "Order" / "✓ Added" toggle tied to `OrderListProvider`
- "Add all to order list" button: adds all products at once with reason "{festival} in X days"; changes to "✓ All added to order list" (green, disabled)

---

**🔮 What to expect next month (`_HumanForecastCard`)**

```
┌────────────────────────────────────────────────────────────┐
│  ✨ "Sales should be steady this month with a slight       │
│      uptick in the second week."                           │
│  ──────────────────────────────────────────────────────   │
│  Expected this month                                       │
│  ₹2.4L                                                     │
│  Second week looks stronger                                │
│                                                            │
│  ┌──────────────┐  ┌──────────────┐                       │
│  │ 📈           │  │ 📉           │                       │
│  │ Best day     │  │ Slower day   │                       │
│  │ 03-14        │  │ 03-22        │                       │
│  └──────────────┘  └──────────────┘                       │
│                                                            │
│  💡 Consider running a small offer on your slower         │
│     day to bring more customers in.                       │
└────────────────────────────────────────────────────────────┘
```

Data computed client-side from the 30-day forecast array:

- `week1` = sum of days 1–7; `week2` = sum of days 8–14 → determines trend label
- `peakDay` and `slowDay` = max/min predicted values in the 30-day period
- `totalPredicted` = sum of all 30 days → displayed as ₹X.XL

---

**📦 Stock to sort out (`_InventoryHealthSummary`)**

Health banner first:

```
✅  All your stock looks healthy          (green border, green text)
  No action needed right now.

— or —

⚠️  Some items need ordering soon        (red border, red text)
  2 running out fast · 1 getting low
```

Then a list of `_AlertCard`s for each alert. Each card shows:

- 🔴/🟡 emoji + product name + "Order Now" / "Plan Restock" / "✓ In list" button
- Days remaining: "⏰ Runs out tomorrow" / "About X days of stock left"
- "Order about X units to be safe" in saffron
- AI tip in a grey rounded box (💡 icon)

The "Order Now" / "Plan Restock" button adds to `OrderListProvider` with the AI-suggested `reorderQty` and reason.

#### Empty State

When no AI insights exist yet:

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

On the backend, `/bills/upload` creates a bill record with `status: UPLOADED`, then dispatches the `ocrWorker` which processes the image with Gemini Vision, extracts line items, creates a ledger entry, and updates the bill to `COMPLETED`.

---

### 8.8 Manual Bill Entry Screen

**Route:** `/dashboard/bills/manual`

**Form layout (scrollable):**

```
┌──────────────────────────────────────────────────┐
│  [ ↓ Income ]   [ ↑ Expense ]   ← animated toggle│
├──────────────────────────────────────────────────┤
│  Where did you buy (shop name)? *               │
├──────────────────────────────────────────────────┤
│  📅  Date of Purchase: 15/01/2025  ›           │
├──────────────────────────────────────────────────┤
│  ₹  Total Amount *                              │
├──────────────────────────────────────────────────┤
│  Items Purchased                  [+ Add Item]  │
│  (optional section — shows placeholder if empty)│
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ Item 1                              [✕]  │   │
│  │  Item Name                               │   │
│  │  Qty  │  Price per item (₹)              │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  [ 💾 Save Bill ]                               │
└──────────────────────────────────────────────────┘
```

**Transaction type toggle:**

- "Income" (↓ arrow, green fill when selected)
- "Expense" (↑ arrow, red fill when selected)
- Animated with 200ms duration

**Date picker:** Tapping the date row opens the system `DatePicker` dialog. Defaults to today. Range: 2020–today.

**Line items:** Optional. User can add any number of items. Each item has:

- Item Name (text)
- Qty (number)
- Price per item ₹ (decimal)

**Submit flow:**

```
POST /bills/manual
{
  storeId, merchant, date (ISO), total, transactionType,
  lineItems: [{ name, qty, unitPrice }]
}
```

On success: SnackBar "Bill saved!" + navigate to `/dashboard/bills`.

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

| Method | Route                         | Auth | Purpose                                          |
| ------ | ----------------------------- | ---- | ------------------------------------------------ |
| POST   | `/auth/register`              | ❌   | Create account, returns tokens                   |
| POST   | `/auth/login`                 | ❌   | Login, returns tokens + store info               |
| POST   | `/auth/refresh`               | ❌   | Exchange refresh token for new access token      |
| POST   | `/auth/logout`                | ✅   | Invalidate refresh token                         |
| POST   | `/stores/setup`               | ✅   | Create store (onboarding step 2)                 |
| GET    | `/bills`                      | ✅   | List all bills for user                          |
| POST   | `/bills/upload`               | ✅   | Upload bill image (multipart), starts OCR job    |
| POST   | `/bills/manual`               | ✅   | Manual bill entry, directly creates ledger entry |
| GET    | `/ledger/entries`             | ✅   | List ledger entries (`?limit=200`)               |
| GET    | `/analytics/sales-trends`     | ✅   | Daily sales for last N days                      |
| GET    | `/analytics/product-rankings` | ✅   | Top N products by sales velocity                 |
| GET    | `/ai/insights`                | ✅   | Read cached AI insights (pure DB read)           |
| GET    | `/ai/jobs/:id`                | ✅   | Check OCR job status                             |
| GET    | `/ai/jobs/:id/result`         | ✅   | Get OCR job result                               |
| GET    | `/stocks`                     | ✅   | List stock items for store                       |
| POST   | `/stocks`                     | ✅   | Add new stock item                               |
| PUT    | `/stocks/:id`                 | ✅   | Update stock item (qty, unit, price)             |
| DELETE | `/stocks/:id`                 | ✅   | Remove stock item                                |
| GET    | `/order-items`                | ✅   | List order items for store                       |
| POST   | `/order-items`                | ✅   | Add item to order list                           |
| PATCH  | `/order-items/:id`            | ✅   | Update qty or unit                               |
| DELETE | `/order-items/:id`            | ✅   | Remove one order item                            |
| DELETE | `/order-items`                | ✅   | Clear all order items for a store (`?storeId=X`) |

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

**OCR flow (`POST /bills/upload`):**

1. Image saved to storage (S3 or local disk)
2. `bills` record created with `status: UPLOADED`, `source: 'ocr'`
3. `ocrWorker` dispatched (worker thread)
4. Worker sends image to Gemini Vision → extracts merchant name, date, total, line items
5. Creates `ledger_entry` + `line_items` records
6. Updates bill `status → COMPLETED`
7. If worker fails: `status → FAILED`

**Manual flow (`POST /bills/manual`):**

1. Creates `bills` record with `source: 'manual'`, `status: COMPLETED` immediately
2. Creates `ledger_entry` with all provided fields
3. Creates `line_items` for each item in the array
4. Calls `checkAndRefreshIfNeeded()` — if 20+ new ledger entries since last AI run, triggers background refresh

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

Returns `{ forecast, inventory, festival[], generatedAt }`.

This endpoint also calls `checkAndRefreshIfNeeded()` **in the background** — if the data is stale, a new AI generation starts without blocking the response. The response always returns whatever is currently in the cache.

---

## 10. The AI System (Deep Dive)

### 10.1 Three Insight Types

| Type      | DB `type` column | What it contains                                                |
| --------- | ---------------- | --------------------------------------------------------------- |
| Forecast  | `forecast`       | 30-day daily sales prediction + 1-sentence summary              |
| Inventory | `inventory`      | List of stock alerts (product, days left, reorder qty, urgency) |
| Festival  | `festival`       | Array of upcoming festival objects with product recommendations |

All three are stored in the `ai_insights` table with `UNIQUE(store_id, type)` — so there is always exactly one row per type per store, updated in place.

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

This is the only file that calls Gemini. It runs in a Node.js worker thread.

**Execution order:**

1. `generateInventory()` — most critical for day-to-day
2. `generateFestivals()` — per-festival, up to 45 days ahead
3. (forecast generation is present in older code but the scheduler only runs inventory + festivals in the latest version)

**`upsertInsight(type, data, ledgerCount)`:**

- Checks if data is valid (not null, not `{}`, not `[]`, not an error object)
- If valid: `INSERT ... ON CONFLICT(store_id, type) DO UPDATE` — atomically replaces the cache
- If invalid: **does nothing** — preserves the existing good cache

This means: **a failed or empty AI response never overwrites working cached data.**

---

### 10.4 Anti-Hallucination Rule

The festival prompt contains an explicit constraint:

> "Products this store actually sells (last 30 days): [list of product names from salesVelocity query]. ONLY recommend from these. Do NOT invent items the store doesn't sell."

The `catalogList` is built from:

```sql
SELECT li.product_name FROM line_items li
JOIN ledger_entries le ON ...
WHERE le.user_id=$1 AND le.transaction_date >= NOW() - INTERVAL '30 days'
GROUP BY li.product_name ORDER BY total_qty_30d DESC LIMIT 20
```

If the store has no recent sales history, the constraint is relaxed: "No catalog available — suggest realistic {festival} items for a {storeType} store."

---

### 10.5 Gemini Prompts (summarised)

**Forecast prompt:**

```
You are a demand forecasting AI for a {storeType} retail store.
Historical daily sales data (last 90 days): [...].
Predict daily sales for the next 30 days.
Return ONLY valid JSON: { forecast: [{date, predicted, confidenceLow, confidenceHigh}], summary: "..." }
```

**Inventory prompt:**

```
You are an inventory manager for a {storeType} retail shop. Today is {date}.
Current stock: [...]. Last-30-day sales velocity per product: [...].
For each product at risk: compute days left (qty / daily_velocity).
Return alerts for urgency HIGH (≤3 days) and MEDIUM (4-10 days) only.
Return ONLY valid JSON: { alerts: [{product, currentStock, unit, dailyVelocity,
estimatedDaysLeft, reorderQty, urgency, actionText}] }
```

**Festival prompt (per event):**

```
You are a festival sales advisor for a {storeType} retail shop in India.
Festival: {name} — {daysAway} days away.
Last year sales during this festival: [...].
Products this store actually sells: [CATALOG].
CRITICAL RULE: Recommend ONLY products from the catalog above.
Return ONLY valid JSON: { festival, date, daysAway, totalEstimatedBoost,
festivalTip, recommendations: [{product, recommendedQty, stockGap,
estimatedExtraRevenue, urgencyToBuy, tip}] }
```

---

### 10.6 The Golden Rule: App Never Calls AI

This is enforced at every layer:

- **`GET /ai/insights`** route returns cached data only; `checkAndRefreshIfNeeded()` runs in the background without blocking the response
- **`POST /ai/insights/refresh`** was deliberately removed from the routes file (comment left as documentation)
- **`InsightsScreen._onPullRefresh()`** only calls `_loadInsights()` (a GET), never posts to any AI endpoint
- **`DashboardHomeContent._loadUrgentAlerts()`** only reads from `/ai/insights` GET

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
  total_price       DECIMAL(10,2) NOT NULL
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
                             CHECK (type IN ('forecast','inventory','festival')),
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

-- Key Indexes
CREATE INDEX idx_ledger_user_date     ON ledger_entries(user_id, transaction_date);
CREATE INDEX idx_line_items_product   ON line_items(product_name);
CREATE INDEX idx_bills_user_status    ON bills(user_id, status);
CREATE INDEX idx_ai_insights_store    ON ai_insights(store_id, type);
CREATE INDEX idx_stock_items_store    ON stock_items(store_id);
CREATE INDEX idx_stores_user          ON stores(user_id);
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

- Product name is the unique key within a store — you cannot have two "Rice" entries
- Cost price is optional but improves AI reorder cost estimates
- Quantities can be decimal (10.5 kg), but display rounds to integer when `qty % 1 == 0`
- The "Ordered — Update Stock" action only updates quantities for products whose names **exactly match** (case-insensitive) an existing stock item. New products in the order list are NOT auto-created in stock.

### Order List

- Fully persistent via the backend — survives app restarts, reinstalls (as long as the account exists)
- All mutations are optimistic: UI updates instantly, reverts on network failure
- A product can only appear once (UNIQUE constraint). Calling `add()` for an existing product is a no-op (the `contains()` check prevents duplicates in the UI, but the backend also enforces uniqueness)
- `markAllOrdered()` (from "Clear List") does NOT update stock quantities — it just empties the list
- `markAllOrdered()` (from "Ordered — Update Stock") DOES update stock quantities first, then empties the list

### AI System

- The app is **read-only** with respect to AI — it can only call `GET /ai/insights`
- AI refresh is triggered by time (3× daily) or activity (every 20 new ledger entries), never by the user
- Bad/empty AI responses are silently discarded; the cache is never overwritten with junk data
- Festival recommendations are constrained to the store's own product catalog to prevent hallucination
- AI workers are staggered 10 seconds apart when multiple stores refresh at the same time (scheduler runs)
- In-flight deduplication: `refreshInFlight` Set prevents two simultaneous refreshes for the same store

### UX Philosophy

- The home screen is **decision-first** — urgent actions appear above neutral information
- `OrderListProvider` is wired across the entire app — "Add to Order" buttons anywhere (Advice tab, Inventory tab, Home alerts) all write to the same persistent list
- Pull-to-refresh on all list screens always re-fetches from the API — there is no local-only cache
- The empty state for Smart Advice deliberately has no action button — the correct response is to keep adding bills, not to manually trigger AI
