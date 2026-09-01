# VendingIosSDK

[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

iOS SDK for integrating vending machine functionality into your iOS applications. The SDK provides a complete solution for Bluetooth Low Energy (BLE) communication with vending machines, handling authentication, transaction processing, and device management.

## Features

- 🔐 **Authentication**: Secure authentication with backend services
- 📡 **BLE Communication**: Bluetooth Low Energy integration for vending machine communication
- 💳 **Transaction Processing**: Complete transaction lifecycle management
- 🎯 **Simple API**: Easy-to-use delegate-based and closure-based APIs
- 🔄 **Objective-C Compatible**: Full Objective-C interoperability
- 📱 **iOS 13+ Support**: Compatible with iOS 13.0 and later

## Requirements

- iOS 13.0 or later
- Xcode 14.0 or later
- Swift 5.0 or later
- Bluetooth Low Energy capable device

## Installation

### Swift Package Manager (Recommended)

1. In Xcode, select **File** → **Add Packages...**
2. Enter the repository URL:
   ```
   https://github.com/mycompanee/vendingSDK-Ios.git
   ```
3. Select the version you want to use
4. Click **Add Package**

Alternatively, add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mycompanee/vendingSDK-Ios.git", from: "1.1.0")
]
```

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'VendingIosSDK', '~> 1.1.0'
```

Then run:

```bash
pod install
```

### Manual Installation

1. Download the `VendingIosSDK.xcframework` from the [Releases](https://github.com/mycompanee/vendingSDK-Ios/releases) page
2. Drag the framework into your Xcode project
3. In your target's **General** settings, add the framework under **Frameworks, Libraries, and Embedded Content**
4. Ensure **Embed & Sign** is selected

## Setup

### 1. Add Privacy Permissions

Add the following to your app's `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to communicate with vending machines.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth access to communicate with vending machines.</string>
```

### 2. Import the Framework

**Swift:**
```swift
import VendingIosSDK
```

**Objective-C:**
```objc
#import <VendingIosSDK/VendingIosSDK.h>
```

## Quick Start

### Swift - Delegate Pattern

```swift
import VendingIosSDK

class ViewController: UIViewController, VendingSDKDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set delegate
        VendingSDK.shared.delegate = self
        
        // Start vending session
        VendingSDK.shared.startVending(
            authKey: "your-auth-key",
            apiKey: "your-api-key",
            vendingMachineNumber: 123
        )
    }
    
    // MARK: - VendingSDKDelegate
    
    func vendingSDK(_ sdk: VendingSDK, didUpdateStatus status: String) {
        print("Status: \(status)")
        // Update UI with status
    }
    
    func vendingSDK(_ sdk: VendingSDK, didCompleteTransaction result: VendingTransactionResult) {
        print("Transaction completed!")
        print("Selection: \(result.selection)")
        print("Amount: \(result.amount)")
        // Handle successful transaction
    }
}
```

### Swift - Closure Pattern

```swift
import VendingIosSDK

VendingSDK.shared.startVending(
    authKey: "your-auth-key",
    apiKey: "your-api-key",
    vendingMachineNumber: 123,
    connectionTimeout: 30.0,
    statusCallback: { status in
        print("Status: \(status)")
    },
    transactionCallback: { result in
        print("Transaction completed: \(result)")
    }
)
```

### Objective-C

```objc
#import <VendingIosSDK/VendingIosSDK.h>

@interface ViewController () <VendingSDKDelegate>
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    VendingSDK.shared.delegate = self;
    
    [VendingSDK.shared startVendingWithAuthKey:@"your-auth-key"
                                         apiKey:@"your-api-key"
                           vendingMachineNumber:123
                              connectionTimeout:30.0];
}

- (void)vendingSDK:(VendingSDK *)sdk didUpdateStatus:(NSString *)status {
    NSLog(@"Status: %@", status);
}

- (void)vendingSDK:(VendingSDK *)sdk didCompleteTransaction:(VendingTransactionResult *)result {
    NSLog(@"Transaction completed!");
}

