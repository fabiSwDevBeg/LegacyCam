#import "FlashManager.h"
#import "LCCaptureDevice.h"
#import <AVFoundation/AVFoundation.h>

@implementation FlashManager

static BOOL flashEnabled = NO;
static NSString *flashError = nil;

+ (void)setFlash:(BOOL)on {

    AVCaptureDevice *device = [LCCaptureDevice backVideoDevice];

    if (!device) {
        flashError = @"camera_device_unavailable";
        NSLog(@"[LegacyCam] flash error: no camera device");
        return;
    }

    if (![device hasTorch]) {
        flashError = @"torch_unavailable";
        NSLog(@"[LegacyCam] flash error: selected device has no torch (%@)", device.localizedName);
        return;
    }

    if (![device isTorchAvailable]) {
        flashError = @"torch_not_available_now";
        NSLog(@"[LegacyCam] flash error: torch not available now (%@)", device.localizedName);
        return;
    }

    NSError *error = nil;

    if (![device lockForConfiguration:&error]) {
        flashError = [NSString stringWithFormat:@"torch_lock_error:%@", error.localizedDescription ?: @"unknown"];
        NSLog(@"[LegacyCam] flash lock error: %@", error);
        return;
    }

    if (on) {
        [device setTorchMode:AVCaptureTorchModeOn];
    } else {
        [device setTorchMode:AVCaptureTorchModeOff];
    }

    flashEnabled = on;
    flashError = nil;

    [device unlockForConfiguration];
}

+ (BOOL)isFlashEnabled {
    return flashEnabled;
}

+ (BOOL)isTorchAvailable {
    AVCaptureDevice *device = [LCCaptureDevice backVideoDevice];
    return device && [device hasTorch] && [device isTorchAvailable];
}

+ (NSString *)lastError {
    return flashError;
}

@end
