//
//  NJPageCanvasController.h
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NJOfflineSyncViewController;
@class NJViewController;
@class NJPage;
@interface NJPageCanvasController : UIViewController <UIAlertViewDelegate>

@property (strong, nonatomic) NJOfflineSyncViewController *offlineSyncViewController;
@property (nonatomic) BOOL closeBtnPressedStatus;
@property (strong, nonatomic) NJViewController *parentController;
@property (strong, nonatomic) NJPage *canvasPage;
@property (nonatomic) NSInteger activeNotebookId;
@property (nonatomic) NSInteger activePageNumber;
@property (nonatomic) UInt32 penColor;

@end
