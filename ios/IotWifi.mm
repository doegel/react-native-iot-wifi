#import "IotWifi.h"
#import <CoreLocation/CoreLocation.h>
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/CaptiveNetwork.h>

@implementation IotWifi
RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(requestPermission,
                  requestPermissionWithResolver:(RCTPromiseResolveBlock)resolve withRejecter:(RCTPromiseRejectBlock)reject)
{
    CLLocationManager *locationManager = [[CLLocationManager alloc] init];
    [locationManager requestWhenInUseAuthorization];

    // TODO: return state from aquired from delegate
    resolve(@[[NSNull null]]);
}

RCT_REMAP_METHOD(hasPermission,
                 hasPermissionWithResolver:(RCTPromiseResolveBlock)resolve withRejecter:(RCTPromiseRejectBlock)reject)
{
    if (@available(iOS 14.0, *)) {
      CLLocationManager *locationManager = [[CLLocationManager alloc] init];
      CLAuthorizationStatus status = [locationManager authorizationStatus];
      if (status == kCLAuthorizationStatusAuthorizedAlways ||
          status == kCLAuthorizationStatusAuthorizedWhenInUse)
      {
        resolve(@(YES));
      } else {
        resolve(@(NO));
      }
    } else {
      reject(@"not_supported", @"Not supported in iOS<14.0", nil);
    }
}

RCT_REMAP_METHOD(isApiAvailable,
                 isApiAvailableWithResolver:(RCTPromiseResolveBlock)resolve withRejecter:(RCTPromiseRejectBlock)reject)
{
    BOOL available = NO;

#if !TARGET_OS_SIMULATOR
    if (@available(iOS 11.0, *)) {
        available = YES;
    }
#endif

    resolve(@(available));
}

RCT_REMAP_METHOD(getSSID,
                 getSSIDWithResolver:(RCTPromiseResolveBlock)resolve withRejecter:(RCTPromiseRejectBlock)reject)
{
#if TARGET_OS_SIMULATOR
    reject(@"not_available", @"Cannot run on a simulator", nil);
#else
    if (@available(iOS 14.0, *)) {
        [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable currentNetwork) {
            if (currentNetwork == nil) {
                reject(@"not_available", @"Cannot detect SSID, do you have location permission?", nil);
            } else {
                NSString *ssid = [currentNetwork SSID];
                resolve(@[ssid]);
            }
        }];
    } else {
        NSString *kSSID = (NSString*) kCNNetworkInfoKeySSID;

        NSArray *ifs = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
        NSDictionary *info;
        for (NSString *ifnam in ifs) {
            info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
            if (info && [info count]) {
                NSString *ssid = [info objectForKey: kSSID];
                resolve(@[ssid]);
            } else {
                reject(@"not_available", @"Cannot detect SSID, do you have location permission?", nil);
            }
        }
    }
#endif
}

RCT_EXPORT_METHOD(connect:(NSString*)ssid
                  withPassphrase:(NSString*)passphrase
                  rememberNetwork:(BOOL)rememberNetwork
                  isWEP:(BOOL)isWEP
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
{
#if TARGET_OS_SIMULATOR
    reject(@"not_available", @"Cannot run on a simulator", nil);
#else
    if (@available(iOS 11.0, *)) {
        NEHotspotConfiguration* configuration = nil;
        if ([passphrase length] == 0) {
            // Connect without passphrase
            configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid];
        } else {
            // Connect with credentials
            configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid passphrase:passphrase isWEP:isWEP];
        }

        configuration.joinOnce = !rememberNetwork;

        [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                reject(@"not_configured", [error localizedDescription], error);
            } else {
                resolve(@[[NSNull null]]);
            }
        }];
    } else {
        reject(@"not_supported", @"Not supported in iOS<11.0", nil);
    }
#endif
}

RCT_EXPORT_METHOD(disconnect:(NSString*)ssid
                  forgetNetwork:(BOOL)forgetNetwork //Ignored
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
{
#if TARGET_OS_SIMULATOR
    reject(@"not_available", @"Cannot run on a simulator", nil);
#else
    if (@available(iOS 11.0, *)) {
        [[NEHotspotConfigurationManager sharedManager] getConfiguredSSIDsWithCompletionHandler:^(NSArray<NSString *> *ssids) {
            if (ssids != nil && [ssids indexOfObject:ssid] != NSNotFound) {
                [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:ssid];
            }
            resolve(@[[NSNull null]]);

            // TODO: reject if not found?
        }];
    } else {
        reject(@"not_supported", @"Not supported in iOS<11.0", nil);
    }
#endif
}

// Don't compile this code when we build for the old architecture.
#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeIotWifiSpecJSI>(params);
}
#endif

@end
