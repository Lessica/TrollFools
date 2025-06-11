//
//  StripedTextTableViewController.m
//  CommonViewControllers
//
//  Created by Lessica <82flex@gmail.com> on 2022/1/20.
//  Copyright © 2022 Zheng Wu. All rights reserved.
//

#import "StripedTextTableViewController.h"

@interface StripedTextTableViewController () <UISearchResultsUpdating>

@property (nonatomic, strong) NSArray <NSString *> *filteredTextRows;
@property (nonatomic, strong) NSArray <NSString *> *textRows;

@property (nonatomic, strong) NSNumberFormatter *decimalNumberFormatter;
@property (nonatomic, assign) NSUInteger numberOfTextRowsNotLoaded;

@property (nonatomic, strong) UIBarButtonItem *shareItem;
@property (nonatomic, strong) UIBarButtonItem *trashItem;
@property (nonatomic, strong) UIBarButtonItem *dismissItem;
@property (nonatomic, strong) UISearchController *searchController;

@property (nonatomic, assign) dispatch_source_t autoReloadSource;

@end

@implementation StripedTextTableViewController
@synthesize entryPath = _entryPath;

+ (NSString *)viewerName {
    return NSLocalizedString(@"Log Viewer", @"StripedTextTableViewController");
}

- (instancetype)initWithPath:(NSString *)path {
    if (self = [super init]) {
        _entryPath = path;
        _rowHeight = UITableViewAutomaticDimension;
        _lineBreakMode = NSLineBreakByWordWrapping;

        _decimalNumberFormatter = [[NSNumberFormatter alloc] init];
        _decimalNumberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.title.length == 0) {
        if (self.entryPath) {
            NSString *entryName = [self.entryPath lastPathComponent];
            self.title = entryName;
        } else {
            self.title = [[self class] viewerName];
        }
    }

    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.searchController = ({
        UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
        searchController.searchResultsUpdater = self;
        searchController.obscuresBackgroundDuringPresentation = NO;
        searchController.hidesNavigationBarDuringPresentation = YES;
        searchController;
    });

    if (self.pullToReload) {
        self.refreshControl = ({
            UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
            [refreshControl addTarget:self action:@selector(reloadTextDataFromEntry:) forControlEvents:UIControlEventValueChanged];
            refreshControl;
        });
    }

    NSMutableArray <UIBarButtonItem *> *rightBarButtonItems = [NSMutableArray arrayWithCapacity:2];

    if (self.allowDismissal) {
        [rightBarButtonItems addObject:self.dismissItem];
    }

    if (@available(iOS 16, *)) {
        if (self.allowShare) {
            [rightBarButtonItems addObject:self.shareItem];
        }
    }

    if (self.allowTrash) {
        [rightBarButtonItems addObject:self.trashItem];
    }

    self.navigationItem.rightBarButtonItems = rightBarButtonItems;

    if (self.allowSearch) {
        self.navigationItem.hidesSearchBarWhenScrolling = YES;
        self.navigationItem.searchController = self.searchController;
    }

    [self.tableView setSeparatorInset:UIEdgeInsetsZero];

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"StripedTextCell"];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CenteredTextCell"];

    [self loadTextDataFromEntry];
}

- (void)reloadTextDataFromEntry:(UIRefreshControl *)sender {
    if (self.searchController.isActive) {
        return;
    }
    [self loadTextDataFromEntry];
    if ([sender isRefreshing]) {
        [sender endRefreshing];
    }
}

