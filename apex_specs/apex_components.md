# Shared Components and APEX Infrastructure Guide

## 1. Application Items & Application Processes
- **Application Items:**
  - `F_APP_USER_ID`
  - `F_INV_ORG_ID`
  - `F_TERMINAL_ID`
  - `F_SHIFT_ID`
  - `F_LEGAL_ENTITY_ID`
- **Application Processes:**
  - `APEX_AFTER_AUTH`: Context initialization calling `POS_CTX_PKG.SET_SESSION_CONTEXT` to set global context parameters upon successful login.

## 2. Shared Lists of Values (LOVs)
Dynamic LOVs with SQL definitions for application-wide consistency:
- `LOV_INVENTORY_ORGS`
- `LOV_SUBINVENTORIES`
- `LOV_CATEGORIES`
- `LOV_PRICE_LISTS`
- `LOV_CUSTOMERS`
- `LOV_PAYMENT_METHODS`
- `LOV_TAX_RATES`

## 3. REST Data Sources & ORDS Endpoints
Specification of all REST APIs needed for PWA sync:
- `GET /items`: Fetch product catalog delta for local IndexedDB cache.
- `POST /sync/orders`: Sync offline orders to server.
- `POST /sync/batch`: Batch sync of operational data.
- `GET /health`: Health check endpoint to determine network status and ORDS availability.

## 4. Custom APEX Plugins & Dynamic Action Plugins
- **Barcode Scanner Wedge Plugin:** Intercepts wedge scanner inputs to prevent keyboard misfires and cleanly formats the scan payload.
- **WebSerial / ESC/POS Receipt Printer Plugin:** Communicates directly with hardware printers from the browser without middleware, using the WebSerial API.
- **Offline Status & Auto-Sync Bar Plugin:** Persistent UI element showing offline queue size and auto-syncing when connectivity is restored.
