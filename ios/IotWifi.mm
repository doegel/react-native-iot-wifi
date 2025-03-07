#import "IotWifi.h"

@implementation IotWifi
RCT_EXPORT_MODULE();

RCT_REMAP_METHOD(requestPermission,
                 requestPermissionWithResolver:(RCTPromiseResolveBlock)resolve withRejecter:(RCTPromiseRejectBlock)reject)
{
    if (![CLLocationManager locationServicesEnabled]) {
        resolve(@NO);
    }
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusNotDetermined) {
        [self checkPermissionWithResolver:resolve withRejecter:reject];
    }

    _resolve = resolve;
    _reject = reject;

    _locationManager = [CLLocationManager new];
    [_locationManager setDelegate:self];
    [_locationManager requestWhenInUseAuthorization];
}

RCT_REMAP_METHOD(hasPermission,
                 hasPermissionWithResolver:(RCTPromiseResolveBlock)resolve withRejecter:(RCTPromiseRejectBlock)reject)
{
    [self checkPermissionWithResolver:resolve withRejecter:reject];
}

RCT_REMAP_METHOD(isApiAvailable,
                 isApiAvailableWithResolver:(RCTPromiseResolveBlock)resolve withRejecter:(RCTPromiseRejectBlock)reject)
{
    BOOL available = NO;

    if (@available(iOS 11.0, *)) {
        available = YES;
    }

    resolve(@(available));
}

RCT_REMAP_METHOD(getSSID,
                 getSSIDWithResolver:(RCTPromiseResolveBlock)resolve withRejecter:(RCTPromiseRejectBlock)reject)
{
    [self fetchSSIDWithResolver:resolve withRejecter:reject];
}

RCT_EXPORT_METHOD(connect:(NSString*)ssid
                  withPassphrase:(NSString*)passphrase
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
{
    if (@available(iOS 11.0, *)) {
        NEHotspotConfiguration* configuration = nil;
        if ([passphrase length] == 0) {
            // Connect without passphrase
            configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid];
        } else {
            // Connect with credentials
            configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid passphrase:passphrase isWEP:NO];
        }

        configuration.joinOnce = true; // Will behave more like android if set

        [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                reject(@"not_configured", [error localizedDescription], error);
            } else {
                // Wait for network to join.
                [self waitForNetworkWithSSID:ssid withResolver:resolve withRejecter:reject];
            }
        }];
    } else {
        reject(@"not_supported", @"Not supported in iOS<11.0", nil);
    }
}

RCT_EXPORT_METHOD(disconnect:(NSString*)ssid
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)
{
    if (@available(iOS 11.0, *)) {
        [[NEHotspotConfigurationManager sharedManager] getConfiguredSSIDsWithCompletionHandler:^(NSArray<NSString *> *ssids) {
            if (ssids != nil && [ssids indexOfObject:ssid] != NSNotFound) {
                [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:ssid];
            }
            resolve([NSNull null]);

            // TODO: reject if not found?
        }];
    } else {
        reject(@"not_supported", @"Not supported in iOS<11.0", nil);
    }
}

 /** Method called by the delegate with the result of the permission request. */
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status != kCLAuthorizationStatusNotDetermined) {
        [_locationManager setDelegate:nil];
        [self checkPermissionWithResolver:_resolve withRejecter:_reject];
    }
}

- (void)waitForNetworkWithSSID:(NSString*)ssid
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject {
    __block BOOL joined = NO;
    // Wait until device joined the network.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // non-main thread.
        for (int i = 1; i < 5; i++) { // Wait for 10s
            [NSThread sleepForTimeInterval:2.0f];
            dispatch_async(dispatch_get_main_queue(), ^{
                // main thread
                [self fetchSSIDWithResolver:^(id result) {
                    if ([result isEqualToString:ssid]) {
                        // We joined successfully.
                        joined = YES;
                    }
                } withRejecter:^(NSString *code, NSString *message, NSError *error) {
                    // We could not determine SSID.
                    joined = NO;
                }];
            });
            if (joined) {
                // Break the loop if we are joined.
                break;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            // main thread
            if (joined) {
                resolve([NSNull null]);
            } else {
                reject(@"not_joined", @"Cannot join the configured network", nil);
            }
        });
    });
}

- (void)fetchSSIDWithResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject {
  if (@available(iOS 14.0, *)) {
        [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable currentNetwork) {
            if (currentNetwork == nil) {
                reject(@"not_available", @"Cannot detect SSID, do you have location permission?", nil);
            } else {
                NSString *ssid = [currentNetwork SSID];
                resolve(ssid);
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
                resolve(ssid);
            } else {
                reject(@"not_available", @"Cannot detect SSID, do you have location permission?", nil);
            }
        }
    }
}

- (void)checkPermissionWithResolver:(RCTPromiseResolveBlock)resolve
                       withRejecter:(RCTPromiseRejectBlock)reject {
    if (![CLLocationManager locationServicesEnabled]) {
        // Location disabled
        resolve(@NO);
    }
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusAuthorizedAlways ||
        status == kCLAuthorizationStatusAuthorizedWhenInUse)
    {
        resolve(@YES);
    } else {
        resolve(@NO);
    }
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
