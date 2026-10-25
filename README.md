# Kamal Bhandar

Android grocery ordering app for Kamal Bhandar. Approved customers browse the
catalogue, build a cart in grams, kilos, pieces or bags, and place a pickup
order. The owner approves customers, gets a loud alert for every new order,
adjusts orders when something is short, and records payment at pickup.

Version 1 choices: prices hidden from customers, pickup only, pay at the store
(cash, UPI or card), free push notifications, ₹0 running cost, app file shared
directly (Play Store later).

## What is in this repository

| Folder | What it is |
| --- | --- |
| `app/` | The Flutter Android app. Customer and owner screens in one app; the owner role unlocks the owner screens. |
| `functions/` | Cloud Functions (TypeScript, Mumbai region): registration, approvals, placing and adjusting orders, notifications, nightly backup, billing kill switch. |
| `firestore.rules`, `storage.rules` | Security rules. The phone can read only what its user may see and can write almost nothing directly. |
| `rules-tests/` | Tests for the security rules, run against the Firebase emulator. |
| `scripts/` | One-off admin scripts: give the owner role, load a starter catalogue. |
| `hosting/public/` | Privacy policy and account-deletion pages (needed for the Play Store). |
| `docs/` | [Setup guide](docs/SETUP.md) and [release guide](docs/RELEASE.md). |

## How an order flows

1. Customer signs in with Google and fills in name, mobile and address. The owner gets a "New sign-up" notification.
2. Owner calls if needed and approves. The customer is notified and can shop.
3. Customer adds items, reviews and confirms. `placeOrder` re-reads every product on the server, checks quantities, gives the order a number like `KB-2026-000123`, locks it and empties the cart.
4. Owner gets a loud "New order" notification, packs the order, and adjusts quantities if something is short (the customer is told).
5. Owner marks it ready (customer notified), then picked up with the payment method.

## Running the checks

```sh
# Server functions: build and unit tests
cd functions && npm ci && npm run build && npm test

# Security rules against the emulator (needs Java 21)
cd rules-tests && npm ci && npm test

# App: static checks and tests (Flutter 3.47.8)
cd app && flutter pub get && flutter analyze && flutter test
```

GitHub Actions runs all three on every push and pull request, and builds a test
APK when the `GOOGLE_SERVICES_JSON` secret is set.

## Data model

Quantities are whole numbers in a base unit (grams, pieces or bags) and money is
whole paise, so there are no rounding errors. Each order keeps a copy of the
customer's details and each item's name and price at the time of ordering, so
history never changes when products or profiles do.

| Collection | Holds |
| --- | --- |
| `users/{uid}` | Profile, status (pending, approved, rejected, blocked), role |
| `users/{uid}/devices/{token}` | One per phone, for notifications |
| `categories/{id}`, `products/{id}` | Catalogue; products have up to three sell modes |
| `carts/{uid}` | The customer's cart |
| `orders/{id}` | Locked orders with status history |
| `auditLog/{id}` | Who changed what (approvals, adjustments, status) |
| `settings/store` | Store name, pickup hours, show prices switch |
| `counters/orders` | Next order number for the year |
