#import "LCPowerManager.h"
#import <dlfcn.h>

typedef uint32_t LCPMAssertionID;
typedef int32_t LCPMReturn;
typedef LCPMReturn (*LCPMAssertionCreateWithName)(CFStringRef, uint32_t, CFStringRef, LCPMAssertionID *);
typedef LCPMReturn (*LCPMAssertionRelease)(LCPMAssertionID);

static const uint32_t LCPMAssertionLevelOn = 255;
static const LCPMAssertionID LCPMAssertionIDInvalid = 0;

@implementation LCPowerManager {
    void *_ioKit;
    LCPMAssertionCreateWithName _createAssertion;
    LCPMAssertionRelease _releaseAssertion;
    LCPMAssertionID _assertionID;
}

- (void)dealloc {
    [self stopPreventingIdleSleep];

    if (_ioKit) {
        dlclose(_ioKit);
    }
}

- (BOOL)idleSleepPrevented {
    return _assertionID != LCPMAssertionIDInvalid;
}

- (void)startPreventingIdleSleep {
    if (self.idleSleepPrevented) {
        return;
    }

    if (![self loadIOKitSymbols]) {
        NSLog(@"[LegacyCam] power assertion unavailable");
        return;
    }

    LCPMAssertionID assertionID = LCPMAssertionIDInvalid;
    LCPMReturn result = _createAssertion(CFSTR("NoIdleSleepAssertion"),
                                         LCPMAssertionLevelOn,
                                         CFSTR("LegacyCam camera stream"),
                                         &assertionID);

    if (result == 0 && assertionID != LCPMAssertionIDInvalid) {
        _assertionID = assertionID;
        NSLog(@"[LegacyCam] idle sleep prevention enabled");
    } else {
        NSLog(@"[LegacyCam] idle sleep prevention failed: %d", result);
    }
}

- (void)stopPreventingIdleSleep {
    if (!self.idleSleepPrevented || !_releaseAssertion) {
        return;
    }

    _releaseAssertion(_assertionID);
    _assertionID = LCPMAssertionIDInvalid;
    NSLog(@"[LegacyCam] idle sleep prevention disabled");
}

- (BOOL)loadIOKitSymbols {
    if (_createAssertion && _releaseAssertion) {
        return YES;
    }

    if (!_ioKit) {
        _ioKit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    }

    if (!_ioKit) {
        return NO;
    }

    _createAssertion = (LCPMAssertionCreateWithName)dlsym(_ioKit, "IOPMAssertionCreateWithName");
    _releaseAssertion = (LCPMAssertionRelease)dlsym(_ioKit, "IOPMAssertionRelease");

    return _createAssertion && _releaseAssertion;
}

@end
