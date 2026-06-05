#import "LCCameraManager.h"
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>

@implementation LCCameraManager {
    AVCaptureSession *session;
    CIContext *context;
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

    CGImageRelease(cgImage);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    self.latestFrame = img;
}

@end