#import "HTTPServer.h"
#import "FlashManager.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>

@implementation HTTPServer {
    int server_fd;
}

- (void)start {
    signal(SIGPIPE, SIG_IGN);
    
    server_fd = socket(AF_INET, SOCK_STREAM, 0);

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(8080);
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

    char buffer[1024] = {0};
    int len = read(client, buffer, sizeof(buffer)-1);

    if (len <= 0) {
        close(client);
        return;
    }

    NSString *request = [[NSString alloc] initWithBytes:buffer
                                                  length:len
                                                encoding:NSUTF8StringEncoding];
    if ([request rangeOfString:@"/flash/on"].location != NSNotFound) {
        [FlashManager setFlash:YES];
    }

    if ([request rangeOfString:@"/flash/off"].location != NSNotFound) {
        [FlashManager setFlash:NO];
    }

    if ([request rangeOfString:@"/snapshot.jpg"].location != NSNotFound) {
        [self sendSnapshot:client];
        return;
    }

    if ([request rangeOfString:@"/stream"].location != NSNotFound) {
        [self sendMJPEG:client];
        return;
    }              

    const char *resp =
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: text/plain\r\n\r\n"
        "LegacyCam OK";

    write(client, resp, strlen(resp));
    close(client);
}

- (void)sendMJPEG:(int)client {
    NSString *header =
    @"HTTP/1.1 200 OK\r\n"
    "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n";

    write(client, header.UTF8String, header.length);

    while (1) {

        UIImage *img = self.camera.latestFrame;

        if (!img) {
            usleep(50000);
            continue;
        }

        NSData *jpg = UIImageJPEGRepresentation(img, 0.3);

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
            break;
        }

        usleep(180000);
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

    NSData *jpg = UIImageJPEGRepresentation(img, 0.4);

    NSString *header = [NSString stringWithFormat:
        @"HTTP/1.1 200 OK\r\nContent-Type: image/jpeg\r\nContent-Length: %lu\r\n\r\n",
        (unsigned long)jpg.length];

    write(client, header.UTF8String, header.length);
    write(client, jpg.bytes, jpg.length);
    close(client);
}

@end