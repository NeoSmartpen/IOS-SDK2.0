//
//  NJFWUpdateViewController.h
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NJFWUpdateViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *indicator;
@property (strong, nonatomic) IBOutlet UILabel *penVersionLabel;

@property (strong, nonatomic) IBOutlet UIView *progressView;
@property (strong, nonatomic) IBOutlet UILabel *progressViewLabel;
@property (strong, nonatomic) IBOutlet UIProgressView *progressBar;

@end
