#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LCCameraManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (atomic, strong) NSData *latestJPEG;
@property (atomic, assign) NSUInteger latestJPEGSequence;

- (void)start;

@end
