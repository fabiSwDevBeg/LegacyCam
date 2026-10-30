#import "LCCameraManager.h"
#import "LCCaptureDevice.h"
#import "LCConfigManager.h"
#import "LCLog.h"
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#import <objc/message.h>

@interface LCCameraManager ()
@property (atomic, copy, readwrite) NSString *lastError;
@end

@implementation LCCameraManager {
    AVCaptureSession *session;
    AVCaptureDeviceInput *sessionInput;
    AVCaptureVideoDataOutput *sessionOutput;
    dispatch_queue_t sessionOutputQueue;
    CIContext *context;
    NSTimeInterval lastFrameTime;
    NSTimeInterval sessionStartTime;
    NSString *_lastError;
}

- (void)start {
    @synchronized (self) {
        if (session && session.isRunning) {
            return;
        }
    }

    // Check for camera authorization (iOS 7+)
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
        NSInteger (*authorizationStatus)(id, SEL, NSString *) = (void *)objc_msgSend;
        NSInteger status = authorizationStatus([AVCaptureDevice class],
                                               @selector(authorizationStatusForMediaType:),
                                               AVMediaTypeVideo);

        // Check for denied (1) or restricted (2)
        if (status == 1 || status == 2) {
            [self setLastError:@"camera_permission_denied"];
            LCLog(@"camera permission denied or restricted");
            return;
        }

        // Check for not determined (0)
        if (status == 0) {
            [self setLastError:@"camera_permission_not_determined"];
            LCLog(@"requesting camera permission");

            void (*requestAccess)(id, SEL, NSString *, void (^)(BOOL)) = (void *)objc_msgSend;
            requestAccess([AVCaptureDevice class],
                          @selector(requestAccessForMediaType:completionHandler:),
                          AVMediaTypeVideo,
                          ^(BOOL granted) {
                if (granted) {
                    LCLog(@"camera permission granted");
                    [self start];
                } else {
                    [self setLastError:@"camera_permission_denied"];
                    LCLog(@"camera permission denied after request");
                }
            });
            return;
        }
    }
    // iOS 6 doesn't have camera authorization, proceed directly

    [self tearDownSessionKeepingError:NO];

    AVCaptureSession *newSession = [[AVCaptureSession alloc] init];
    [self setLastError:nil];

    if ([newSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        newSession.sessionPreset = AVCaptureSessionPreset640x480;
    } else if ([newSession canSetSessionPreset:AVCaptureSessionPresetLow]) {
        newSession.sessionPreset = AVCaptureSessionPresetLow;
    }

    AVCaptureDevice *device = [LCCaptureDevice backVideoDevice];

    if (!device) {
        [self setLastError:@"camera_device_unavailable"];
        LCLog(@"camera device unavailable");
        return;
    }

    LCLog(@"selected camera device: %@ position=%ld", device.localizedName, (long)device.position);

    NSError *error = nil;

    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];

    if (!input || error) {
        [self setLastError:[NSString stringWithFormat:@"camera_input_error:%@", error.localizedDescription ?: @"unknown"]];
        LCLog(@"camera input error: %@", error);
        return;
    }

    if (![newSession canAddInput:input]) {
        [self setLastError:@"cannot_add_camera_input"];
        LCLog(@"cannot add camera input");
        return;
    }

    [newSession beginConfiguration];
    [newSession addInput:input];

    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;

    output.videoSettings = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey :
        @(kCVPixelFormatType_32BGRA)
    };

    dispatch_queue_t q = dispatch_queue_create("com.fabiswdevbeg.legacycam.camera", DISPATCH_QUEUE_SERIAL);
    [output setSampleBufferDelegate:self queue:q];

    if (![newSession canAddOutput:output]) {
        [newSession commitConfiguration];
        [self setLastError:@"cannot_add_camera_output"];
        LCLog(@"cannot add camera output");
        return;
    }

    [newSession addOutput:output];
    [newSession commitConfiguration];

    @synchronized (self) {
        session = newSession;
        sessionInput = input;
        sessionOutput = output;
        sessionOutputQueue = q;
        lastFrameTime = 0;
        sessionStartTime = CFAbsoluteTimeGetCurrent();
    }

    [self registerForSessionNotifications:newSession];
    [newSession startRunning];

    if (!newSession.isRunning) {
        if (!self.lastError) {
            [self setLastError:@"camera_session_not_running"];
        }
        LCLog(@"camera session did not start running");
    } else {
        LCLog(@"camera session started");
    }
}

- (void)stop {
    [self tearDownSessionKeepingError:NO];

    @synchronized (self) {
        self.latestJPEG = nil;
        self.latestJPEGSequence = self.latestJPEGSequence + 1;
        [self setLastError:nil];
        lastFrameTime = 0;
    }
}

- (void)tearDownSessionKeepingError:(BOOL)keepError {
    AVCaptureSession *sessionToStop = nil;

    @synchronized (self) {
        sessionToStop = session;
        session = nil;
        sessionInput = nil;
        sessionOutput = nil;
        sessionOutputQueue = nil;
        lastFrameTime = 0;
        sessionStartTime = 0;

        if (!keepError) {
            [self setLastError:nil];
        }
    }

    if (sessionToStop) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:sessionToStop];
        [sessionToStop stopRunning];
    }
}

- (BOOL)isRunning {
    @synchronized (self) {
        return session && session.isRunning;
    }
}

