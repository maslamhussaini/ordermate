# OrderMate Full Technical Guide: From Start to End

**Date:** January 2026
**Version:** 3.0 (Post-Production Polish)

---

## 🧭 Introduction
This guide is designed to take a developer or administrator from **zero** (setup) to **hero** (full operational deployment), covering every technical aspect of the OrderMate SaaS platform.

It answers the question: *"Where do I start, and how does the whole system flow together?"*

---

## ⚡ Part 1: Where to Start (Setup & Initialization)

### 1.1 Development Environment
Before running the code, ensure your environment matches the production baseline:
*   **Flutter SDK**: 3.27+ (Stable Channel)
*   **Dart SDK**: 3.6+
*   **Platform Support**:
    *   **Android**: Min SDK 21, Target SDK 34.
    *   **iOS**: Target 14.0+.
    *   **Web**: WASM enabled (optional but recommended).
    *   **Windows**: Visual Studio 2022 Build Tools (C++ Desktop).

### 1.2 Configuration (`.env`)
The app relies on a root `.env` file. You must define:
```env
SUPABASE_URL=https://<your-project>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
```

### 1.3 Running the App
*   **Debug Mode**: `flutter run` (Use `-d chrome` for web, `-d windows` for desktop).
*   **Release Build**: `flutter build apk --release` (Android).

---

## 🔄 Part 2: The Core Logic (Online vs. Offline)

This is the "Brain" of OrderMate. Understanding this is crucial.

### 2.1 The "Online-First" Strategy
OrderMate prefers real-time data but gracefully handles offline scenarios.
1.  **App Launch**:
    *   Checks Connectivity.
    *   **If Online**: Authenticates with Supabase Auth.
    *   **If Offline**: Validates session against encrypted local hash in `local_users`.
2.  **Dashboard Load**:
    *   **Priority**: Always attempts to fetch live counts from Supabase.
    *   **Fallback**: If network fails, catches error and loads from SQLite (`ordermate_local.db`).
    *   **Consistency**: Logic for filters (e.g., `store_id`) is IDENTICAL between Supabase (PostgREST) and SQLite (SQL).

### 2.2 The Sync Engine (`SyncService`)
*   **Background Process**: Runs periodically or on specific triggers (App Resume, Manual Refresh).
*   **Push**: Uploads local `queue` items (Orders, New Partners) to Supabase.
*   **Pull**: Downloads delta changes (`updated_at > last_sync`) from Server to SQLite.
*   **Smart Refresh**: When Sync finishes, the Dashboard automatically refreshes online stats to ensure data is fresh.

---

## 🚀 Part 3: The User Flow (Start to End)

This is the functional path a user takes through the system.

### Phase 1: Onboarding
1.  **Sign Up/Login**: `/login` or `/register`.
2.  **Organization Setup**: `/onboarding/organization` (Create your generic business entity).
3.  **Store Setup**: `/onboarding/store` (Define physical branches/warehouses).
4.  **Team Setup**: `/onboarding/team` (Invite staff).

### Phase 2: Core Data (The Foundation)
Before booking orders, you need data:
1.  **Accounting Setup**:
    *   **Chart of Accounts**: Define GL accounts.
    *   **Voucher Prefixes**: Auto-numbering for Invoices (`SI-2026-001`).
    *   **Payment Terms**: Net 15, Net 30.
2.  **Inventory**:
    *   **Brands/Categories**: Classification.
    *   **Units of Measure**: kg, pcs, box.
    *   **Products**: The implementation details (`omtbl_products`).

### Phase 3: Relationships (CRM)
*   **Path**: `/customers` or `/vendors`.
*   **Action**: Create profiles.
*   **Logic**: Strict typing (`is_customer=1` vs `is_vendor=1`).

### Phase 4: Operations (The Daily Loop)
1.  **Order Booking**:
    *   Select Customer -> Add Items -> Set Discounts -> **Submit**.
    *   *Result*: Order is saved locally (status: `pending`) and synced.
2.  **Invoicing**:
    *   Convert Order to **Sales Invoice** (`SI`).
    *   Post to **General Ledger** (Debits/Credits auto-calculated).
3.  **Payments**:
    *   Record Receipt against Invoice.
    *   Updates `bank_cash` balance.

### Phase 5: Reporting (The "End")
1.  **Dashboard**: High-level metrics (Sales, Orders).
2.  **Ledgers**: Detailed transaction history per account.
3.  **Sales Reports**: Group by Customer/Product.

---

## 🛠️ Part 4: Code Architecture Guide

Where is everything?

### 4.1 Folder Structure (`lib/features/`)
*   **`auth`**: Login, Splash, Onboarding.
*   **`dashboard`**: Home screen logic & stats providers.
*   **`business_partners`**: Customers/Vendors repositories.
*   **`inventory`**: Products, Brands, UOMs.
*   **`orders`**: Order management logic.
*   **`accounting`**: The heavy lifting (GL, Invoices, Transactions).
*   **`organization`**: Multi-tenancy settings.

### 4.2 Key Routing (`lib/core/router/app_router.dart`)
*   **Standard Pattern**:
    *   List: `/resource` (e.g., `/customers`)
    *   Create: `/resource/create`
    *   Edit: `/resource/edit/:id`
    *   Detail: `/resource/:id`

---

## ❓ Part 5: Troubleshooting & Maintenance

### Common Issues
1.  **"Stats show Zero"**:
    *   **Cause**: Sync finished and overwrote UI with empty local data (Fixed in v3.0 by forcing Online check).
    *   **Verify**: Check Console for `Dashboard Online Counts: ...`.
2.  **"Duplicate Key Error"**:
    *   **Cause**: Offline ID collision.
    *   **Fix**: App uses UUIDs generated locally to prevent this.
3.  **"Route Not Found"**:
    *   **Check**: `app_router.dart` ordering. Ensure generic routes (`:id`) are LAST.

---

## ✅ Summary

You start at **Auth**, build your **Foundation** (Org/Accounting), execute **Operations** (Orders/Invoices), and end at **Reporting**. The system handles the complexity of syncing and offline storage transparently in the background.

*Documentation Generated by OrderMate Technical Team.*
