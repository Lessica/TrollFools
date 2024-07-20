//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "LSApplicationProxy.h"
#import "LSApplicationWorkspace.h"

#import <UIKit/UIKit.h>

FOUNDATION_EXTERN void TFUtilKillAll(NSString *processPath, BOOL softly);

@interface UIImage (Private)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier 
                                                  format:(int)format
                                                   scale:(CGFloat)scale;
@end

