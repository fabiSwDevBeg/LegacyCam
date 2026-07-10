#import "LCStatusManager.h"
#import "LCConfigManager.h"
#import <stdatomic.h>

@implementation LCStatusManager {
    NSDate *_startedAt;
    atomic_int _streamClients;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _startedAt = [NSDate date];
        _streamClients = 0;
    }

    return self;
}

- (NSTimeInterval)uptime {
    return [[NSDate date] timeIntervalSinceDate:_startedAt];
}

- (NSInteger)streamClients {
    return atomic_load(&_streamClients);
}

- (void)incrementStreamClients {
    atomic_fetch_add(&_streamClients, 1);
}

- (void)decrementStreamClients {
    atomic_fetch_sub(&_streamClients, 1);
}

- (NSDictionary *)statusDictionaryWithFlashEnabled:(BOOL)flashEnabled
                                    cameraEnabled:(BOOL)cameraEnabled
                                    cameraRunning:(BOOL)cameraRunning
                                      cameraError:(NSString *)cameraError {
    LCConfigManager *config = [LCConfigManager sharedManager];

    return @{
        @"online": @YES,
        @"flash": @(flashEnabled),
        @"camera_enabled": @(cameraEnabled),
        @"camera_running": @(cameraRunning),
        @"camera_error": cameraError ?: @"",
        @"uptime": @((NSUInteger)self.uptime),
        @"version": config.version,
        @"build": config.build,
        @"device": config.deviceName,
        @"stream_clients": @(self.streamClients)
    };
}

@end