- (BOOL)producingFrames {
    @synchronized (self) {
        if (!session || !session.isRunning) {
            return NO;
        }

        NSTimeInterval now = CFAbsoluteTimeGetCurrent();
        if (lastFrameTime > 0) {
            return now - lastFrameTime < 10.0;
        }

        return sessionStartTime > 0 && now - sessionStartTime < 15.0;
    }
}

- (NSString *)lastError {
    @synchronized (self) {
        return _lastError;
    }
}

- (void)setLastError:(NSString *)lastError {
    @synchronized (self) {
        _lastError = [lastError copy];
    }
}

- (void)registerForSessionNotifications:(AVCaptureSession *)captureSession {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center addObserver:self
               selector:@selector(sessionDidStartRunning:)
                   name:AVCaptureSessionDidStartRunningNotification
                 object:captureSession];
    [center addObserver:self
               selector:@selector(sessionDidStopRunning:)
                   name:AVCaptureSessionDidStopRunningNotification
                 object:captureSession];
    [center addObserver:self
               selector:@selector(sessionRuntimeError:)
                   name:AVCaptureSessionRuntimeErrorNotification
                 object:captureSession];
    [center addObserver:self
               selector:@selector(sessionWasInterrupted:)
                   name:AVCaptureSessionWasInterruptedNotification
                 object:captureSession];
    [center addObserver:self
               selector:@selector(sessionInterruptionEnded:)
                   name:AVCaptureSessionInterruptionEndedNotification
                 object:captureSession];
}

- (void)sessionDidStartRunning:(NSNotification *)notification {
    @synchronized (self) {
        if (notification.object == session) {
            [self setLastError:nil];
        }
    }

    LCLog(@"camera session did start running");
}

- (void)sessionDidStopRunning:(NSNotification *)notification {
    @synchronized (self) {
        if (notification.object == session && !_lastError) {
            [self setLastError:@"camera_session_stopped"];
        }
    }

    LCLog(@"camera session did stop running");
}

- (void)sessionRuntimeError:(NSNotification *)notification {
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    NSString *message = nil;

    if (error) {
        message = [NSString stringWithFormat:@"camera_runtime_error:%@:%ld:%@",
                                             error.domain ?: @"unknown",
                                             (long)error.code,
                                             error.localizedDescription ?: @"unknown"];
    } else {
        message = @"camera_runtime_error";
    }

    [self setLastError:message];
    LCLog(@"camera runtime error: %@", error);
}

- (void)sessionWasInterrupted:(NSNotification *)notification {
    NSNumber *reason = notification.userInfo[@"AVCaptureSessionInterruptionReasonKey"];
    NSString *message = @"camera_session_interrupted";

    if (reason) {
        switch (reason.integerValue) {
            case 1:
                message = @"camera_background_forbidden";
                break;
            case 2:
                message = @"camera_audio_in_use_by_other_client";
                break;
            case 3:
                message = @"camera_video_in_use_by_other_client";
                break;
            case 4:
                message = @"camera_unavailable_multiple_foreground_apps";
                break;
            default:
                message = [NSString stringWithFormat:@"camera_session_interrupted:%ld", (long)reason.integerValue];
                break;
        }
    }

    @synchronized (self) {
        if (notification.object == session) {
            [self setLastError:message];
        }
    }

    LCLog(@"camera session was interrupted: %@", notification.userInfo);
}

- (void)sessionInterruptionEnded:(NSNotification *)notification {
    @synchronized (self) {
        if (notification.object == session) {
            [self setLastError:@"camera_session_interruption_ended"];
        }
    }

    LCLog(@"camera session interruption ended");
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    NSTimeInterval frameInterval = [LCConfigManager sharedManager].frameIntervalUsec / 1000000.0;

    @synchronized (self) {
        if (lastFrameTime > 0 && now - lastFrameTime < frameInterval) {
            return;
        }
    }

    lastFrameTime = now;

    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    if (!pixelBuffer || CVPixelBufferLockBaseAddress(pixelBuffer, 0) != kCVReturnSuccess) {
        return;
    }

    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);

    void *base = CVPixelBufferGetBaseAddress(pixelBuffer);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    if (!base || !colorSpace) {
        if (colorSpace) {
            CGColorSpaceRelease(colorSpace);
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return;
    }

    CGContextRef contextRef =
        CGBitmapContextCreate(base,
                              width,
                              height,
                              8,
                              CVPixelBufferGetBytesPerRow(pixelBuffer),
                              colorSpace,
                              kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);

    if (!contextRef) {
        CGColorSpaceRelease(colorSpace);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return;
    }

    CGImageRef cgImage = CGBitmapContextCreateImage(contextRef);

    if (!cgImage) {
        CGContextRelease(contextRef);
        CGColorSpaceRelease(colorSpace);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return;
    }

    UIImage *img = [UIImage imageWithCGImage:cgImage];
    NSData *jpg = UIImageJPEGRepresentation(img, [LCConfigManager sharedManager].streamQuality);

    CGImageRelease(cgImage);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    if (jpg) {
        self.latestJPEG = jpg;
        self.latestJPEGSequence = self.latestJPEGSequence + 1;

        @synchronized (self) {
            lastFrameTime = now;
        }
    }
}

- (void)dealloc {
    [self tearDownSessionKeepingError:YES];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
