#ifndef LSApplicationProxy_h
#define LSApplicationProxy_h

#import <Foundation/Foundation.h>

@class LSPlugInKitProxy;

@interface LSApplicationProxy : NSObject

+ (LSApplicationProxy *)applicationProxyForIdentifier:(NSString *)bundleIdentifier;

- (BOOL)installed;
- (BOOL)restricted;

- (NSString *)applicationIdentifier;
- (NSString *)localizedName;
- (NSString *)shortVersionString;
- (NSString *)applicationType;
- (NSString *)teamID;

- (NSURL *)bundleURL;
- (NSURL *)dataContainerURL;
- (NSURL *)bundleContainerURL;

- (NSDictionary<NSString *, NSURL *> *)groupContainerURLs;
- (NSDictionary *)entitlements;

- (NSArray<LSPlugInKitProxy *> *)plugInKitPlugins;

- (BOOL)isRemoveableSystemApp;
- (BOOL)isRemovedSystemApp;

@end

#endif /* LSApplicationProxy_h */
