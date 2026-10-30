#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HTTPServer.h"
#import "LCCameraManager.h"
#import "LCPreferences.h"
#import "LCStatusManager.h"
#import "LCPowerManager.h"
#import "LCLog.h"

static LCCameraManager *LegacyCamSBCamera = nil;
static LCPowerManager *LegacyCamSBPowerManager = nil;
static HTTPServer *LegacyCamSBServer = nil;
static NSTimer *LegacyCamSBRetryTimer = nil;
static dispatch_queue_t LegacyCamSBCameraQueue = nil;
static BOOL LegacyCamSBCameraStartPending = NO;

static void LegacyCamSBScheduleRetry(void);

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
        dispatch_async(LegacyCamSBCameraQueue, ^{
            [LegacyCamSBCamera stop];
            [LegacyCamSBPowerManager stopPreventingIdleSleep];
        });
        LCLog(@"SpringBoard host camera disabled");
        return;
    }

    if (LegacyCamSBCamera.producingFrames) {
        return;
    }

    if (LegacyCamSBCameraStartPending) {
        return;
    }

    LegacyCamSBCameraStartPending = YES;
    dispatch_async(LegacyCamSBCameraQueue, ^{
        if (LegacyCamSBCamera.isRunning) {
            LCLog(@"SpringBoard frame watchdog restarting stale camera session");
            [LegacyCamSBCamera stop];
        }

        [LegacyCamSBPowerManager startPreventingIdleSleep];
        [LegacyCamSBCamera start];

        BOOL cameraRunning = LegacyCamSBCamera.isRunning;
        NSString *cameraError = [LegacyCamSBCamera.lastError copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            LegacyCamSBCameraStartPending = NO;

            if (![LCPreferences isCameraEnabled]) {
                LegacyCamSBEnsureCameraRunning();
            } else if (cameraRunning) {
                LCLog(@"SpringBoard camera session started; frame watchdog active");
                LegacyCamSBScheduleRetry();
            } else {
                LCLog(@"SpringBoard host camera start pending: %@", cameraError ?: @"unknown");
                LegacyCamSBScheduleRetry();
            }
        });
    });
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
        [LegacyCamSBRetryTimer performSelector:@selector(setTolerance:) withObject:@1.0];
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
        LegacyCamSBCameraQueue = dispatch_queue_create("com.fabiswdevbeg.legacycam.session", DISPATCH_QUEUE_SERIAL);

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
        LCLog(@"SpringBoard host ready");
    } @catch (NSException *exception) {
        LCLog(@"SpringBoard host failed: %@", exception);
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
