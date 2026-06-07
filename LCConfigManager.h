#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <unistd.h>

@interface LCConfigManager : NSObject

@property (nonatomic, readonly) NSUInteger port;
@property (nonatomic, readonly) CGFloat streamQuality;
@property (nonatomic, readonly) CGFloat snapshotQuality;
@property (nonatomic, readonly) useconds_t frameIntervalUsec;
@property (nonatomic, readonly) NSString *version;
@property (nonatomic, readonly) NSString *deviceName;

+ (instancetype)sharedManager;

@end
