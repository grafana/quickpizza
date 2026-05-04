#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(QuickPizzaCrash, NSObject)

RCT_EXTERN_METHOD(crash:(NSString *)variant)

@end
