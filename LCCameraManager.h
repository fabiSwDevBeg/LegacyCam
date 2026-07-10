#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LCCameraManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (atomic, strong) NSData *latestJPEG;
@property (atomic, assign) NSUInteger latestJPEGSequence;
@property (atomic, readonly, getter=isRunning) BOOL running;
@property (atomic, copy, readonly) NSString *lastError;

- (void)start;
- (void)stop;

@end
