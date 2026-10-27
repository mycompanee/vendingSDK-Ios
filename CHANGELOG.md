# Changelog

All notable changes to the VendingIosSDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-XX

### Added
- Initial release of VendingIosSDK
- BLE communication with vending machines
- Authentication and API integration
- Transaction processing
- Delegate-based and closure-based APIs
- Objective-C compatibility
- Sample application
- Swift Package Manager support
- CocoaPods support
- Privacy manifest for iOS 17+ compliance

### Features
- Secure authentication with backend services
- Bluetooth Low Energy device communication
- Complete transaction lifecycle management
- Real-time status updates
- Error handling and recovery
- Thread-safe implementation

### Requirements
- iOS 13.0 or later
- Xcode 14.0 or later
- Swift 5.0 or later

---

## [1.0.1] - 2025-01-XX

### Changed
- Removed URL obfuscation from Config.m - API URLs are now in plain text for easier debugging and development
- Updated SDK version to 1.0.1

### Technical
- Simplified Config.m implementation by removing XOR obfuscation functions
- All API endpoints are now directly readable in source code

---

## [1.0.2] - 2025-01-XX

### Added
- Added `terminalName` property to `VendingTransactionResult` for easy access to terminal name
- Added `storeName` property to `VendingTransactionResult` for easy access to store name
- Added `transactionUUID` property to `VendingTransactionResult` for easy access to transaction UUID
- Extended `VendingSendTransactionResponse` to include `transactionUUID` field (mapped from `purseTransactionUUID` in API response)

### Changed
- Updated SDK version to 1.0.2
- Enhanced transaction result to include terminal name, store name, and transaction UUID as convenience properties

### Technical
- Added convenience properties to `VendingTransactionResult` that directly expose terminal name, store name, and transaction UUID
- Updated `VendingSendTransactionResponseObjC` to include transaction UUID
- Updated sample app to display the new transaction information fields

---

## [1.1.0] - 2026-09-01

### Added
- **Cost center support for vending transactions** (ported from the legacy myCompanee app)
  - If an RFID card linked to the user's purse has a cost center assigned, the transaction can be charged to that cost center instead of the user's purse
  - New API method `getAvailableCostCenters(authKey:apiKey:completion:)` (Swift `Result` and Objective-C compatible variant) — returns the cost centers available to the current purse via `GET /MobileApplication/GetExternalCardsWithCostCenter?purseUUID=`
  - New optional parameter `costCenterId` on `startVending(...)` (both delegate-based and closure-based variants, default `nil` = charge purse as before)
  - When a cost center is selected, a fixed dummy balance of 8888 cents is sent to the vending machine via BLE (`overrideBalance`), matching the legacy app behavior — the machine releases the sale and the server charges the cost center
  - The `costCenterId` is passed through to `SendVendingTransaction`, so the backend books the transaction on the cost center
