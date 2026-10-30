#import "HTTPServer.h"
#import "FlashManager.h"
#import "LCConfigManager.h"
#import "LCPreferences.h"
#import "LCRoutes.h"
#import "LCStatusManager.h"
#import "LCLog.h"
#import <sys/socket.h>
#import <sys/time.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>

@implementation HTTPServer {
    int server_fd;
    int activeStreamClient;
    NSLock *streamLock;
    dispatch_queue_t flashQueue;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        activeStreamClient = -1;
        streamLock = [[NSLock alloc] init];
        flashQueue = dispatch_queue_create("com.fabiswdevbeg.legacycam.flash", DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

- (void)start {
    signal(SIGPIPE, SIG_IGN);

    if (!self.statusManager) {
        self.statusManager = [[LCStatusManager alloc] init];
    }

    dispatch_async(flashQueue, ^{
        [FlashManager refreshTorchAvailability];
        LCLog(@"initial torch availability: %@", [FlashManager isTorchAvailable] ? @"available" : @"unavailable");
    });
    
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        LCLog(@"HTTP socket creation failed: %s", strerror(errno));
        return;
    }

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons([LCConfigManager sharedManager].port);
    addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        LCLog(@"HTTP bind on port %u failed: %s", ntohs(addr.sin_port), strerror(errno));
        close(server_fd);
        server_fd = -1;
        return;
    }

    if (listen(server_fd, 16) < 0) {
        LCLog(@"HTTP listen failed: %s", strerror(errno));
        close(server_fd);
        server_fd = -1;
        return;
    }

    LCLog(@"HTTP server listening on port %u", ntohs(addr.sin_port));

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self loop];
    });
}

- (void)loop {

    while (1) {

        int client = accept(server_fd, NULL, NULL);
        if (client < 0) continue;

        [self configureClientSocket:client forStream:NO];

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
            LCLog(@"HTTP request read failed: result=%d errno=%d", len, errno);
            close(client);
            return;
        }

        NSString *request = [[NSString alloc] initWithBytes:buffer
                                                      length:len
                                                    encoding:NSUTF8StringEncoding];
        NSString *path = [self pathForRequest:request];
        LCLog(@"HTTP request %@", path);

        if ([path isEqualToString:LCRoutePing]) {
            [self sendJSON:@{@"ok": @YES} client:client];
            return;
        }

        if ([path isEqualToString:LCRouteStatus]) {
            [self sendJSON:[self statusPayload] client:client];
            return;
        }

        if ([path isEqualToString:LCRouteFlashStatus]) {
            [self sendJSON:@{
                @"enabled": @([FlashManager isFlashEnabled]),
                @"available": @([FlashManager isTorchAvailable]),
                @"error": [FlashManager lastError] ?: @""
            } client:client];
            return;
        }

        if ([path isEqualToString:LCRouteFlashOn]) {
            dispatch_async(flashQueue, ^{
                [FlashManager setFlash:YES];
            });
            [self sendFlashAccepted:YES client:client];
            return;
        }

        if ([path isEqualToString:LCRouteFlashOff]) {
            dispatch_async(flashQueue, ^{
                [FlashManager setFlash:NO];
            });
            [self sendFlashAccepted:NO client:client];
            return;
        }

        if ([path isEqualToString:LCRouteStream]) {
            if (![LCPreferences isCameraEnabled] || !self.camera.isRunning || !self.camera.producingFrames) {
                LCLog(@"stream rejected: enabled=%d running=%d producing_frames=%d",
                      [LCPreferences isCameraEnabled], self.camera.isRunning, self.camera.producingFrames);
                [self sendUnavailable:client];
                return;
            }

            [self sendMJPEG:client];
            return;
        }

        [self sendDiagnostics:client];
    }
}

