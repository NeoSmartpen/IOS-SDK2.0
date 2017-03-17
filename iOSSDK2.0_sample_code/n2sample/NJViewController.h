//
//  NJViewController.h
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NJPageCanvasController;
@interface NJViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *statusMessage;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (nonatomic) BOOL canvasCloseBtnPressed;
@property (nonatomic, strong) NJPageCanvasController *pageCanvasController;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;

@end
