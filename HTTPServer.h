#import <Foundation/Foundation.h>
#import "LCCameraManager.h"

@class LCStatusManager;

@interface HTTPServer : NSObject

@property (nonatomic, weak) LCCameraManager *camera;
@property (nonatomic, strong) LCStatusManager *statusManager;

- (void)start;

@end
