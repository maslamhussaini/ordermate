# OrderMate Enterprise SaaS Technical Documentation

**Version:** 2.0.0 (Enterprise Gold)  
**Status:** FINAL / LOCKED  
**Date:** January 2026

---

## 1. Executive Summary
OrderMate is an enterprise-grade, offline-first SaaS mobile application designed for seamless order booking, inventory management, and business partner relations. Built on a robust **Flutter** foundation with a scalable **Supabase** backend, it employs a strict **Clean Architecture** to ensure maintainability, scalability, and testability.

This document serves as the single source of truth for the system's technical implementation, security protocols, and architectural decisions.

---

## 2. Architecture & Design Patterns

### 2.1 Clean Architecture
The application strictly follows the **Feature-First Clean Architecture** pattern, enforcing a unidirectional data flow and separation of concerns:

*   **Presentation Layer (`lib/features/*/presentation`)**:
    *   **UI**: Reactive Flutter widgets implementing Material 3 Design.
    *   **State Management**: `Riverpod` (Notifiers/Providers) handles UI state and interacts with Use Cases.
*   **Domain Layer (`lib/features/*/domain`)**:
    *   **Entities**: Pure Dart objects representing business logic (e.g., `Order`, `BusinessPartner`).
    *   **Use Cases**: Encapsulate specific business rules (e.g., `SubmitOrder`, `SyncOfflineTransactions`).
    *   **Repository Interfaces**: Abstract contracts defining data operations.
*   **Data Layer (`lib/features/*/data`)**:
    *   **Repositories**: Concrete implementations of domain interfaces.
    *   **Data Sources**:
        *   *Remote*: Supabase API calls (PostgREST).
        *   *Local*: SQLite (sqflite) integration for offline persistence.

### 2.2 Offline-First Strategy
OrderMate treats "Offline" as a first-class citizen, not an error state.
*   **Local-First Reads**: Data is primarily served from the local SQLite database for instant UI response.
*   **Sync Logic**: A specialized `SyncService` operates in the background:
    *   **Pull**: Fetches changes from Supabase (based on `updated_at` timestamps) and updates local tables.
    *   **Push**: Offline actions are queued in a `sync_queue` table and replayed sequentially when connectivity is restored.
*   **Resiliency**: Handled via `connectivity_plus` to detect network changes and trigger sync events automatically.

---

## 3. SaaS Multi-Tenancy & Security

### 3.1 Multi-Organization Model
OrderMate utilizes a **Row-Level Security (RLS)** based multi-tenancy model to ensure strict data isolation between SaaS tenants (organizations).
*   **Organization Table**: `omtbl_organizations` serves as the root for tenancy.
*   **Data Isolation**: Every operational table (e.g., `products`, `orders`) includes an `organization_id` column.
*   **RLS Policies**: Postgres policies enforces that users can only `SELECT`, `INSERT`, or `UPDATE` rows where `organization_id` matches their user profile's assigned organization.

### 3.2 Role-Based Access Control (RBAC)
User permissions are granularly managed via a role hierarchy:
1.  **Owner**: Full control over organization, subscription, and user management.
2.  **Admin**: Operational control, can manage staff and inventory but not billing.
3.  **Staff**: Daily operations (Order booking, customer management).
4.  **Viewer**: Read-only access for auditing or basic metrics.

Roles are linked to the `omtbl_users` profile table and enforced via both:
*   **Backend**: RLS Policies preventing unauthorized writes.
*   **Frontend**: UI guards hiding restricted features (e.g., Admin settings).

### 3.3 Authentication & Session Management
*   **Provider**: Supabase Auth (GoTrue).
*   **Strategies**: Email/Password and Mobile OTP (WhatsApp/SMS).
*   **Token Handling**: JSON Web Tokens (JWT) are used for API authorization. Tokens are automatically refreshed by the SDK and persisted securely.
*   **Session**:
    *   *Online*: Validated against Supabase Auth.
    *   *Offline*: Validated against a secure, encrypted local hash in `local_users` to allow app access without internet.

---

## 4. Feature Modules

### 4.1 Business Partners (CRM)
Unified management for Customers, Vendors, and Suppliers.
*   **Schema**: Consolidated into `omtbl_businesspartners` with boolean flags (`is_customer`, `is_vendor`).
*   **Geolocation**: Integrated OpenStreetMap (OSM) and GPS for customer address tagging and route optimization.
*   **Validation**: Advanced form validation for phone numbers and email formats.

### 4.2 Inventory & Products
*   **Catalog**: Supports complex product attributes (SKU, price, cost, tax).
*   **Stock Tracking**: Real-time inventory deduction upon order confirmation.
*   **Images**: Product imagery stored in Supabase Storage buckets with public URLs cached locally.

### 4.3 Order Management
*   **Workflow**: `Draft` -> `Confirmed` -> `Shipped` -> `Delivered` / `Cancelled`.
*   **Calculation**: Centralized logic for Subtotal, Tax, and Grand Total calculation to prevent client-side float errors.
*   **PDF Generation**: On-device generation of Invoices/Receipts using the `pdf` and `printing` packages.

---

## 5. Deployment & Scalability

### 5.1 Infrastructure
*   **Backend**: Serverless (Supabase) scaling automatically with request load.
*   **Database**: PostgreSQL 15+ with extensions (`pgcrypto`, `postgis` for geo-queries).
*   **Edge Functions**: Deno-based serverless functions for critical tasks (e.g., Sending WhatsApp OTPs, Periodic Reports).

### 5.2 Build & Release
*   **CI/CD**: Automated builds for Android (APK/AAB) via GitHub Actions (configured).
*   **Versioning**: Semantic versioning (e.g., `1.0.1+2`) tracked in `pubspec.yaml`.
*   **Tree Shaking**: Enabled for release builds to minimize APK size (currently ~18MB).
*   **Obfuscation**: Code obfuscation enabled for release builds to protect IP.

---

## 6. Future Roadmap

*   **Q1 2026**:
    *   Advanced Analytics Dashboard with PowerBI integration.
    *   Stripe/Payment Gateway integration for in-app invoice settlement.
*   **Q2 2026**:
    *   Multi-warehouse support (Inventory transfer).
    *   Driver/Delivery Management App (Companion Map).
*   **Q3 2026**:
    *   AI-powered demand forecasting (using historical order data).

---

© 2026 OrderMate Inc. All Rights Reserved.
Confidential & Proprietary.