- New models: `CardsWithCostCenter`, `PurseCardsWithCostCenter`, `CostCenterObjC` (Objective-C compatible wrapper)
- `PurseExtCardNumber` extended with `costCenterId` field
- `VendingSendTransactionResponseObjC` and `VendingTransactionResult` now expose the booked cost center (`costCenter`, `costCenterIdentifier`, `costCenterName`)
- Sample app: cost center selection action sheet ("Bitte Kostenstelle auswählen" / "Börse nutzen") before starting a vending session, and the booked cost center is shown in the transaction result
- **Training mode for vending machines** (ported from the legacy myCompanee app; Swift only)
  - Maintenance/setup mode for service technicians: no real transactions are sent; each dispensed product is reported for article assignment
  - New API method `getPurseInfo(authKey:apiKey:completion:)` and `VendingSDK.isTrainingPurse(_:)` — a purse named "TRAININGMODE" enables the training flow; the host app asks the user (like the legacy "Im Trainingsmodus starten?" dialog)
  - New optional parameters `trainingMode` and `trainingProductCallback` on the closure-based `startVending(...)`
  - BLE differences (match legacy BLE.cs): fixed dummy balance of 9999 cents (takes precedence over the cost center override), sale acknowledged with 0x0c instead of 0x0a, no local balance deduction, idle timeout disabled (connection stays open), app data re-armed after 2 seconds so consecutive assignments work without reconnecting, status messages suffixed with "(TRAINING)"
  - Journal entries are sent via `POST /crud/JournalEntries` (fire-and-forget, legacy event types and message formats, user id instead of user name): START_TRAINING before connecting, PRODUCT_SELECT per dispense, FINISH_TRAINING on disconnect/abort
  - New APIs for the article assignment flow: `createVendingArticle(...)` (POST /crud/VendingArticles with case-insensitive PLU duplicate check), `assignVendingArticle(...)` (creates or overwrites VendingMachineArticleMappings incl. ARTICLE_ASSIGN / OVERWRITE_ASSIGNMENT journal entries), `reloadVendingBaseData(...)`
  - New models: `JournalEntry`, `JournalEventType`, `VendingTrainingProduct`; `Purse` extended with `name`
  - Sample app: training confirmation dialog and article assignment UI ("Artikel zuordnen" with filter, article creation via [PLU]:[Name], assignment confirmation), port of the legacy VendingArticleTraining page

### Changed
- Updated SDK version to 1.1.0
- `abortVending()` now disconnects first so the training FINISH journal entry is sent before callbacks are cleared
- BLE poll (0x55) now answers with 0x06 only while app data is pending (matches legacy behavior, required for training re-arm)

---

## [1.2.0] - 2026-10-27

### Fixed
- **"Loading vending data" no longer blocks on `GetLocationsWithPurse`** (fixed an extreme slowdown on large tenants, e.g. tenant 2035)
  - The SDK previously called the parameterless `GET /MobileApplication/GetLocationsWithPurse` on every session start, which returns **every purse of the tenant** (4,300+ purses on tenant 2035, serialized via an N+1 per-purse location query) — while the result was **never used** by the SDK at all
  - The call has been removed entirely; the vending base data (`GetVendingBaseData`) is the only request in this step now, and the purse continues to be resolved via the third-party API. The legacy app was never affected because it only queries the user's own purses (`GetLocationsWithPurse/{userId}`, indexed)
  - Removed the unused private `getLocationsWithPurse` helper (`ClientServiceAPI.getLocationsWithPurse` remains available for future use)
- **Price override rules from the backend (`VendingMachinePriceMappings`) are now applied** (fixes a parity gap to the legacy app and the backend OnlineVendingService)
  - Previously the machine-reported sale price was forwarded to `SendVendingTransaction` unchanged; the backend books the client-reported amount 1:1, so configured per-user-group / sub-user-group / price-list overrides (e.g. subsidized prices) were silently ignored and users were overcharged
  - The resolved article mapping (including the standard-article fallback on selection -1) is now the base for the price override lookup, exactly like the legacy `Ble_SaleComplete`
  - Match rules (last one wins): user group only, sub user group only, price list only, user group + sub user group, user group + sub user group + price list
  - Sales only: loading events (negative amounts) are never overridden; negative override prices are passed through and booked as a credit, matching the legacy behavior
  - When an override changes the price, a status update `Price override applied: <machine> -> <override> cents` is emitted
  - The overridden amount is used for the backend transaction and reported in `VendingTransactionResult.amount`

### Added
- `Purse` model extended with `subUserGroupId` (decoded from `subUserGroupId`, provided by `GetPurseByUUID`; required for the sub-user-group price override rules)

### Changed
- **Minimum deployment target raised from iOS 13.0 to iOS 15.0** (Xcode 27 no longer supports deployment targets below iOS 15.0; updated in the Xcode project, `Package.swift`, the podspec and the docs)
- Updated SDK version to 1.2.0
- Podspec `spec.version` synchronized with the SDK version (was still at 1.0.0)

---

## [Unreleased]

### Planned
- Enhanced error types and error handling
- Additional configuration options
- Performance optimizations
- Extended logging capabilities