@end
```

## API Reference

### VendingSDK

Main entry point for the SDK.

#### Properties

- `static let shared: VendingSDK` - Shared singleton instance
- `weak var delegate: VendingSDKDelegate?` - Delegate for receiving callbacks

#### Methods

##### `startVending(authKey:apiKey:vendingMachineNumber:connectionTimeout:)`

Starts a vending session with the specified machine.

**Parameters:**
- `authKey: String` - Authentication key for backend services
- `apiKey: String` - API key for third-party API access
- `vendingMachineNumber: Int32` - Machine number to connect to
- `connectionTimeout: TimeInterval` - BLE connection timeout in seconds (default: 30.0)
- `costCenterId: Int64?` - Optional cost center ID to charge the transaction to (default: `nil` = charge the user's purse). See [Cost Centers](#cost-centers).

**Delegate Callbacks:**
- `vendingSDK(_:didUpdateStatus:)` - Called with status updates
- `vendingSDK(_:didCompleteTransaction:)` - Called when transaction completes

##### `abortVending()`

Aborts the current vending session and disconnects from the BLE device.

##### `static getSDKVersion() -> String`

Returns the current SDK version string.

##### `getAvailableCostCenters(authKey:apiKey:completion:)`

Returns the cost centers available to the current purse (empty if none). Call this before `startVending` if your users may have RFID cards with linked cost centers. See [Cost Centers](#cost-centers).

### Cost Centers

If an RFID card linked to the user's purse has a cost center assigned, transactions can be charged to that cost center instead of the user's purse. The flow:

1. Call `getAvailableCostCenters(authKey:apiKey:)` before starting a session
2. If cost centers are returned, let the user choose one (or offer to use the purse instead)
3. Pass the selected `costCenter.id` to `startVending(..., costCenterId:)`

When a cost center is used, the SDK sends a fixed dummy balance to the vending machine via BLE so the sale is released; the actual charge is booked server-side on the cost center. The transaction result contains the booked cost center via `result.costCenterIdentifier` / `result.costCenterName`.

```swift
VendingSDK.shared.getAvailableCostCenters(authKey: authKey, apiKey: apiKey) { result in
    switch result {
    case .success(let costCenters):
        if costCenters.isEmpty {
            // No cost centers - start normally with the purse
            VendingSDK.shared.startVending(authKey: authKey, apiKey: apiKey,
                                          vendingMachineNumber: 123, costCenterId: nil, /* ... */)
        } else {
            // Let the user pick a cost center, then:
            // VendingSDK.shared.startVending(..., costCenterId: costCenters[0].id, ...)
        }
    case .failure(let error):
        print("Failed to load cost centers: \(error.localizedDescription)")
    }
}
```

### Training Mode

The training mode is a maintenance mode for service technicians: no real transactions are booked. Instead, every product dispensed at the machine is reported to the app, which can then assign an article to the selected slot (selection).

**Trigger:** The mode is enabled when the purse is named `TRAININGMODE`. The SDK exposes this check; the host app asks the user how to proceed:

```swift
VendingSDK.shared.getPurseInfo(authKey: authKey, apiKey: apiKey) { result in
    if case .success(let purse) = result, VendingSDK.isTrainingPurse(purse) {
        // Ask the user: "Im Trainingsmodus starten?" (training) or normal vending
    }
}
```

**Start with the `trainingMode` parameter (Swift closure API only):**

```swift
VendingSDK.shared.startVending(
    authKey: authKey, apiKey: apiKey,
    vendingMachineNumber: 123,
    trainingMode: true,
    statusCallback: { status in print(status) },
    transactionCallback: { _ in },                 // not called in training mode
    trainingProductCallback: { product in
        // product.selection, product.amount (cents), product.fingerprint, product.isLoading
        // Show your article assignment UI here
    }
)
```

**Behavior in training mode:**
- A fixed dummy balance of 9999 cents is sent to the machine (takes precedence over cost centers)
- Sales are acknowledged differently (0x0c), no local balance is deducted
- The idle timeout is disabled — the connection stays open for unlimited consecutive assignments
- After each dispense the app data is re-armed after 2 seconds, so the next dispense works without reconnecting
- No `SendVendingTransaction` is sent; journal entries (START/PRODUCT_SELECT/FINISH) are written via `POST /crud/JournalEntries` instead, also on `abortVending()` or connection loss

**Article assignment APIs:**

```swift
// Create a new article (duplicate PLUs are rejected, journal ARTICLE_CREATE)
VendingSDK.shared.createVendingArticle(authKey: authKey, apiKey: apiKey, plu: "123", name: "Coffee") { result in }

