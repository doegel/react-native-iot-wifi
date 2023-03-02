
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNIotWifiSpec.h"

@interface IotWifi : NSObject <NativeIotWifiSpec>
#else
#import <React/RCTBridgeModule.h>

@interface IotWifi : NSObject <RCTBridgeModule>
#endif

@end
