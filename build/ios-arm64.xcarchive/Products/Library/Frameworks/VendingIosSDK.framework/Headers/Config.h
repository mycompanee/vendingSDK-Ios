//
//  Config.h
//  VendingIosSDK
//
//  Created on $(DATE).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Config : NSObject

+ (instancetype)sharedConfig;

// Service Addresses
@property (class, nonatomic, readonly) BOOL enableSslPinning;
@property (class, nonatomic, readonly) NSString *userServiceBaseUrl;
@property (class, nonatomic, readonly) NSString *notificationServiceUrl;
@property (class, nonatomic, readonly) NSString *clientServiceBaseUrl;
@property (class, nonatomic, readonly) NSString *paymentServiceApiUrl;
@property (class, nonatomic, readonly) NSString *paymentServiceBaseUrl;
@property (class, nonatomic, readonly) NSString *notificationRazorPagesServiceUrl;
@property (class, nonatomic, readonly) NSString *sdkVersion;

@end

NS_ASSUME_NONNULL_END

