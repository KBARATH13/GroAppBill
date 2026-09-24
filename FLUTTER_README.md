# GroAppBill Flutter App

GroAppBill is a Flutter application for grocery billing, inventory management, water-bottle deposit tracking, user access, and shop configuration. It is built with Flutter and Riverpod, uses Firebase for authentication and cloud data, and is designed to keep core billing work available when the device is temporarily offline.

## Overview

This app supports a shop workflow where:
- an admin manages inventory and settings
- operators (approved users) create bills from the catalog
- product data is synced between local state and Firestore
- items can be scanned by barcode and added to a billing cart
- settings include printer configuration and shop metadata
- an additional water-bottle deposit tracking workflow exists alongside the grocery billing flow
- bills are saved locally first, removed from the active cart, and uploaded in creation order when connectivity returns
- pending uploads are visible in bill history and can be synchronized manually

## Tech Stack

- Flutter SDK: 3.11.1+
- Dart: modern Flutter SDK
- State management: Riverpod
- Local persistence: SharedPreferences and Firestore offline persistence
- Backend/auth: Firebase Auth + Firestore
- Barcode scanning: mobile_scanner
- Sharing / receipt flow: share_plus
- Network logic: http
- Date/time formatting: intl
- Connectivity checks: connectivity_plus

## Architecture

The application follows a feature-oriented Flutter architecture with a clear separation between UI, state, domain models, and persistence services:

```text
Flutter widgets/screens
        |
        v
Riverpod providers and controllers
        |
        v
Domain models and feature rules
        |
        +--> SharedPreferences (local cart, inventory cache, billing queue)
        |
        +--> Firebase Auth / Firestore (users, shop data, uploaded bills)
        |
        +--> Connectivity listener (retries pending bill uploads)
```

Screens own presentation and user interaction. Providers hold reactive state and coordinate updates. Models define serializable business data. Services isolate Firebase, local persistence, printer, and synchronization details from the widgets.

### Application bootstrap

`lib/main.dart` initializes Flutter and Firebase, enables unlimited Firestore offline persistence, attempts to upload queued bills for the signed-in user, and registers a connectivity listener. When the auth provider resolves, the app displays the login screen, pending-approval screen, or the main home shell.

### State boundaries

- `auth_providers.dart` exposes the signed-in Firebase user and the application-level role/approval record.
- `inventory_providers.dart` owns products, categories, usage counts, local inventory changes, and publishing.
- `cart_provider.dart` owns multiple carts, the active cart, cart persistence, quantity changes, and per-cart price overrides.
- `history_providers.dart` exposes local billing history and pending-upload state to the history UI.
- `water_bottle_provider.dart` owns customer records, search state, local cache, and Firestore record updates.
- `navigation_provider.dart`, `shop_provider.dart`, and `address_provider.dart` hold shared shell and shop metadata state.

## Project Structure

```text
lib/
├── main.dart                    # App bootstrap and route selection
├── models/
│   ├── address.dart
│   ├── app_user.dart            # Auth user + admin/operator role model
│   ├── bill.dart                # Bill object model
│   ├── billing_history.dart     # Past bill history records
│   ├── cart_item.dart           # Cart line item model
│   ├── index.dart               # Models export barrel
│   ├── product.dart             # Product catalog model
│   ├── shop_info.dart           # Shop name, categories, units, metadata
│   └── water_bottle_record.dart # Water bottle deposit customer tracking
├── providers/
│   ├── address_provider.dart
│   ├── app_providers.dart       # Core app providers
│   ├── auth_providers.dart      # Auth-related provider state
│   ├── billing_controller.dart
│   ├── cart_provider.dart       # Cart logic and state
│   ├── history_providers.dart   # History state
│   ├── inventory_providers.dart # Inventory + product state
│   ├── navigation_provider.dart # Tab navigation state
│   ├── shop_provider.dart       # Shop metadata state
│   ├── water_bottle_provider.dart
│   └── ...
├── screens/
│   ├── admin_screen.dart        # Inventory management UI
│   ├── billing_screen.dart      # Main sales/billing UI
│   ├── calculator_screen.dart   # Quick calculator screen
│   ├── cart_screen.dart         # Cart display and actions
│   ├── history_screen.dart      # Past bill list / history
│   ├── home_screen.dart         # App shell with nav + app bar
│   ├── index.dart               # Screens export barrel
│   ├── login_screen.dart        # Login/auth UI
│   ├── settings_screen.dart     # Printer, account, shop config
│   └── water_bottle_screen.dart # Bottles deposit records UI
├── services/
│   ├── auth_service.dart        # Firebase auth + user management
│   ├── history_service.dart
│   ├── printer_service.dart     # Printer config and discovery logic
│   ├── sync_service.dart        # Firestore sync for inventory/shop data
│   └── water_bottle_service.dart
├── utils/
│   └── ...
├── widgets/
│   ├── address_info_card.dart
│   ├── bill_preview_dialog.dart
│   ├── cart_selection_tabs.dart
│   ├── glass_container.dart
│   ├── numpad_input_sheet.dart
│   ├── product_form_dialog.dart
│   ├── vibrant_background.dart
│   └── ...
└── main.dart
```