- (NSDictionary *)statusPayload {
    NSMutableDictionary *payload = [[self.statusManager statusDictionaryWithFlashEnabled:[FlashManager isFlashEnabled]
                                                                           cameraEnabled:[LCPreferences isCameraEnabled]
                                                                           cameraRunning:self.camera.isRunning
                                                                             cameraError:self.camera.lastError] mutableCopy];

    payload[@"flash_available"] = @([FlashManager isTorchAvailable]);
    payload[@"flash_error"] = [FlashManager lastError] ?: @"";
    payload[@"frame_sequence"] = @(self.camera.latestJPEGSequence);
    payload[@"latest_jpeg_bytes"] = @(self.camera.latestJPEG.length);
    payload[@"camera_producing_frames"] = @(self.camera.producingFrames);
    payload[@"max_stream_clients"] = @([LCConfigManager sharedManager].maxStreamClients);

    return payload;
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
    [self configureClientSocket:client forStream:YES];

    [streamLock lock];
    int previousClient = activeStreamClient;
    activeStreamClient = client;

    if (previousClient < 0) {
        [self.statusManager incrementStreamClients];
    }

    [streamLock unlock];

    if (previousClient >= 0) {
        LCLog(@"new stream client replaced the previous client");
        shutdown(previousClient, SHUT_RDWR);
    }

    LCLog(@"MJPEG stream connected");

    NSString *header =
    @"HTTP/1.1 200 OK\r\n"
    "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n";

    if (![self writeStreamString:header client:client]) {
        [self finishStreamClient:client];
        return;
    }

    NSUInteger lastSequence = 0;

    while (1) {
        @autoreleasepool {
            if (![self isActiveStreamClient:client]) {
                break;
            }

            NSData *jpg = self.camera.latestJPEG;
            NSUInteger sequence = self.camera.latestJPEGSequence;

            if (!jpg || sequence == lastSequence) {
                usleep(50000);
                continue;
            }

            NSString *meta = [NSString stringWithFormat:
                @"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %lu\r\n\r\n",
                (unsigned long)jpg.length];

            if (![self writeStreamString:meta client:client] ||
                ![self writeStreamData:jpg client:client] ||
                ![self writeStreamString:@"\r\n" client:client]) {
                [self finishStreamClient:client];
                LCLog(@"MJPEG stream write failed");
                break;
            }

            lastSequence = sequence;
        }
    }
}

- (BOOL)isActiveStreamClient:(int)client {
    [streamLock lock];
    BOOL isActive = activeStreamClient == client;
    [streamLock unlock];
    return isActive;
}

- (BOOL)writeStreamString:(NSString *)string client:(int)client {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self writeStreamData:data client:client];
}

- (BOOL)writeStreamData:(NSData *)data client:(int)client {
    [streamLock lock];
    BOOL isActive = activeStreamClient == client;
    [streamLock unlock];

    return isActive && [self writeData:data client:client];
}

- (void)finishStreamClient:(int)client {
    [streamLock lock];

    if (activeStreamClient == client) {
        activeStreamClient = -1;
        [self.statusManager decrementStreamClients];
    }

    close(client);
    [streamLock unlock];
}

- (void)configureClientSocket:(int)client forStream:(BOOL)stream {
    int noDelay = 1;
    int keepAlive = 1;
    setsockopt(client, IPPROTO_TCP, TCP_NODELAY, &noDelay, sizeof(noDelay));
    setsockopt(client, SOL_SOCKET, SO_KEEPALIVE, &keepAlive, sizeof(keepAlive));

    struct timeval receiveTimeout;
    receiveTimeout.tv_sec = stream ? 5 : 2;
    receiveTimeout.tv_usec = 0;
    setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &receiveTimeout, sizeof(receiveTimeout));

    struct timeval sendTimeout;
    sendTimeout.tv_sec = stream ? 5 : 2;
    sendTimeout.tv_usec = 0;
    setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &sendTimeout, sizeof(sendTimeout));
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

- (void)sendFlashAccepted:(BOOL)enabled client:(int)client {
    NSDictionary *payload = @{
        @"accepted": @YES,
        @"requested_enabled": @(enabled),
        @"enabled": @([FlashManager isFlashEnabled]),
        @"available": @([FlashManager isTorchAvailable]),
        @"error": [FlashManager lastError] ?: @""
    };
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    NSString *header = [NSString stringWithFormat:
        @"HTTP/1.1 202 Accepted\r\nContent-Type: application/json\r\nContent-Length: %lu\r\n\r\n",
        (unsigned long)body.length];

    [self writeString:header client:client];
    [self writeData:body client:client];
    close(client);
}

- (void)sendUnavailable:(int)client {
    NSDictionary *payload = [self statusPayload];
    NSError *error = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];

    if (!body || error) {
        body = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    }

    NSString *header = [NSString stringWithFormat:
        @"HTTP/1.1 503 Service Unavailable\r\nContent-Type: application/json\r\nContent-Length: %lu\r\n\r\n",
        (unsigned long)body.length];

    write(client, header.UTF8String, header.length);
    write(client, body.bytes, body.length);
    close(client);
}

- (void)sendDiagnostics:(int)client {
    NSDictionary *status = [self statusPayload];
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
