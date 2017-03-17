//
//  NJOfflineSyncViewController.h
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NJPage;
@class NJViewController;
@interface NJOfflineSyncViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic) BOOL showOfflineFileList;
@property (nonatomic, strong) NJPage *oPage;
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NJViewController *parentController;

@end