## App Flow

### Startup and auth
The app entry point in [lib/main.dart](lib/main.dart) does the following:
1. initializes Flutter bindings
2. initializes Firebase
3. enables Firestore offline persistence
4. loads the current user from Firebase auth
5. routes to either login, approval wait screen, or home screen

The app user object includes role and approval information, and is stored in Firestore under the `users` collection.

### Login and approval model
The app supports two user roles:
- admin
- operator

New operator accounts are created as pending until approved by an admin. Admin accounts are approved by default. The auth service validates role and access rules before allowing login.

### Home navigation
The home screen provides the primary application shell with:
- billing tab
- water bottle tab
- admin tab (admin only)
- settings access
- calculator
- bill history access

It also includes prompts before leaving the admin section when there are unpublished inventory changes.

## Core Features

### 1. Billing workflow
The billing screen supports:
- product search and filtering
- category-based browsing
- quantity/weight entry using custom numpad UI
- barcode scanning for item lookup using linear formats only; QR, Data Matrix, PDF417, Aztec, and other non-retail codes are rejected with placement guidance
- cart creation and updates
- custom pricing override when needed, including direct price editing for every cart unit type
- operator and delivery metadata

The cart state is handled through Riverpod and supports three independent carts. The active cart is persisted locally. Quantity changes, scanned products, stale scanned prices, and custom price overrides all update the same cart model and recalculate totals.

### 2. Local-first billing and upload queue

Saving or printing a bill first creates a local `BillingHistoryRecord`. The active cart is cleared after the save operation succeeds, so billing can continue without waiting for Firebase. Each local record contains a creation timestamp, bill identity, upload flag, and Firestore document ID.

`HistoryService` maintains the local history and pending queue in SharedPreferences. Pending records are sorted by `createdAtMs` and uploaded oldest first. A failed upload stops the current batch so later bills cannot overtake an earlier bill. Upload retries occur:

1. at application startup
2. when `connectivity_plus` reports a usable connection
3. when the user selects Sync Now from bill history

The history screen displays pending counts and upload status. Local records remain available while offline and are marked uploaded only after Firestore accepts the write.

### 3. Inventory management
The admin screen allows:
- listing products by inventory data
- barcode scanning to locate products
- adding products
- editing product metadata
- deleting products from the catalog
- category overview cards with item counts and direct category filtering
- publishing inventory data to Firestore

The inventory provider keeps a local cache in SharedPreferences and syncs from Firestore in real time, so changes are retained even when offline.

### 4. Shop configuration and settings
The settings screen contains:
- printer configuration
- printer discovery on the local network
- shop profile metadata
- user approval and permission setup
- account management actions like approve, reject, and block users

This makes the app suitable for a small retail or grocery operation with role-based access.

### 5. Water bottle deposit tracking
The water bottle feature is a separate record management system for customers purchasing bottles with deposits. It supports:
- customer name and address capture
- multiple bottle entries
- bottle type selection
- payment method tracking
- deposit amount calculation
- add, edit, and confirmed delete flows
- newest-first sorting
- filtering by all records, today, last seven days, this month, or previous month
- creation dates preserved when an existing customer is edited

This is a separate domain from grocery inventory and serves a distinct operational need.

### 6. Billing history and calculators
The app includes:
- a bill/history screen
- a calculator screen
- a history service and provider layer to track prior billing records

This supports a single-machine retail workflow where recent records can be reviewed quickly.

