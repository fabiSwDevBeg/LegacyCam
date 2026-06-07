#import "FlashManager.h"
#import <AVFoundation/AVFoundation.h>

@implementation FlashManager

static BOOL flashEnabled = NO;

+ (void)setFlash:(BOOL)on {

    AVCaptureDevice *device =
        [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    if ([device hasTorch] && [device isTorchAvailable]) {

        NSError *error = nil;

        if (![device lockForConfiguration:&error]) {
            return;
        }

        if (on) {
            [device setTorchMode:AVCaptureTorchModeOn];
        } else {
            [device setTorchMode:AVCaptureTorchModeOff];
        }

        flashEnabled = on;

        [device unlockForConfiguration];
    }
}

+ (BOOL)isFlashEnabled {
    return flashEnabled;
}

@end
