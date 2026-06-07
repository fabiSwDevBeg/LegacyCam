#import "LCConfigManager.h"

@implementation LCConfigManager

+ (instancetype)sharedManager {
    static LCConfigManager *manager = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        manager = [[LCConfigManager alloc] init];
    });

    return manager;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _port = 8080;
        _streamQuality = 0.3;
        _snapshotQuality = 0.4;
        _frameIntervalUsec = 180000;
        _version = @"1.0.0";
        _deviceName = @"iPhone4";
    }

    return self;
}

@end
