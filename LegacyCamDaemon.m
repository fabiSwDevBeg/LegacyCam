#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LegacyCamDaemon.h"
#import "HTTPServer.h"
#import "LCCameraManager.h"
#import "LCStatusManager.h"
#import "LCPowerManager.h"
#import "LCPreferences.h"

static BOOL LegacyCamShouldExit = NO;
static LCCameraManager *LegacyCamCamera = nil;
static LCPowerManager *LegacyCamPowerManager = nil;
static NSTimer *LegacyCamCameraRetryTimer = nil;
static id LegacyCamCameraRetryTarget = nil;

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
        LegacyCamCameraRetryTimer.tolerance = 1.0;
    }

    NSLog(@"[LegacyCam] camera retry scheduled");
}

static void LegacyCamEnsureCameraRunning(void) {
    if (![LCPreferences isCameraEnabled]) {
        LegacyCamInvalidateCameraRetry();
        return;
    }

    if (LegacyCamCamera.isRunning) {
        LegacyCamInvalidateCameraRetry();
        return;
    }

    [LegacyCamPowerManager startPreventingIdleSleep];
    [LegacyCamCamera start];

    if (LegacyCamCamera.isRunning) {
        LegacyCamInvalidateCameraRetry();
        NSLog(@"[LegacyCam] camera running");
    } else {
        LegacyCamScheduleCameraRetry();
        NSLog(@"[LegacyCam] camera start pending: %@", LegacyCamCamera.lastError ?: @"unknown");
    }
}

static void LegacyCamApplyPreferences(void) {
    if ([LCPreferences isCameraEnabled]) {
        NSLog(@"[LegacyCam] camera enabled");
        LegacyCamEnsureCameraRunning();
    } else {
        LegacyCamInvalidateCameraRetry();
        [LegacyCamCamera stop];
        [LegacyCamPowerManager stopPreventingIdleSleep];
        NSLog(@"[LegacyCam] camera disabled");
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
            NSLog(@"[LegacyCam] daemon idle: camera and HTTP server are hosted in SpringBoard on this iOS version");

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
        LegacyCamApplyPreferences();

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        LegacyCamPreferencesChanged,
                                        (__bridge CFStringRef)LCPrefsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        LCStatusManager *statusManager = [[LCStatusManager alloc] init];

        HTTPServer *server = [[HTTPServer alloc] init];
        server.camera = camera;
        server.statusManager = statusManager;
        [server start];

        NSLog(@"[LegacyCam] daemon ready");

        while (!LegacyCamShouldExit) {
            @autoreleasepool {
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:60.0]];
            }
        }

        NSLog(@"[LegacyCam] daemon stopping");
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