- (void)loadTextDataFromEntry {
    NSString *entryPath = self.entryPath;
    if (!entryPath) {
        return;
    }
    NSURL *fileURL = [NSURL fileURLWithPath:entryPath];
    NSError *readError = nil;
    NSFileHandle *textHandler = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&readError];
    if (readError) {
        self.textRows = [NSArray arrayWithObjects:readError.localizedDescription, nil];
        [self.tableView reloadData];
        return;
    }
    if (!textHandler) {
        return;
    }
    if (self.reversed) {
        unsigned long long seekOffset = 0;
        [textHandler seekToEndReturningOffset:&seekOffset error:nil];
        if (seekOffset > 1024 * 1024) {
            [textHandler seekToOffset:seekOffset - 1024 * 1024 error:nil];
        } else {
            [textHandler seekToOffset:0 error:nil];
        }
    }
    NSData *dataPart = [textHandler readDataUpToLength:1024 * 1024 error:nil];
    [textHandler closeFile];
    if (!dataPart) {
        return;
    }
    NSString *stringPart = [[NSString alloc] initWithData:dataPart encoding:NSUTF8StringEncoding];
    if (!stringPart) {
        self.textRows = [NSArray arrayWithObjects:[NSString stringWithFormat:NSLocalizedString(@"Cannot parse text with UTF-8 encoding: “%@”.", nil), [entryPath lastPathComponent]], nil];
        [self.tableView reloadData];
        return;
    }
    if (stringPart.length == 0) {
        self.textRows = [NSArray arrayWithObjects:[NSString stringWithFormat:NSLocalizedString(@"The content of text file “%@” is empty.", nil), [entryPath lastPathComponent]], nil];
        [self.tableView reloadData];
    } else {
        NSMutableArray <NSString *> *rowTexts = nil;

        if (self.rowSeparator) {
            rowTexts = [[stringPart componentsSeparatedByString:self.rowSeparator] mutableCopy];
        } else {
            rowTexts = [[stringPart componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] mutableCopy];
        }

        if (self.rowPrefixRegularExpression) {
            NSMutableArray <NSString *> *mRowTexts = [NSMutableArray arrayWithCapacity:rowTexts.count];
            NSMutableString *mRow = nil;
            for (NSString *row in rowTexts) {
                if (![self.rowPrefixRegularExpression firstMatchInString:row
                      options:NSMatchingAnchored
                      range:NSMakeRange(0, [row length])]
                    ) {
                    [mRow appendString:self.rowSeparator ?: @"\n"];
                    [mRow appendString:row];
                } else {
                    if (mRow)
                        [mRowTexts addObject:[mRow stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                    mRow = [row mutableCopy];
                }
            }
            if (mRow)
                [mRowTexts addObject:[mRow stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
            rowTexts = mRowTexts;
        }

        if (!self.preserveEmptyLines) {
            [rowTexts removeObject:@""];
        }

        if (self.removeDuplicates) {
            NSMutableArray <NSString *> *mRowTexts = [NSMutableArray arrayWithCapacity:rowTexts.count];
            for (NSString *rowText in rowTexts) {
                if (![mRowTexts containsObject:rowText]) {
                    [mRowTexts addObject:rowText];
                }
            }
            rowTexts = mRowTexts;
        }

        if (self.reversed) {
            rowTexts = [[[rowTexts reverseObjectEnumerator] allObjects] mutableCopy];
        }

        if (self.maximumNumberOfRows > 0 && self.maximumNumberOfRows < rowTexts.count) {
            self.textRows = [rowTexts subarrayWithRange:NSMakeRange(0, self.maximumNumberOfRows)];
            self.numberOfTextRowsNotLoaded = rowTexts.count - self.maximumNumberOfRows;
        } else {
            self.textRows = rowTexts;
            self.numberOfTextRowsNotLoaded = 0;
        }

        [self.tableView reloadData];
    }
    if (self.autoReload) {
        [self resetAutoReload];
    }
}

- (void)resetAutoReload {
    int entryfd = open([self.entryPath fileSystemRepresentation], O_EVTONLY);
    if (entryfd < 0) {
        return;
    }

    if (self.autoReloadSource) {
        dispatch_source_cancel(self.autoReloadSource);
        self.autoReloadSource = nil;
    }

    dispatch_queue_t eventQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);

    uintptr_t eventMask = DISPATCH_VNODE_DELETE | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_LINK | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE;

    dispatch_source_t eventSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, entryfd, eventMask, eventQueue);

    __weak typeof(self) weakSelf = self;
    dispatch_block_t eventHandler = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        uintptr_t pendingData = dispatch_source_get_data(eventSource);
        if ((pendingData & DISPATCH_VNODE_DELETE) || (pendingData & DISPATCH_VNODE_RENAME)) {
            dispatch_source_cancel(eventSource);
            strongSelf.autoReloadSource = nil;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf loadTextDataFromEntry];
        });
    };
    dispatch_block_t cancelHandler = ^{
        int closefd = (int)dispatch_source_get_handle(eventSource);
        close(closefd);
    };

    dispatch_source_set_event_handler(eventSource, eventHandler);
    dispatch_source_set_cancel_handler(eventSource, cancelHandler);

    self.autoReloadSource = eventSource;
    dispatch_resume(eventSource);
}

