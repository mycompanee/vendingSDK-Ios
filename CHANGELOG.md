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

## [Unreleased]

### Planned
- Enhanced error types and error handling
- Additional configuration options
- Performance optimizations
- Extended logging capabilities