// Assign an article to a machine selection (POST or PUT mapping, journal ASSIGN/OVERWRITE)
// Returns the refreshed vending base data
VendingSDK.shared.assignVendingArticle(authKey: authKey, apiKey: apiKey, machineNumber: 123,
                                       selection: 5, newArticle: article) { result in }

// Reload machines/articles/mappings after changes
VendingSDK.shared.reloadVendingBaseData(authKey: authKey, apiKey: apiKey) { result in }
```

See the sample app's `TrainingArticleViewController` for a complete assignment UI (filter, article creation via `[PLU]:[Name]`, assignment confirmation).

### VendingSDKDelegate

Protocol for receiving SDK callbacks.

#### Methods

- `vendingSDK(_:didUpdateStatus:)` - Status update callback
- `vendingSDK(_:didCompleteTransaction:)` - Transaction completion callback

### VendingTransactionResult

Result object containing transaction information.

**Properties:**
- `selection: Int32` - Selected item number
- `amount: Int32` - Transaction amount
- `fingerprint: UInt32` - Transaction fingerprint
- `article: VendingArticleObjC?` - Article information (Objective-C compatible)
- `transactionResponse: VendingSendTransactionResponseObjC?` - Backend response (Objective-C compatible)
- `terminalName: String?` - Terminal name from transaction (convenience property)
- `storeName: String?` - Store name from transaction (convenience property)
- `transactionUUID: String?` - Transaction UUID from transaction (convenience property)
- `costCenter: CostCenterObjC?` - Booked cost center, if the transaction was charged to one (convenience property)
- `costCenterIdentifier: String?` - Cost center identifier (convenience property)
- `costCenterName: String?` - Cost center name (convenience property)

## Status Messages

The SDK provides status updates through the delegate or callback. Common status messages include:

- `"SDK Version: 1.0.2"` - SDK initialization
- `"Authenticating..."` - Authentication in progress
- `"Loading vending data..."` - Loading machine and article data
- `"Connecting..."` - BLE connection in progress
- `"Connected"` - Successfully connected to vending machine
- `"Sending saldo..."` - Sending balance information
- `"Transaction completed successfully"` - Transaction finished

## Error Handling

The SDK handles errors internally and reports them through status messages. Common error scenarios:

- **Authentication failures**: Check your `authKey` and network connectivity
- **Machine not found**: Verify the `vendingMachineNumber` exists in your account
- **BLE connection timeout**: Ensure the device is powered on and in range
- **Transaction failures**: Check purse balance and machine status

## Aborting a Session

To cancel an ongoing vending session:

```swift
VendingSDK.shared.abortVending()
```

This will:
- Disconnect from the BLE device
- Clear all callbacks
- Clean up resources

## Thread Safety

The SDK is thread-safe and can be called from any thread. All delegate callbacks are delivered on the main thread.

## Example Project

See the `VendingIosSDKSampleApp` directory for a complete example implementation.

## Troubleshooting

### Bluetooth Not Working

1. Ensure Bluetooth is enabled on the device
2. Check that your app has Bluetooth permissions in Info.plist
3. Verify the vending machine is powered on and in range
4. Check that the machine's BLE identifier matches your configuration

### Connection Timeout

1. Increase the `connectionTimeout` parameter
2. Ensure the device is close to the vending machine
3. Check for interference from other Bluetooth devices
4. Verify the machine's BLE identifier is correct

### Authentication Errors

1. Verify your `authKey` is valid and not expired
2. Check network connectivity
3. Ensure your API endpoints are accessible
4. Review backend logs for authentication failures

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, please contact:
- Email: support@mycompanee.de
- Issues: [GitHub Issues](https://github.com/mycompanee/vendingSDK-Ios/issues)

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

---

Made with ❤️ by myCompanee GmbH

