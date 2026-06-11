#import <Foundation/Foundation.h>
#import "HTTPServer.h"
#import "LCCameraManager.h"
#import "LCStatusManager.h"
#import "LCPowerManager.h"

static BOOL LegacyCamShouldExit = NO;

static void LegacyCamHandleSignal(int signal) {
    LegacyCamShouldExit = YES;
    CFRunLoopStop(CFRunLoopGetMain());
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        signal(SIGTERM, LegacyCamHandleSignal);
        signal(SIGINT, LegacyCamHandleSignal);
        signal(SIGPIPE, SIG_IGN);

        LCPowerManager *powerManager = [[LCPowerManager alloc] init];
        [powerManager startPreventingIdleSleep];

        LCCameraManager *camera = [[LCCameraManager alloc] init];
        [camera start];

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
        [powerManager stopPreventingIdleSleep];
    }

    return 0;
}
