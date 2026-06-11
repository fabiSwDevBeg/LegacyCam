#import "LCCameraManager.h"
#import "LCConfigManager.h"
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>

@implementation LCCameraManager {
    AVCaptureSession *session;
    CIContext *context;
    NSTimeInterval lastFrameTime;
}

- (void)start {

    session = [[AVCaptureSession alloc] init];

    // 🔥 IMPORTANTISSIMO: risoluzione bassa
    session.sessionPreset = AVCaptureSessionPreset640x480;

    AVCaptureDevice *device =
        [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    NSError *error = nil;

    AVCaptureDeviceInput *input =
        [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];

    [session addInput:input];

    AVCaptureVideoDataOutput *output =
        [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;

    output.videoSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey :
        @(kCVPixelFormatType_32BGRA)
    };

    dispatch_queue_t q = dispatch_queue_create("camQueue", DISPATCH_QUEUE_SERIAL);
    [output setSampleBufferDelegate:self queue:q];

    [session addOutput:output];

    [session startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    NSTimeInterval frameInterval = [LCConfigManager sharedManager].frameIntervalUsec / 1000000.0;

    if (lastFrameTime > 0 && now - lastFrameTime < frameInterval) {
        return;
    }

    lastFrameTime = now;

    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    // 🔥 LOCK MINIMO
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);

    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);

    void *base = CVPixelBufferGetBaseAddress(pixelBuffer);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef contextRef =
        CGBitmapContextCreate(base,
                              width,
                              height,
                              8,
                              CVPixelBufferGetBytesPerRow(pixelBuffer),
                              colorSpace,
                              kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);

    CGImageRef cgImage = CGBitmapContextCreateImage(contextRef);

    UIImage *img = [UIImage imageWithCGImage:cgImage];
    NSData *jpg = UIImageJPEGRepresentation(img, [LCConfigManager sharedManager].streamQuality);

    CGImageRelease(cgImage);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    if (jpg) {
        self.latestJPEG = jpg;
        self.latestJPEGSequence = self.latestJPEGSequence + 1;
    }
}

@end
