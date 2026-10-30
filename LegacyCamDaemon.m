#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LegacyCamDaemon.h"
#import "HTTPServer.h"
#import "LCCameraManager.h"
#import "LCStatusManager.h"
#import "LCPowerManager.h"
#import "LCPreferences.h"
#import "LCLog.h"

static BOOL LegacyCamShouldExit = NO;
static LCCameraManager *LegacyCamCamera = nil;
static LCPowerManager *LegacyCamPowerManager = nil;
static NSTimer *LegacyCamCameraRetryTimer = nil;
static id LegacyCamCameraRetryTarget = nil;
static dispatch_queue_t LegacyCamCameraQueue = nil;
static BOOL LegacyCamCameraStartPending = NO;

static void LegacyCamApplyPreferences(void);
static void LegacyCamEnsureCameraRunning(void);

@interface LegacyCamRetryTarget : NSObject
- (void)retryCamera:(NSTimer *)timer;
@end

@implementation LegacyCamRetryTarget

- (void)retryCamera:(NSTimer *)timer {
    LegacyCamEnsureCameraRunning();
}

@end

static void LegacyCamHandleSignal(int signal) {
    LegacyCamShouldExit = YES;
    CFRunLoopStop(CFRunLoopGetMain());
}

static BOOL LegacyCamUsesSpringBoardHost(void) {
    return [[[UIDevice currentDevice] systemVersion] integerValue] >= 9;
}

static void LegacyCamInvalidateCameraRetry(void) {
    if (LegacyCamCameraRetryTimer) {
        [LegacyCamCameraRetryTimer invalidate];
        LegacyCamCameraRetryTimer = nil;
    }
}

static void LegacyCamScheduleCameraRetry(void) {
    if (LegacyCamCameraRetryTimer || LegacyCamShouldExit) {
        return;
    }

    if (!LegacyCamCameraRetryTarget) {
        LegacyCamCameraRetryTarget = [[LegacyCamRetryTarget alloc] init];
    }

    LegacyCamCameraRetryTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                                 target:LegacyCamCameraRetryTarget
                                                               selector:@selector(retryCamera:)
                                                               userInfo:nil
                                                                repeats:YES];

    if ([LegacyCamCameraRetryTimer respondsToSelector:@selector(setTolerance:)]) {
        [LegacyCamCameraRetryTimer performSelector:@selector(setTolerance:) withObject:@1.0];
    }

    LCLog(@"camera retry/frame watchdog scheduled");
}

static void LegacyCamEnsureCameraRunning(void) {
    if (![LCPreferences isCameraEnabled]) {
        LegacyCamInvalidateCameraRetry();
        return;
    }

    if (LegacyCamCamera.producingFrames) {
        return;
    }

    if (LegacyCamCameraStartPending) {
        return;
    }

    LegacyCamCameraStartPending = YES;
    dispatch_async(LegacyCamCameraQueue, ^{
        if (LegacyCamCamera.isRunning) {
            LCLog(@"frame watchdog restarting stale camera session");
            [LegacyCamCamera stop];
        }

        [LegacyCamPowerManager startPreventingIdleSleep];
        [LegacyCamCamera start];
        BOOL cameraRunning = LegacyCamCamera.isRunning;
        NSString *cameraError = [LegacyCamCamera.lastError copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            LegacyCamCameraStartPending = NO;

            if (![LCPreferences isCameraEnabled]) {
                LegacyCamEnsureCameraRunning();
            } else if (cameraRunning) {
                LCLog(@"camera session started; frame watchdog active");
                LegacyCamScheduleCameraRetry();
            } else {
                LCLog(@"camera start pending or failed: %@", cameraError ?: @"unknown");
                LegacyCamScheduleCameraRetry();
            }
        });
    });
}

static void LegacyCamApplyPreferences(void) {
    if ([LCPreferences isCameraEnabled]) {
        LCLog(@"camera enabled in preferences");
        LegacyCamEnsureCameraRunning();
    } else {
        LegacyCamInvalidateCameraRetry();
        dispatch_async(LegacyCamCameraQueue, ^{
            [LegacyCamCamera stop];
            [LegacyCamPowerManager stopPreventingIdleSleep];
        });
        LCLog(@"camera disabled in preferences");
    }
}

static void LegacyCamPreferencesChanged(CFNotificationCenterRef center,
                                        void *observer,
                                        CFStringRef name,
                                        const void *object,
                                        CFDictionaryRef userInfo) {
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{
        LegacyCamApplyPreferences();
    });
    CFRunLoopWakeUp(CFRunLoopGetMain());
}

int LegacyCamDaemonMain(int argc, char *argv[]) {
    @autoreleasepool {
        signal(SIGTERM, LegacyCamHandleSignal);
        signal(SIGINT, LegacyCamHandleSignal);
        signal(SIGPIPE, SIG_IGN);

        if (LegacyCamUsesSpringBoardHost()) {
            LCLog(@"daemon idle: camera and HTTP server are hosted in SpringBoard on this iOS version");

            while (!LegacyCamShouldExit) {
                @autoreleasepool {
                    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:60.0]];
                }
            }

            return 0;
        }

        LCPowerManager *powerManager = [[LCPowerManager alloc] init];
        LegacyCamPowerManager = powerManager;

        LCCameraManager *camera = [[LCCameraManager alloc] init];
        LegacyCamCamera = camera;
        LegacyCamCameraQueue = dispatch_queue_create("com.fabiswdevbeg.legacycam.session", DISPATCH_QUEUE_SERIAL);

        LCStatusManager *statusManager = [[LCStatusManager alloc] init];

        HTTPServer *server = [[HTTPServer alloc] init];
        server.camera = camera;
        server.statusManager = statusManager;
        [server start];

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        LegacyCamPreferencesChanged,
                                        (__bridge CFStringRef)LCPrefsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

                LegacyCamApplyPreferences();

                LCLog(@"daemon ready; HTTP server started before camera initialization");

        while (!LegacyCamShouldExit) {
            @autoreleasepool {
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:60.0]];
            }
        }

        LCLog(@"daemon stopping");
        LegacyCamInvalidateCameraRetry();
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                           NULL,
                                           (__bridge CFStringRef)LCPrefsChangedNotification,
                                           NULL);
        [camera stop];
        [powerManager stopPreventingIdleSleep];
    }

    return 0;
}
