#import "LCLog.h"
#import <stdarg.h>

static NSObject *LCLogLock;

void LCLog(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LCLogLock = [[NSObject alloc] init];
    });

    @synchronized(LCLogLock) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:[NSDate date]], message ?: @""];
        NSString *directory = @"/var/mobile/Library/Logs/LegacyCam";
        NSString *path = [directory stringByAppendingPathComponent:@"legacycam-runtime.log"];
        NSString *oldPath = [path stringByAppendingString:@".1"];
        NSFileManager *fileManager = [NSFileManager defaultManager];

        [fileManager createDirectoryAtPath:directory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:NULL];

        NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:NULL];
        if ([attributes[NSFileSize] unsignedLongLongValue] >= 524288) {
            [fileManager removeItemAtPath:oldPath error:NULL];
            [fileManager moveItemAtPath:path toPath:oldPath error:NULL];
        }

        if (![fileManager fileExistsAtPath:path]) {
            [fileManager createFileAtPath:path contents:nil attributes:nil];
        }

        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        if (handle) {
            [handle seekToEndOfFile];
            [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        }

        NSLog(@"[LegacyCam] %@", message ?: @"");
    }
}