#import <Foundation/Foundation.h>

@interface LCStatusManager : NSObject

@property (nonatomic, readonly) NSTimeInterval uptime;
@property (nonatomic, readonly) NSInteger streamClients;

- (void)incrementStreamClients;
- (void)decrementStreamClients;
- (NSDictionary *)statusDictionaryWithFlashEnabled:(BOOL)flashEnabled;

@end
