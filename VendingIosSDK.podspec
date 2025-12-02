Pod::Spec.new do |spec|
  spec.name         = "VendingIosSDK"
  spec.version      = "1.0.0"
  spec.summary      = "iOS SDK for vending machine integration via Bluetooth Low Energy"
  spec.description  = <<-DESC
    VendingIosSDK provides a complete solution for integrating vending machine functionality
    into iOS applications. The SDK handles authentication, BLE communication, transaction processing,
    and provides a simple delegate-based API for vending operations.
  DESC

  spec.homepage     = "https://github.com/mycompanee/vendingSDK-Ios"
  spec.license      = { :type => "Proprietary", :file => "LICENSE" }
  spec.author       = { "myCompanee GmbH" => "support@mycompanee.de" }

  spec.platform     = :ios, "13.0"
  spec.swift_version = "5.0"

  spec.source       = { :git => "https://github.com/mycompanee/vendingSDK-Ios.git", :tag => "#{spec.version}" }

  spec.source_files = "VendingIosSDK/**/*.{h,m,swift}"
  spec.public_header_files = "VendingIosSDK/**/*.h"
  spec.exclude_files = [
    "VendingIosSDK/Info.plist",
    "VendingIosSDK/**/*Tests.swift"
  ]

  spec.frameworks = "Foundation", "CoreBluetooth"
  spec.requires_arc = true

  # Privacy manifest
  spec.resource_bundles = {
    "VendingIosSDK_Privacy" => ["VendingIosSDK/PrivacyInfo.xcprivacy"]
  }
end

