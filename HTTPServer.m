#import "HTTPServer.h"
#import "FlashManager.h"
#import "LCConfigManager.h"
#import "LCRoutes.h"
#import "LCStatusManager.h"
#import <sys/socket.h>
#import <netinet/in.h>
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

        if ([path isEqualToString:LCRouteSnapshot]) {
            [self sendSnapshot:client];
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
    NSString *header =
    @"HTTP/1.1 200 OK\r\n"
    "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n";

    write(client, header.UTF8String, header.length);

    [self.statusManager incrementStreamClients];

    while (1) {
        @autoreleasepool {
            UIImage *img = self.camera.latestFrame;

            if (!img) {
                usleep(50000);
                continue;
            }

            NSData *jpg = UIImageJPEGRepresentation(img, [LCConfigManager sharedManager].streamQuality);

            NSMutableData *chunk = [NSMutableData data];

            NSString *meta = [NSString stringWithFormat:
                @"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %lu\r\n\r\n",
                (unsigned long)jpg.length];

            [chunk appendData:[meta dataUsingEncoding:NSUTF8StringEncoding]];
            [chunk appendData:jpg];
            [chunk appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

            ssize_t w = write(client, chunk.bytes, chunk.length);

            if (w <= 0) {
                close(client);
                [self.statusManager decrementStreamClients];
                break;
            }

            usleep([LCConfigManager sharedManager].frameIntervalUsec);
        }
    }
}

- (void)sendSnapshot:(int)client {

    UIImage *img = self.camera.latestFrame;

    if (!img) {
        const char *err =
            "HTTP/1.1 503 Service Unavailable\r\n\r\n";
        write(client, err, strlen(err));
        close(client);
        return;
    }

    NSData *jpg = UIImageJPEGRepresentation(img, [LCConfigManager sharedManager].snapshotQuality);

    NSString *header = [NSString stringWithFormat:
        @"HTTP/1.1 200 OK\r\nContent-Type: image/jpeg\r\nContent-Length: %lu\r\n\r\n",
        (unsigned long)jpg.length];

    write(client, header.UTF8String, header.length);
    write(client, jpg.bytes, jpg.length);
    close(client);
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
        "<p><a href=\"/stream\">stream</a> <a href=\"/snapshot.jpg\">snapshot</a> "
        "<a href=\"/status\">status</a></p></body></html>",
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
