#import <Foundation/Foundation.h>

@interface LCPowerManager : NSObject

@property (nonatomic, readonly) BOOL idleSleepPrevented;

- (void)startPreventingIdleSleep;
- (void)stopPreventingIdleSleep;

@end
