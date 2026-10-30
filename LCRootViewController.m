#import "LCRootViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import "LCLog.h"

@implementation LCRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"LegacyCam";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Grant camera access here. The permission remains granted when the screen locks; camera capture runs in the LegacyCam background service.";
    }

    return @"The MJPEG HTTP server is managed by launchd in the background.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"Camera Permission";
        cell.detailTextLabel.text = [self cameraPermissionText];
        return cell;
    }

    if (indexPath.section == 0 && indexPath.row == 1) {
        cell.textLabel.text = @"Request Camera Access";
        cell.textLabel.textColor = [UIColor blueColor];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }

    cell.textLabel.text = @"Daemon URL";
    cell.detailTextLabel.text = @"http://device-ip:8080/status";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 1) {
        if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType:completionHandler:)]) {
            void (*requestAccess)(id, SEL, NSString *, void (^)(BOOL)) = (void *)objc_msgSend;
            requestAccess([AVCaptureDevice class],
                          @selector(requestAccessForMediaType:completionHandler:),
                          AVMediaTypeVideo,
                          ^(BOOL granted) {
                LCLog(@"camera permission request from app completed: %@", granted ? @"granted" : @"denied");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
            });
        }
    }
}

- (NSString *)cameraPermissionText {
    if (![AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
        return @"Not required";
    }

    NSInteger (*authorizationStatus)(id, SEL, NSString *) = (void *)objc_msgSend;
    NSInteger status = authorizationStatus([AVCaptureDevice class],
                                           @selector(authorizationStatusForMediaType:),
                                           AVMediaTypeVideo);

    switch (status) {
        case 3: // AVAuthorizationStatusAuthorized
            return @"Authorized";
        case 1: // AVAuthorizationStatusDenied
            return @"Denied";
        case 2: // AVAuthorizationStatusRestricted
            return @"Restricted";
        case 0: // AVAuthorizationStatusNotDetermined
            return @"Not Determined";
    }

    return @"Unknown";
}

@end
