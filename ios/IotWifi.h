#import <CoreLocation/CoreLocation.h>
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/CaptiveNetwork.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import "RNIotWifiSpec.h"

@interface IotWifi : NSObject <NativeIotWifiSpec, CLLocationManagerDelegate>
#else
#import <React/RCTBridgeModule.h>

@interface IotWifi : NSObject <RCTBridgeModule, CLLocationManagerDelegate>
#endif

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) void (^resolve)(__strong id);
@property (nonatomic, strong) void (^reject)(NSString *__strong, NSString *__strong, NSError *__strong);

@end