- (void)shareItemTapped:(UIBarButtonItem *)sender {
    if (!self.entryPath) {
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.entryPath]) {
        return;
    }
    NSURL *fileURL = [NSURL fileURLWithPath:self.entryPath];
    if (!fileURL) {
        return;
    }
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    if (@available(iOS 16, *)) {
        activityViewController.popoverPresentationController.sourceItem = sender;
    } else {
        // Fallback on earlier versions
        activityViewController.popoverPresentationController.barButtonItem = sender;
        activityViewController.popoverPresentationController.sourceView = self.view;
    }
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (void)trashItemTapped:(UIBarButtonItem *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Confirm", @"StripedTextTableViewController") message:[NSString stringWithFormat:NSLocalizedString(@"Do you want to clear this log file “%@”?", @"StripedTextTableViewController"), [self.entryPath lastPathComponent]] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"StripedTextTableViewController") style:UIAlertActionStyleCancel handler:^(UIAlertAction *_Nonnull action) {

                      }]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", @"StripedTextTableViewController") style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
                          [[NSData data] writeToFile:[weakSelf entryPath] atomically:YES];
                          [weakSelf loadTextDataFromEntry];
                      }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismissItemTapped:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.searchController.isActive || self.numberOfTextRowsNotLoaded == 0 ? 1 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.searchController.isActive ? self.filteredTextRows.count : self.textRows.count;
    } else {
        return self.numberOfTextRowsNotLoaded == 0 ? 0 : 1;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [UIView new];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return self.allowMultiline ? UITableViewAutomaticDimension : self.rowHeight;
    } else {
        return UITableViewAutomaticDimension;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellName = indexPath.section == 0 ? @"StripedTextCell" : @"CenteredTextCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellName forIndexPath:indexPath];

    if (indexPath.section == 0) {
        NSString *rowText = self.searchController.isActive ? self.filteredTextRows[indexPath.row] : self.textRows[indexPath.row];
        NSString *searchContent = self.searchController.isActive ? self.searchController.searchBar.text : nil;

        NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc] init];
        [paraStyle setLineBreakMode:self.lineBreakMode];

        NSDictionary *rowAttrs = @{
            NSFontAttributeName: [UIFont monospacedSystemFontOfSize:14.0 weight:UIFontWeightRegular],
            NSForegroundColorAttributeName: [UIColor labelColor],
            NSParagraphStyleAttributeName: paraStyle,
        };

        NSMutableAttributedString *mRowText = [[NSMutableAttributedString alloc] initWithString:rowText attributes:rowAttrs];
        if (searchContent) {
            NSRange searchRange = [rowText rangeOfString:searchContent options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch range:NSMakeRange(0, rowText.length)];
            if (searchRange.location != NSNotFound) {
                [mRowText addAttributes:@{
                     NSForegroundColorAttributeName: [UIColor colorWithDynamicProvider:^UIColor *_Nonnull (UITraitCollection *_Nonnull traitCollection) {
                                                          if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                                                              return [UIColor systemBackgroundColor];
                                                          } else {
                                                              return [UIColor labelColor];
                                                          }
                                                      }],
                     NSBackgroundColorAttributeName: [UIColor colorWithRed:253.0/255.0 green:247.0/255.0 blue:148.0/255.0 alpha:1.0],
                 } range:searchRange];
            }
        }

        [cell.textLabel setAttributedText:mRowText];
        [cell.textLabel setTextAlignment:NSTextAlignmentNatural];
        [cell.textLabel setLineBreakMode:self.lineBreakMode];
        [cell.textLabel setNumberOfLines:self.allowMultiline ? (NSInteger)self.maximumNumberOfLines : 1];
        [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
    } else {
        NSDictionary *rowAttrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:14.0],
            NSForegroundColorAttributeName: [UIColor secondaryLabelColor],
        };
        NSAttributedString *rowText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:NSLocalizedString(@"%@ rows not loaded", @"StripedTextTableViewController"), [self.decimalNumberFormatter stringFromNumber:@(self.numberOfTextRowsNotLoaded)]] attributes:rowAttrs];

        [cell.textLabel setAttributedText:rowText];
        [cell.textLabel setTextAlignment:NSTextAlignmentCenter];
        [cell.textLabel setLineBreakMode:NSLineBreakByTruncatingTail];
        [cell.textLabel setNumberOfLines:0];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    }

    if (indexPath.row % 2 == 0) {
        [cell setBackgroundColor:[UIColor systemBackgroundColor]];
    } else {
        [cell setBackgroundColor:[UIColor secondarySystemBackgroundColor]];
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        if (self.tapToCopy) {
            NSString *content = (self.searchController.isActive ? self.filteredTextRows[indexPath.row] : self.textRows[indexPath.row]);
            [[UIPasteboard generalPasteboard] setString:content];
            if ([self.delegate respondsToSelector:@selector(stripedTextTableViewRowDidCopy:withText:)]) {
                [self.delegate stripedTextTableViewRowDidCopy:self withText:content];
            }
        }
    }
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    if (indexPath.section == 0) {
        if (self.pressToCopy) {
            NSString *content = (self.searchController.isActive ? self.filteredTextRows[indexPath.row] : self.textRows[indexPath.row]);
            NSArray <UIAction *> *cellActions = @[
                [UIAction actionWithTitle:NSLocalizedString(@"Copy", @"StripedTextTableViewController") image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(__kindof UIAction *_Nonnull action) {
                     [[UIPasteboard generalPasteboard] setString:content];
                     if ([self.delegate respondsToSelector:@selector(stripedTextTableViewRowDidCopy:withText:)]) {
                         [self.delegate stripedTextTableViewRowDidCopy:self withText:content];
                     }
                 }],
            ];
            return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *_Nullable (NSArray<UIMenuElement *> *_Nonnull suggestedActions) {
                        UIMenu *menu = [UIMenu menuWithTitle:@"" children:cellActions];
                        return menu;
                    }];
        }
    }
    return nil;
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *text = self.searchController.searchBar.text;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", text];
    if (predicate) {
        self.filteredTextRows = [self.textRows filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

#pragma mark - UIView Getters

- (UIBarButtonItem *)shareItem {
    if (!_shareItem) {
        _shareItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareItemTapped:)];
    }
    return _shareItem;
}

- (UIBarButtonItem *)trashItem {
    if (!_trashItem) {
        _trashItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(trashItemTapped:)];
    }
    return _trashItem;
}

- (UIBarButtonItem *)dismissItem {
    if (!_dismissItem) {
        _dismissItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(dismissItemTapped:)];
    }
    return _dismissItem;
}

#pragma mark -

- (void)dealloc {
#if DEBUG
    NSLog(@"-[%@ dealloc]", [self class]);
#endif
}

@end
