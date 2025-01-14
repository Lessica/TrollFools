//
//  StripedTextTableViewController.h
//  CommonViewControllers
//
//  Created by Lessica <82flex@gmail.com> on 2022/1/20.
//  Copyright © 2022 Zheng Wu. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class StripedTextTableViewController;

@protocol StripedTextTableViewControllerDelegate <NSObject>
@optional
- (void)stripedTextTableViewRowDidCopy:(StripedTextTableViewController *)controller withText:(NSString *)text;
@end

@interface StripedTextTableViewController : UITableViewController

@property (nonatomic, weak) id <StripedTextTableViewControllerDelegate> delegate;

- (instancetype)initWithPath:(NSString *)path;
@property (nonatomic, copy, readonly) NSString *entryPath;

@property (nonatomic, assign) BOOL autoReload;

@property (nonatomic, assign) BOOL reversed;
@property (nonatomic, assign) BOOL removeDuplicates;
@property (nonatomic, assign) BOOL allowTrash;
@property (nonatomic, assign) BOOL allowSearch;
@property (nonatomic, assign) BOOL pullToReload;
@property (nonatomic, assign) BOOL tapToCopy;
@property (nonatomic, assign) BOOL pressToCopy;
@property (nonatomic, assign) BOOL preserveEmptyLines;

@property (nonatomic, assign) CGFloat rowHeight;
@property (nonatomic, assign) BOOL allowMultiline;
@property (nonatomic, assign) NSLineBreakMode lineBreakMode;

@property (nonatomic, assign) NSUInteger maximumNumberOfLines;  // default is 0, unlimited
@property (nonatomic, assign) NSUInteger maximumNumberOfRows;   // default is 0, unlimited

@property (nonatomic, copy) NSString *rowSeparator;
@property (nonatomic, copy) NSRegularExpression *rowPrefixRegularExpression;

@end

NS_ASSUME_NONNULL_END
