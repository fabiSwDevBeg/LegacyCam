#import "LCRootViewController.h"
#import <AVFoundation/AVFoundation.h>

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
        return @"Open this app once on iOS 12 and allow camera access, then reload the LegacyCam daemon.";
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
        cell.textLabel.textColor = self.view.tintColor;
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
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }];
    }
}

- (NSString *)cameraPermissionText {
    if (![AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)]) {
        return @"Not required";
    }

    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

    switch (status) {
        case AVAuthorizationStatusAuthorized:
            return @"Authorized";
        case AVAuthorizationStatusDenied:
            return @"Denied";
        case AVAuthorizationStatusRestricted:
            return @"Restricted";
        case AVAuthorizationStatusNotDetermined:
            return @"Not Determined";
    }

    return @"Unknown";
}

@end
