#import "FlashManager.h"
#import "LCCaptureDevice.h"
#import "LCLog.h"
#import <AVFoundation/AVFoundation.h>

@implementation FlashManager

static BOOL flashEnabled = NO;
static BOOL torchAvailable = NO;
static NSString *flashError = nil;

+ (void)setFlashError:(NSString *)error {
    @synchronized(self) {
        flashError = [error copy];
    }
}

+ (void)setTorchAvailableValue:(BOOL)available {
    @synchronized(self) {
        torchAvailable = available;
    }
}

+ (void)setFlash:(BOOL)on {

    AVCaptureDevice *device = [LCCaptureDevice backVideoDevice];

    if (!device) {
        [self setTorchAvailableValue:NO];
        [self setFlashError:@"camera_device_unavailable"];
        LCLog(@"flash request failed: no camera device");
        return;
    }

    if (![device hasTorch]) {
        [self setTorchAvailableValue:NO];
        [self setFlashError:@"torch_unavailable"];
        LCLog(@"flash request failed: selected device has no torch (%@)", device.localizedName);
        return;
    }

    [self setTorchAvailableValue:[device isTorchAvailable]];

    if (![device isTorchAvailable]) {
        [self setFlashError:@"torch_not_available_now"];
        LCLog(@"flash request failed: torch not available now (%@)", device.localizedName);
        return;
    }

    NSError *error = nil;

    if (![device lockForConfiguration:&error]) {
        [self setFlashError:[NSString stringWithFormat:@"torch_lock_error:%@", error.localizedDescription ?: @"unknown"]];
        LCLog(@"flash configuration lock failed: %@", error);
        return;
    }

    if (on) {
        [device setTorchMode:AVCaptureTorchModeOn];
    } else {
        [device setTorchMode:AVCaptureTorchModeOff];
    }

    @synchronized(self) {
        flashEnabled = on;
        flashError = nil;
    }

    [device unlockForConfiguration];
    LCLog(@"flash set to %@", on ? @"on" : @"off");
}

+ (BOOL)isFlashEnabled {
    @synchronized(self) {
        return flashEnabled;
    }
}

+ (BOOL)isTorchAvailable {
    @synchronized(self) {
        return torchAvailable;
    }
}

+ (NSString *)lastError {
    @synchronized(self) {
        return flashError;
    }
}

+ (void)refreshTorchAvailability {
    AVCaptureDevice *device = [LCCaptureDevice backVideoDevice];
    [self setTorchAvailableValue:device && [device hasTorch] && [device isTorchAvailable]];
}

@end
