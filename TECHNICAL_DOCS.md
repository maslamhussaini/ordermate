# OrderMate Technical Documentation

## 1. Project Overview
OrderMate is a robust, offline-first field sales and ordering application built with Flutter. It helps businesses manage orders, products, and business partners (customers/vendors) seamlessly, even in environments with unstable internet connections. The app supports multi-tenancy, allowing multiple organizations to use the platform securely.

## 2. Technology Stack

### Frontend & Mobile
*   **Framework**: [Flutter](https://flutter.dev/) (Windows, Android, iOS)
*   **Language**: Dart
*   **State Management**: [Riverpod](https://riverpod.dev/) for reactive state and dependency injection.
*   **Navigation**: GoRouter (Inferred).

### Backend & Database
*   **Backend-as-a-Service (BaaS)**: [Supabase](https://supabase.com/).
*   **Remote Database**: PostgreSQL.
*   **Local Database**: SQLite (via `sqflite` and `sqflite_common_ffi` for Desktop).
*   **Authentication**: Supabase Auth.
*   **Remote Logic**: Supabase Edge Functions (for specific tasks like WhatsApp OTP).

## 3. Architecture
The application follows a **Clean Architecture** approach, emphasizing separation of concerns:

*   **Presentation Layer** (`lib/features/*/presentation`): UI widgets and Riverpod notifiers.
*   **Domain Layer** (`lib/features/*/domain`): Entities and abstract repository definitions.
*   **Data Layer** (`lib/features/*/data`): Repositories implementations, DTOs (Models), and Data Sources (Local/Remote).
*   **Core** (`lib/core`): Shared utilities, configuration, network clients, and the base database helper.

### Offline-First Strategy
The app is designed to work offline by default:
1.  **Read**: UI reads from the **Local SQLite Database**.
2.  **Write**: User actions write to the Local SQLite Database and add an entry to the `sync_queue` table.
3.  **Sync**: A background service monitors connectivity and processes the `sync_queue` to push changes to Supabase. It also pulls updates from Supabase to keep local data fresh.

## 4. Database Structure

### 4.1 Remote Database (PostgreSQL / Supabase)
Prefix: `omtbl_` (OrderMate Table)

#### Core Entities

**`omtbl_organizations`**
*   Represents a tenant or company using the system.
*   `id`: SERIAL PRIMARY KEY
*   `name`: TEXT NOT NULL
*   `code`: TEXT UNIQUE
*   `is_active`: BOOLEAN
*   `subscription_tier`: TEXT (e.g., 'free')
*   `subscription_status`: TEXT
*   `stripe_customer_id`: TEXT
*   `logo_url`: TEXT

**`omtbl_stores`**
*   Physical branches or locations under an organization.
*   `id`: SERIAL PRIMARY KEY
*   `organization_id`: FK -> `omtbl_organizations`
*   `name`: TEXT NOT NULL
*   `location`: TEXT
*   `is_active`: BOOLEAN

**`omtbl_users`**
*   App users linked to Supabase Auth.
*   `id`: UUID PRIMARY KEY (often matches Auth UID)
*   `auth_id`: UUID FK -> `auth.users`
*   `email`: TEXT
*   `full_name`: TEXT
*   `organization_id`: FK -> `omtbl_organizations`
*   `store_id`: FK -> `omtbl_stores`
*   `role_id`: FK -> `omtbl_roles`

**`omtbl_businesspartners`**
*   Unified table for Customers, Vendors, and Employees.
*   `id`: UUID PRIMARY KEY
*   `organization_id`: FK -> `omtbl_organizations`
*   `store_id`: FK -> `omtbl_stores`
*   `name`: TEXT
*   `phone`: TEXT
*   `email`: TEXT
*   `address`: TEXT
*   `is_customer`: BOOLEAN
*   `is_vendor`: BOOLEAN
*   `is_employee`: BOOLEAN
*   `manager_id`: FK -> `omtbl_businesspartners` (Self-referencing for hierarchy)
*   `updated_by`: UUID

**`omtbl_products`**
*   Product catalog.
*   `id`: UUID PRIMARY KEY
*   `organization_id`: FK -> `omtbl_organizations`
*   `store_id`: FK -> `omtbl_stores`
*   `name`: TEXT
*   `sku`: TEXT
*   `rate`: NUMERIC
*   `cost`: NUMERIC
*   `stock_quantity`: INTEGER
*   `vendor_id`: FK -> `omtbl_businesspartners` (where is_vendor=true)
*   `items_payload`: JSONB (For complex variations)
*   `created_by`: UUID
*   `updated_by`: UUID

**`omtbl_orders`**
*   Sales orders.
*   `id`: UUID PRIMARY KEY
*   `organization_id`: FK -> `omtbl_organizations`
*   `store_id`: FK -> `omtbl_stores`
*   `order_number`: TEXT
*   `customer_id`: FK -> `omtbl_businesspartners`
*   `total_amount`: NUMERIC
*   `status`: TEXT
*   `order_date`: TIMESTAMP
*   `items_payload`: JSONB (Stores line items as JSON)
*   `created_by`: UUID
*   `updated_by`: UUID

#### Access Control
**`omtbl_roles`**
*   Definitions for 'Super User', 'Admin', 'Manager', 'Booker'.

**`omtbl_privileges`** & **`omtbl_role_privileges`**
*   Fine-grained permission keys managed via many-to-many mapping.

---

### 4.2 Local Database (SQLite)
Prefix: `local_`
Used for offline caching.

**`sync_queue`**
*   Tracks changes waiting to be pushed to the server.
*   `action`: 'CREATE', 'UPDATE', 'DELETE'
*   `entity`: e.g., 'ORDER', 'CUSTOMER'
*   `payload`: JSON String
*   `status`: 0 (Pending), 1 (Processing), 2 (Failed)

**`local_businesspartners`**
*   Mirrors `omtbl_businesspartners`.
*   Adds `is_synced` (0/1) to track sync status.

**`local_products`**
*   Mirrors `omtbl_products`.
*   Includes `items_payload` for offline cart management.

**`local_orders`**
*   Mirrors `omtbl_orders`.

**`local_users`**
*   Stores basic user info for offline login capabilities.

**`local_deleted_records`**
*   Keeps track of IDs deleted while offline so the delete command can be sent to the server later.

**`sync_metadata`**
*   Stores the timestamp of the last successful pull for each entity type to support incremental syncing.

## 5. Security Models
*   **Row Level Security (RLS)**: Implemented in Supabase PostgreSQL using `get_my_org_id()` function.
    *   **Isolation**: Users can only Query/Mutate data belonging to their `organization_id`.
*   **Local Encryption**: (Planned/To-Verify) Sensitive data in SQLite should ideally be encrypted if the device is shared.

## 6. Directory Structure
```
lib/
├── core/                   # Global Singletons, Configs
│   ├── database/           # SQLite Helper
│   ├── network/            # Supabase Client
│   └── services/           # Background Services (Sync, Auth)
├── features/               # Feature Modules
│   ├── auth/               # Login, Registration, OTP
│   ├── business_partners/  # Unified Customer/Vendor/Employee Management
│   ├── dashboard/          # Main App Shell & Navigation
│   ├── inventory/          # Stock Management
│   ├── orders/             # Sales & Transaction Processing
│   ├── organization/       # Organization & Store Settings
│   ├── product/            # Product Catalog (Legacy/Aliased)
│   ├── settings/           # App Settings (Print, Sync, etc.)
│   ├── [legacy]            # customers/, vendors/ (Being consolidated into business_partners)
└── main.dart               # Entry Point
```

## 7. Migration Guide
Database changes are tracked via SQL files in the `lib` root (and stored in the repo).
*   **Applying Changes**: Major schema updates run via `_onUpgrade` in `DatabaseHelper` for local DB, and should be applied via Supabase Dashboard SQL Editor for remote DB using the provided `.sql` files.
