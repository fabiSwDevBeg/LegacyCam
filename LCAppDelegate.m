#import "LCAppDelegate.h"
#import "LCRootViewController.h"
#import "HTTPServer.h"
#import "LCCameraManager.h"

@implementation LCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // CAMERA
    LCCameraManager *cam = [[LCCameraManager alloc] init];
    [cam start];
    self.camera = cam;

    // SERVER
    HTTPServer *server = [[HTTPServer alloc] init];
    server.camera = cam;
    [server start];

    NSLog(@"[LegacyCam] READY");

    return YES;
}

@end