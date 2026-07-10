#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HTTPServer.h"
#import "LCCameraManager.h"
#import "LCPreferences.h"
#import "LCStatusManager.h"
#import "LCPowerManager.h"

static LCCameraManager *LegacyCamSBCamera = nil;
static LCPowerManager *LegacyCamSBPowerManager = nil;
static HTTPServer *LegacyCamSBServer = nil;
static NSTimer *LegacyCamSBRetryTimer = nil;

static BOOL LegacyCamSBIOSUsesSpringBoardHost(void) {
    return [[[UIDevice currentDevice] systemVersion] integerValue] >= 9;
}

static void LegacyCamSBInvalidateRetry(void) {
    if (LegacyCamSBRetryTimer) {
        [LegacyCamSBRetryTimer invalidate];
        LegacyCamSBRetryTimer = nil;
    }
}

static void LegacyCamSBEnsureCameraRunning(void) {
    if (![LCPreferences isCameraEnabled]) {
        LegacyCamSBInvalidateRetry();
        [LegacyCamSBCamera stop];
        [LegacyCamSBPowerManager stopPreventingIdleSleep];
        NSLog(@"[LegacyCam] SpringBoard host camera disabled");
        return;
    }

    if (LegacyCamSBCamera.isRunning) {
        LegacyCamSBInvalidateRetry();
        return;
    }

    [LegacyCamSBPowerManager startPreventingIdleSleep];
    [LegacyCamSBCamera start];

    if (LegacyCamSBCamera.isRunning) {
        LegacyCamSBInvalidateRetry();
        NSLog(@"[LegacyCam] SpringBoard host camera running");
    } else {
        NSLog(@"[LegacyCam] SpringBoard host camera start pending: %@", LegacyCamSBCamera.lastError ?: @"unknown");
    }
}

@interface LegacyCamSBRetryTarget : NSObject
- (void)retryCamera:(NSTimer *)timer;
@end

@implementation LegacyCamSBRetryTarget

- (void)retryCamera:(NSTimer *)timer {
    LegacyCamSBEnsureCameraRunning();
}

@end

static LegacyCamSBRetryTarget *LegacyCamSBRetryTargetInstance = nil;

static void LegacyCamSBScheduleRetry(void) {
    if (LegacyCamSBRetryTimer) {
        return;
    }

    LegacyCamSBRetryTargetInstance = [[LegacyCamSBRetryTarget alloc] init];
    LegacyCamSBRetryTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                             target:LegacyCamSBRetryTargetInstance
                                                           selector:@selector(retryCamera:)
                                                           userInfo:nil
                                                            repeats:YES];

    if ([LegacyCamSBRetryTimer respondsToSelector:@selector(setTolerance:)]) {
        LegacyCamSBRetryTimer.tolerance = 1.0;
    }
}

static void LegacyCamSBApplyPreferences(void) {
    LegacyCamSBEnsureCameraRunning();

    if (![LCPreferences isCameraEnabled]) {
        return;
    }

    if (!LegacyCamSBCamera.isRunning) {
        LegacyCamSBScheduleRetry();
    }
}

static void LegacyCamSBPreferencesChanged(CFNotificationCenterRef center,
                                          void *observer,
                                          CFStringRef name,
                                          const void *object,
                                          CFDictionaryRef userInfo) {
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{
        LegacyCamSBApplyPreferences();
    });
    CFRunLoopWakeUp(CFRunLoopGetMain());
}

static void LegacyCamSBStartHost(void) {
    if (LegacyCamSBServer || !LegacyCamSBIOSUsesSpringBoardHost()) {
        return;
    }

    @try {
        LegacyCamSBPowerManager = [[LCPowerManager alloc] init];
        LegacyCamSBCamera = [[LCCameraManager alloc] init];

        LCStatusManager *statusManager = [[LCStatusManager alloc] init];
        LegacyCamSBServer = [[HTTPServer alloc] init];
        LegacyCamSBServer.camera = LegacyCamSBCamera;
        LegacyCamSBServer.statusManager = statusManager;
        [LegacyCamSBServer start];

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        LegacyCamSBPreferencesChanged,
                                        (__bridge CFStringRef)LCPrefsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        LegacyCamSBApplyPreferences();
        NSLog(@"[LegacyCam] SpringBoard host ready");
    } @catch (NSException *exception) {
        NSLog(@"[LegacyCam] SpringBoard host failed: %@", exception);
    }
}

__attribute__((constructor))
static void LegacyCamSpringBoardHostInit(void) {
    @autoreleasepool {
        if (!LegacyCamSBIOSUsesSpringBoardHost()) {
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            LegacyCamSBStartHost();
        });
    }
}
