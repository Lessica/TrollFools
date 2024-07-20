#import <UIKit/UIKit.h>

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Hello, World!" message:nil preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
		[self presentViewController:alert animated:YES completion:nil];
	});
}

%end

%ctor {
	@autoreleasepool {
		NSLog(@"Hello, World!");
	}
}