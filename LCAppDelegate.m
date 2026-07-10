#import "LCAppDelegate.h"
#import "LCRootViewController.h"

@implementation LCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    LCRootViewController *root = [[LCRootViewController alloc] initWithStyle:UITableViewStyleGrouped];
    self.rootViewController = [[UINavigationController alloc] initWithRootViewController:root];
    self.window.rootViewController = self.rootViewController;
    [self.window makeKeyAndVisible];

    return YES;
}

@end
