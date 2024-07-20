#ifndef LSApplicationWorkspace_h
#define LSApplicationWorkspace_h

#import <Foundation/Foundation.h>

@class LSApplicationProxy;

@interface LSApplicationWorkspace : NSObject

+ (LSApplicationWorkspace *)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allApplications;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;

- (void)enumerateApplicationsOfType:(NSInteger)type block:(void (^)(id))block;

- (BOOL)openApplicationWithBundleID:(NSString *)bundleIdentifier;
- (BOOL)installApplication:(NSURL *)ipaPath withOptions:(id)arg2 error:(NSError *__autoreleasing *)error;
- (BOOL)uninstallApplication:(NSString *)bundleIdentifier withOptions:(id)arg2;
- (BOOL)uninstallApplication:(NSString *)arg1
                 withOptions:(id)arg2
                       error:(NSError *__autoreleasing *)arg3
                  usingBlock:(/*^block*/ id)arg4;
- (BOOL)invalidateIconCache:(id)arg1;
- (BOOL)openSensitiveURL:(NSURL *)url withOptions:(id)arg2 error:(NSError *__autoreleasing *)error;

- (void)removeObserver:(id)arg1;
- (void)addObserver:(id)arg1;

@end

#endif /* LSApplicationWorkspace_h */
