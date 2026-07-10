#import <Foundation/Foundation.h>

@interface FlashManager : NSObject

+ (void)setFlash:(BOOL)on;
+ (BOOL)isFlashEnabled;
+ (BOOL)isTorchAvailable;
+ (NSString *)lastError;

@end
