#ifndef API_AVAILABLE
#define API_AVAILABLE(...)
#endif

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <notify.h>

static NSString * const LCPrefsChangedNotification = @"com.fabiswdevbeg.legacycam/preferenceschanged";

@interface LegacyCamPrefsRootListController : PSListController
@end

@implementation LegacyCamPrefsRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }

    return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];
    notify_post(LCPrefsChangedNotification.UTF8String);
}

@end
