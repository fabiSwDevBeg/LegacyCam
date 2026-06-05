#import <Foundation/Foundation.h>
#import "LCCameraManager.h"

@interface HTTPServer : NSObject

@property (nonatomic, weak) LCCameraManager *camera;

- (void)start;

@end