## State Management Design

The app uses Riverpod providers to centralize state. The main providers include:
- appUserProvider: current auth user and approval state
- productsProvider: inventory list and product operations
- cartProvider: active customer cart
- shopInfoProvider: shop metadata and categories/units
- navigationProvider: home tab selection
- userProvider: local operator identity

This keeps UI screens simple and makes the app easier to extend without over-coupling view logic.

## Persistence and Sync

The app uses a local-first persistence model:
- SharedPreferences stores carts, cached inventory, billing history, the pending bill queue, and the water bottle cache.
- Firestore offline persistence provides local caching for Firestore-backed reads and writes.
- Firestore stores the cloud copy of users, shop products, bills, and water bottle records.
- Connectivity changes trigger ordered upload retries for locally saved bills.

Inventory, shop metadata, bills, and water bottle records are synchronized by service/provider layers. Firebase Auth and the users collection provide identity, role, approval, and permission state.

## Printer Integration

The app includes printer configuration and discovery logic in [lib/services/printer_service.dart](lib/services/printer_service.dart). It supports:
- saving printer host and port
- testing connections
- discovering printers on the local network
- preparing the app for thermal receipt printing workflows

## Firebase Structure

The project expects Firestore collections such as:
- users
- shops
- shops/{adminEmail}/products
- shops/{adminEmail}/bills
- shops/{adminEmail}/waterBottleRecords

This pattern organizes data by shop owner/admin email, allowing a multi-user retail setup with per-shop separation.

### Local storage keys

The main SharedPreferences stores include:
- `grocery-carts`: the three local carts and active cart index
- `billing_history`: recent local billing records
- `billing_pending_upload`: serialized records waiting for Firestore upload
- `water-bottle-records`: cached water bottle customer records
- `grocery-sync-timestamp`: last inventory publish timestamp

## Setup

### Prerequisites
- Flutter SDK 3.11.1 or newer
- Firebase project configured
- Android SDK and an Android device or emulator
- Firebase Android configuration in `android/app/google-services.json`

### Install dependencies
```bash
flutter pub get
```

### Run app
```bash
flutter devices
flutter run -d <android-device-id>
# Chrome is available as a development fallback:
flutter run -d chrome
```

The production target for GroAppBill is Android. Windows desktop support is not required for the application and Windows C++ toolchain errors can be ignored unless desktop support is intentionally enabled later.

### Firebase configuration
Ensure Firebase is initialized properly in the app and that the required `google-services.json` / platform config files are present for Android.

## Current Project Notes

This README reflects the actual project state in the repository rather than a generic starter-template description. The app currently includes:
- Firebase auth and role-based approval flow
- inventory management with catalog sync
- local-first billing with ordered pending-upload synchronization
- billing cart workflow with quantity editing and all-unit price editing
- linear-barcode-only scanning with unsupported-code feedback
- custom admin controls and settings
- water bottle deposit tracking with date filters and customer deletion
- history/calculator screens
- printer configuration tools for Android-connected/local-network printers

## Suggested next improvements

- add stronger unit/integration tests for billing and provider logic
- centralize Firestore document schemas and validation
- add cleaner app error handling for offline/cloud sync failures
- add automated tests for the local-first save and ordered upload queue
- improve receipt formatting and printer integration coverage
- document Firestore collection contracts and admin-user approval flow

## Summary

GroAppBill is a specialized Flutter retail and billing application for a grocery shop. It combines inventory management, billing, local persistence, Firebase synchronization, role-based access, and printer configuration into a single mobile application workflow.

## 🐛 Troubleshooting

### Backend Connection Issues
- Verify Firebase configuration and Firestore security rules.
- Check the signed-in user's admin/shop association.
- Confirm network connectivity when cloud sync is expected.

Bills can still be saved locally while offline. Check the history screen for pending uploads and use Sync Now after connectivity returns.

### Printer Issues
- Test the printer connection from the app's printer settings
- Verify network connectivity to printer
- Check printer IP address
- Ensure printer supports ESC/POS commands

### Data Not Persisting
- Check SharedPreferences permissions
- Verify app has storage access (for Android)
- Clear app data and reinstall if needed

## 📝 License

This project is part of the Grocery Billing System suite.

---

**Developed**: March 2026
**Version**: 1.0.0
