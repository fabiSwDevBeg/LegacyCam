#import <Foundation/Foundation.h>

extern NSString * const LCPrefsIdentifier;
extern NSString * const LCPrefsCameraEnabledKey;
extern NSString * const LCPrefsChangedNotification;

@interface LCPreferences : NSObject

+ (BOOL)isCameraEnabled;

@end
