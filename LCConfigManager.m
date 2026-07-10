#import "LCConfigManager.h"
#import <sys/sysctl.h>

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
        _deviceName = [self detectedDeviceName];
        _version = @"1.0.0";
        _build = @"ios7-4clients-20260619";

        if ([_deviceName hasPrefix:@"iPhone3,"]) {
            _maxStreamClients = 4;
            _streamQuality = 0.16;
            _frameIntervalUsec = 200000;
        } else {
            _maxStreamClients = 3;
            _streamQuality = 0.22;
            _frameIntervalUsec = 66667;
        }
    }

    return self;
}

- (NSString *)detectedDeviceName {
    size_t size = 0;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);

    if (size == 0) {
        return @"unknown";
    }

    char *machine = malloc(size);
    if (!machine) {
        return @"unknown";
    }

    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *device = [NSString stringWithUTF8String:machine] ?: @"unknown";
    free(machine);

    return device;
}

@end
