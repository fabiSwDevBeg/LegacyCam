#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface LCCameraManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) UIImage *latestFrame;

- (void)start;

@end