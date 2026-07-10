#import "LCPreferences.h"

NSString * const LCPrefsIdentifier = @"com.fabiswdevbeg.legacycam";
NSString * const LCPrefsCameraEnabledKey = @"CameraEnabled";
NSString * const LCPrefsChangedNotification = @"com.fabiswdevbeg.legacycam/preferenceschanged";

@implementation LCPreferences

+ (BOOL)isCameraEnabled {
    NSString *path = [NSString stringWithFormat:
        @"/var/mobile/Library/Preferences/%@.plist",
        LCPrefsIdentifier];
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:path];
    id value = prefs[LCPrefsCameraEnabledKey];

    if (!value) {
        return YES;
    }

    return [value boolValue];
}

@end
