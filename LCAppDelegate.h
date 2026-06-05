#import <UIKit/UIKit.h>

@class LCCameraManager;

@interface LCAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UINavigationController *rootViewController;
@property (nonatomic, strong) LCCameraManager *camera;

@end