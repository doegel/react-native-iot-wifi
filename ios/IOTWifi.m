#import "IOTWifi.h"
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/CaptiveNetwork.h>


@implementation IOTWifi
    RCT_EXPORT_MODULE();
    RCT_EXPORT_METHOD(isApiAvailable:(RCTResponseSenderBlock)callback) {
        NSNumber *available = @NO;
        if (@available(iOS 11.0, *)) {
            available = @YES;
        }
        callback(@[available]);
    }
    
    RCT_EXPORT_METHOD(connect:(NSString*)ssid
                      bindNetwork:(BOOL)bindNetwork //Ignored
                      callback:(RCTResponseSenderBlock)callback) {
        if (@available(iOS 11.0, *)) {
            NEHotspotConfiguration* configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid];
            configuration.joinOnce = !bindNetwork;
            
            [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError * _Nullable error) {
                if (error != nil) {
                    callback(@[@"Error while configuring WiFi"]);
                } else {
                    callback(@[[NSNull null]]);
                }
            }];
            
        } else {
            callback(@[@"Not supported in iOS<11.0"]);
        }
    }
        
    RCT_EXPORT_METHOD(connectSecure:(NSString*)ssid
                      withPassphrase:(NSString*)passphrase
                      isWEP:(BOOL)isWEP
                      bindNetwork:(BOOL)bindNetwork
                      callback:(RCTResponseSenderBlock)callback) {
        
        if (@available(iOS 11.0, *)) {
            NEHotspotConfiguration* configuration = [[NEHotspotConfiguration alloc] initWithSSID:ssid passphrase:passphrase isWEP:isWEP];
            configuration.joinOnce = !bindNetwork;
            
            [[NEHotspotConfigurationManager sharedManager] applyConfiguration:configuration completionHandler:^(NSError * _Nullable error) {
                if (error != nil) {
                    callback(@[[error localizedDescription]]);
                } else {
                    callback(@[[NSNull null]]);
                }
            }];
            
        } else {
            callback(@[@"Not supported in iOS<11.0"]);
        }
    }
    
    RCT_EXPORT_METHOD(removeSSID:(NSString*)ssid
                      unbindNetwork:(BOOL)unbindNetwork //Ignored
                      callback:(RCTResponseSenderBlock)callback) {
        
        if (@available(iOS 11.0, *)) {
            [[NEHotspotConfigurationManager sharedManager] getConfiguredSSIDsWithCompletionHandler:^(NSArray<NSString *> *ssids) {
                if (ssids != nil && [ssids indexOfObject:ssid] != NSNotFound) {
                    [[NEHotspotConfigurationManager sharedManager] removeConfigurationForSSID:ssid];
                }
                callback(@[[NSNull null]]);
            }];
        } else {
            callback(@[@"Not supported in iOS<11.0"]);
        }
        
    }
    
    RCT_REMAP_METHOD(getSSID,
                     callback:(RCTResponseSenderBlock)callback) {
        NSString *kSSID = (NSString*) kCNNetworkInfoKeySSID;

        if (@available(iOS 14.0, *)) {
            [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable currentNetwork) {
                NSString *ssid = [currentNetwork SSID];
                callback(@[ssid]);
            }];
        } else {
            NSArray *ifs = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
            NSDictionary *info;
            for (NSString *ifnam in ifs) {
                info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
                if (info && [info count]) {
                    NSString *ssid = [info objectForKey: kSSID];
                    callback(@[ssid]);
                    return;
                }
            }
        }

        callback(@[@"Cannot detect SSID"]);
    }
@end

