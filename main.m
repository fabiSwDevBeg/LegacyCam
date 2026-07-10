#import <Foundation/Foundation.h>
#import "LCAppDelegate.h"
#import "LegacyCamDaemon.h"

int main(int argc, char *argv[]) {
	@autoreleasepool {
		for (int index = 1; index < argc; index++) {
			if (strcmp(argv[index], "--daemon") == 0) {
				return LegacyCamDaemonMain(argc, argv);
			}
		}

		return UIApplicationMain(argc, argv, nil, NSStringFromClass(LCAppDelegate.class));
	}
}
