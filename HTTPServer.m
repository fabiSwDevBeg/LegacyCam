#import "HTTPServer.h"
#import "FlashManager.h"
#import "LCConfigManager.h"
#import "LCRoutes.h"
#import "LCStatusManager.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <unistd.h>

@implementation HTTPServer {
    int server_fd;
}

- (void)start {
    signal(SIGPIPE, SIG_IGN);

    if (!self.statusManager) {
        self.statusManager = [[LCStatusManager alloc] init];
    }
    
    server_fd = socket(AF_INET, SOCK_STREAM, 0);

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons([LCConfigManager sharedManager].port);
    addr.sin_addr.s_addr = INADDR_ANY;

    bind(server_fd, (struct sockaddr *)&addr, sizeof(addr));
    listen(server_fd, 5);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self loop];
    });
}

- (void)loop {

    while (1) {

        int client = accept(server_fd, NULL, NULL);
        if (client < 0) continue;

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self handleRequest:client];
        });
    }
}

- (void)handleRequest:(int)client {
    @autoreleasepool {
        char buffer[1024] = {0};
        int len = read(client, buffer, sizeof(buffer)-1);

        if (len <= 0) {
            close(client);
            return;
        }

        NSString *request = [[NSString alloc] initWithBytes:buffer
                                                      length:len
                                                    encoding:NSUTF8StringEncoding];
        NSString *path = [self pathForRequest:request];

        if ([path isEqualToString:LCRoutePing]) {
            [self sendJSON:@{@"ok": @YES} client:client];
            return;
        }

        if ([path isEqualToString:LCRouteStatus]) {
            [self sendJSON:[self.statusManager statusDictionaryWithFlashEnabled:[FlashManager isFlashEnabled]]
                    client:client];
            return;
        }

        if ([path isEqualToString:LCRouteFlashStatus]) {
            [self sendJSON:@{@"enabled": @([FlashManager isFlashEnabled])} client:client];
            return;
        }

        if ([path isEqualToString:LCRouteFlashOn]) {
            [FlashManager setFlash:YES];
            [self sendJSON:@{@"enabled": @([FlashManager isFlashEnabled])} client:client];
            return;
        }

        if ([path isEqualToString:LCRouteFlashOff]) {
            [FlashManager setFlash:NO];
            [self sendJSON:@{@"enabled": @([FlashManager isFlashEnabled])} client:client];
            return;
        }

        if ([path isEqualToString:LCRouteStream]) {
            [self sendMJPEG:client];
            return;
        }

        [self sendDiagnostics:client];
    }
}

- (NSString *)pathForRequest:(NSString *)request {
    NSArray *lines = [request componentsSeparatedByString:@"\r\n"];
    NSString *requestLine = lines.count > 0 ? lines[0] : @"";
    NSArray *parts = [requestLine componentsSeparatedByString:@" "];

    if (parts.count < 2) {
        return @"/";
    }

    return parts[1];
}

- (void)sendMJPEG:(int)client {
    int noDelay = 1;
    setsockopt(client, IPPROTO_TCP, TCP_NODELAY, &noDelay, sizeof(noDelay));

    NSString *header =
    @"HTTP/1.1 200 OK\r\n"
    "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n";

    if (![self writeString:header client:client]) {
        close(client);
        return;
    }

    [self.statusManager incrementStreamClients];
    NSUInteger lastSequence = 0;

    while (1) {
        @autoreleasepool {
            NSData *jpg = self.camera.latestJPEG;
            NSUInteger sequence = self.camera.latestJPEGSequence;

            if (!jpg || sequence == lastSequence) {
                usleep(10000);
                continue;
            }

            NSString *meta = [NSString stringWithFormat:
                @"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %lu\r\n\r\n",
                (unsigned long)jpg.length];

            if (![self writeString:meta client:client] ||
                ![self writeData:jpg client:client] ||
                ![self writeString:@"\r\n" client:client]) {
                close(client);
                [self.statusManager decrementStreamClients];
                break;
            }

            lastSequence = sequence;
        }
    }
}

- (BOOL)writeString:(NSString *)string client:(int)client {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self writeData:data client:client];
}

- (BOOL)writeData:(NSData *)data client:(int)client {
    return [self writeBytes:data.bytes length:data.length client:client];
}

- (BOOL)writeBytes:(const void *)bytes length:(NSUInteger)length client:(int)client {
    const uint8_t *cursor = bytes;
    NSUInteger remaining = length;

    while (remaining > 0) {
        ssize_t written = write(client, cursor, remaining);

        if (written <= 0) {
            return NO;
        }

        cursor += written;
        remaining -= written;
    }

    return YES;
}

- (void)sendJSON:(NSDictionary *)payload client:(int)client {
    NSError *error = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];

    if (!body || error) {
        body = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    }

    NSString *header = [NSString stringWithFormat:
        @"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %lu\r\n\r\n",
        (unsigned long)body.length];

    write(client, header.UTF8String, header.length);
    write(client, body.bytes, body.length);
    close(client);
}

- (void)sendDiagnostics:(int)client {
    NSDictionary *status = [self.statusManager statusDictionaryWithFlashEnabled:[FlashManager isFlashEnabled]];
    NSString *body = [NSString stringWithFormat:
        @"<!doctype html><html><head><title>LegacyCam</title></head>"
        "<body><h1>LegacyCam</h1><pre>%@</pre>"
        "<p><a href=\"/stream\">stream</a> <a href=\"/status\">status</a></p></body></html>",
        status];

    NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
    NSString *header = [NSString stringWithFormat:
        @"HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: %lu\r\n\r\n",
        (unsigned long)data.length];

    write(client, header.UTF8String, header.length);
    write(client, data.bytes, data.length);
    close(client);
}

@end
