# OrderMate User Guide

Welcome to **OrderMate**, your comprehensive mobile companion for managing orders, inventory, and business relationships. This guide will help you navigate the application's features efficiently.

## 1. Getting Started

### Installation
1.  Download the API file (`app-release.apk`) to your Android device.
2.  Tap the file to install (you may need to allow "Install from Unknown Sources").
3.  Look for the **OrderMate** icon (Blue/Orange Pin with "OM") on your home screen.

## 2. Authentication

### Registration (New Users)
1.  Open the app and tap **"Create an account"**.
2.  **Basic Info:** Enter your Full Name, Mobile Number, and Password.
3.  **Organization:** Enter your **Organization / Store Name**. This is crucial for setting up your business identity.
4.  **Verification:**
    *   **Mobile:** You will receive an OTP (via WhatsApp or SMS). Enter it to verify.
    *   **Email:** A confirmation link may be sent (optional depending on settings).
5.  Tap **Register**.

### Logging In
*   **Online Mode:** Use your registered Email and Password. The app will sync your data and cache it for future offline use.
*   **Offline Mode:** If you have no internet, simply enter your credentials. As long as you have logged in online *at least once* before, the app will recognize you and let you in.

## 3. Dashboard
The **Dashboard** is your command center.
*   **Top Stats:** View total count of Customers, Products, and Vendors.
*   **Order Status:** Quick glance at how many orders are **Booked**, **Pending**, **Approved**, or **Rejected**.
*   **Note:** If you are offline, these numbers reflect the last time you promised synced with the server.

## 4. Managing Business Partners

### Customers
*   Navigate to **Menu > Customers**.
*   **View:** See a list of all your clients. Use the search bar to find specific names.
*   **Add:** Tap the **+** button. Fill in Name, Phone, and Address (Search address via map integration).
*   **Action:** Tap a customer to Edit details or Create a specific Order for them.

### Vendors (Suppliers)
*   Navigate to **Menu > Vendors**.
*   manage your suppliers similarly to customers. This is important for tracking where your inventory comes from (Purchase Orders).

## 5. Inventory & Products
*   Navigate to **Menu > Products** (or Inventory Dashboard).
*   **View Catalog:** See your products with images, prices, and stock levels.
*   **Add Product:** Tap **+**.
    *   **Details:** Name, SKU, Price, Cost.
    *   **Category/Brand:** Assign to organize your catalog.
    *   **Image:** Upload a product image for visual identification.

## 6. Orders
This is the core feature of OrderMate.

1.  Navigate to **Menu > Orders**.
2.  **Create New Order:** Tap **+**.
3.  **Select Type:**
    *   **Sales Order (SO):** Selling to a Customer.
    *   **Purchase Order (PO):** Buying from a Vendor.
4.  **Add Items:** Search for products and specify quantities. The total is calculated automatically.
5.  **Review & Submit:** Once confirmed, the order status defaults to **"Booked"** or **"Pending"** based on your role.

## 7. Organization Profile
*   Navigate to **Menu > Organization**.
*   View your setup details like Organization Name and Table Prefix.
*   Update your **Logo** or Tax Registration information here.

## 8. Troubleshooting

### "Invalid Offline Credentials"
*   **Cause:** You are trying to login offline, but you haven't logged in online on this specific device yet.
*   **Fix:** Connect to WiFi/Data once and login successfully. This saves your key safely in the secure storage.

### Data Not Updating?
*   Check your internet connection.
*   The app is designed to be **Offline-First**, meaning it shows you local data instantly. It syncs with the cloud in the background when connection is available.

### General Errors
*   If you see a red error screen, try restarting the app.
*   If the issue persists, contact support with the error message (e.g., "DatabaseException...").
