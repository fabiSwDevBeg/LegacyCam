#import "LCStatusManager.h"
#import "LCConfigManager.h"
#import <libkern/OSAtomic.h>

@implementation LCStatusManager {
    NSDate *_startedAt;
    int32_t _streamClients;
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
    return _streamClients;
}

- (void)incrementStreamClients {
    OSAtomicIncrement32Barrier(&_streamClients);
}

- (void)decrementStreamClients {
    OSAtomicDecrement32Barrier(&_streamClients);
}

- (NSDictionary *)statusDictionaryWithFlashEnabled:(BOOL)flashEnabled {
    LCConfigManager *config = [LCConfigManager sharedManager];

    return @{
        @"online": @YES,
        @"flash": @(flashEnabled),
        @"uptime": @((NSUInteger)self.uptime),
        @"version": config.version,
        @"device": config.deviceName,
        @"stream_clients": @(self.streamClients)
    };
}

@end
