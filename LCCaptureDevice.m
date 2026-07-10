#import "LCCaptureDevice.h"

@implementation LCCaptureDevice

+ (AVCaptureDevice *)backVideoDevice {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
#pragma clang diagnostic pop
    AVCaptureDevice *fallback = nil;

    for (AVCaptureDevice *device in devices) {
        if (!fallback) {
            fallback = device;
        }

        if (device.position == AVCaptureDevicePositionBack) {
            return device;
        }
    }

    return fallback ?: [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

@end
