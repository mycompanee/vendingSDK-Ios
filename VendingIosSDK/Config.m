//
//  Config.m
//  VendingIosSDK
//
//  Created on $(DATE).
//

#import "Config.h"

@implementation Config

+ (BOOL)enableSslPinning {
    return NO;
}

+ (NSString *)userServiceBaseUrl {
    return @"https://user.mycompanee.de";
}

+ (NSString *)notificationServiceUrl {
    return @"https://gw2.mycompanee.de/ws/notification";
}

+ (NSString *)clientServiceBaseUrl {
    return @"https://gw2.mycompanee.de/api/client";
}

+ (NSString *)paymentServiceApiUrl {
    return @"https://gw2.mycompanee.de/api/payment";
}

+ (NSString *)paymentServiceBaseUrl {
    return @"https://gw2.mycompanee.de/payment";
}

+ (NSString *)notificationRazorPagesServiceUrl {
    return @"https://gw2.mycompanee.de/notification/razorpages";
}

+ (NSString *)sdkVersion {
    return @"1.0.2";
}

@end

