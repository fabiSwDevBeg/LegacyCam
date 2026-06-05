#import "FlashManager.h"
#import <AVFoundation/AVFoundation.h>

@implementation FlashManager

+ (void)setFlash:(BOOL)on {

    AVCaptureDevice *device =
        [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    if ([device hasTorch] && [device isTorchAvailable]) {

        [device lockForConfiguration:nil];

        if (on) {
            [device setTorchMode:AVCaptureTorchModeOn];
        } else {
            [device setTorchMode:AVCaptureTorchModeOff];
        }

        [device unlockForConfiguration];
    }
}

@end