//
//  NJInputPasswordViewController.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJInputPasswordViewController.h"
#import <NISDK/NISDK.h>

@interface NJInputPasswordViewController ()

@property (nonatomic, strong) IBOutlet UIImageView *numberDot1;
@property (nonatomic, strong) IBOutlet UIImageView *numberDot2;
@property (nonatomic, strong) IBOutlet UIImageView *numberDot3;
@property (nonatomic, strong) IBOutlet UIImageView *numberDot4;

@property (nonatomic, strong) IBOutlet UIButton *numberBtn1;
@property (nonatomic, strong) IBOutlet UIButton *numberBtn2;
@property (nonatomic, strong) IBOutlet UIButton *numberBtn3;
@property (nonatomic, strong) IBOutlet UIButton *numberBtn4;
@property (nonatomic, strong) IBOutlet UIButton *numberBtn5;
@property (nonatomic, strong) IBOutlet UIButton *numberBtn6;
@property (nonatomic, strong) IBOutlet UIButton *numberBtn7;
@property (nonatomic, strong) IBOutlet UIButton *numberBtn8;
@property (nonatomic, strong) IBOutlet UIButton *numberBtn9;
@property (nonatomic, strong) IBOutlet UIButton *numberBtn0;

@property (nonatomic, strong) IBOutlet UIButton *backSpace;

@property (nonatomic, strong) IBOutlet UITextView *passwordGuide;

@property (nonatomic) NSTimer *timer;

- (IBAction)numberBtnPressed:(UIButton *)sender;

- (IBAction)backSpacePressed:(id)sender;
@end

@implementation NJInputPasswordViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}]; //back
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    self.navigationController.navigationBar.translucent = YES;
    
    _currentPin = @"";
    
    [_numberBtn1 setImage:[UIImage imageNamed:@"settings_number_1_press.png"] forState:UIControlStateHighlighted];
    [_numberBtn2 setImage:[UIImage imageNamed:@"settings_number_2_press.png"] forState:UIControlStateHighlighted];
    [_numberBtn3 setImage:[UIImage imageNamed:@"settings_number_3_press.png"] forState:UIControlStateHighlighted];
    [_numberBtn4 setImage:[UIImage imageNamed:@"settings_number_4_press.png"] forState:UIControlStateHighlighted];
    [_numberBtn5 setImage:[UIImage imageNamed:@"settings_number_5_press.png"] forState:UIControlStateHighlighted];
    [_numberBtn6 setImage:[UIImage imageNamed:@"settings_number_6_press.png"] forState:UIControlStateHighlighted];
    [_numberBtn7 setImage:[UIImage imageNamed:@"settings_number_7_press.png"] forState:UIControlStateHighlighted];
    [_numberBtn8 setImage:[UIImage imageNamed:@"settings_number_8_press.png"] forState:UIControlStateHighlighted];
    [_numberBtn9 setImage:[UIImage imageNamed:@"settings_number_9_press.png"] forState:UIControlStateHighlighted];
    [_numberBtn0 setImage:[UIImage imageNamed:@"settings_number_0_press.png"] forState:UIControlStateHighlighted];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(penPasswordCompareSuccess:) name:NJPenCommManagerPenConnectionStatusChangeNotification object:nil];
    [nc addObserver:self selector:@selector(penPasswordValidationFail:) name:NJPenCommParserPenPasswordValidationFail object:nil];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)startTimer
{
    if (!_timer)
    {
        _timer = [NSTimer timerWithTimeInterval:0.3
                                         target:self
                                       selector:@selector(completeFourthDot)
                                       userInfo:nil
                                        repeats:YES];
        
        [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
        
    }
}

- (void)stopTimer
{
    [_timer invalidate];
    _timer = nil;
}

- (IBAction)numberBtnPressed:(UIButton *)sender
{
    NSInteger tag = sender.tag;
    NSLog(@"numberBtn %ld Pressed", tag);
    [self newPinSelected:tag];
}

- (IBAction)backSpacePressed:(id)sender
{
    NSLog(@"backSpacePressed");
    if ([self.currentPin length] == 0)
    {
        return;
    }
    
    if ([self.currentPin length] == 1){
        [_numberDot1 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
    }else if ([self.currentPin length] == 2){
        [_numberDot2 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
    }else if ([self.currentPin length] == 3){
        [_numberDot3 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
    }
    
    self.currentPin = [self.currentPin substringWithRange:NSMakeRange(0, [self.currentPin length] - 1)];
    
}

#define PIN_LENGTH 4
- (void)newPinSelected:(NSInteger)pinNumber
{
    if ([self.currentPin length] >= PIN_LENGTH)
    {
        return;
    }
    
    self.currentPin = [NSString stringWithFormat:@"%@%ld", self.currentPin, (long)pinNumber];
    
    if ([self.currentPin length] == 1){
        [_numberDot1 setImage:[UIImage imageNamed:@"field_settings_fill.png"]];
    }else if ([self.currentPin length] == 2){
        [_numberDot2 setImage:[UIImage imageNamed:@"field_settings_fill.png"]];
    }else if ([self.currentPin length] == 3){
        [_numberDot3 setImage:[UIImage imageNamed:@"field_settings_fill.png"]];
    }else if ([self.currentPin length] == PIN_LENGTH)
    {
        [_numberDot4 setImage:[UIImage imageNamed:@"field_settings_fill.png"]];
        [self startTimer];
    }
    
}

- (void) completeFourthDot
{
    [self stopTimer];
    
    [self processPin];
}

- (void) processPin
{
    [[NJPenCommManager sharedInstance] setBTComparePassword:self.currentPin];
    self.savePin = self.currentPin;
    self.currentPin = @"";
    
    [_numberDot1 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
    [_numberDot2 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
    [_numberDot3 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
    [_numberDot4 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
}

- (void)penPasswordCompareSuccess:(NSNotification *)notification
{
    if ((self.savePin != nil) && (![self.savePin isEqualToString:@""])) {
        [MyFunctions saveIntoKeyChainWithPasswd:self.savePin];
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self dismissViewControllerAnimated:YES completion:nil];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:NSLocalizedString(@"Pen Password Input Success", nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
        [alert show];
    }
    self.savePin = @"";
}

- (void)penPasswordValidationFail:(NSNotification *)notification
{
    [self.navigationController popViewControllerAnimated:NO];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:NSLocalizedString(@"PEN_PW_CHANGE_POPUP_FAIL", nil)
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"PEN_PW_SETTING_POPUP_OK", nil)
                                          otherButtonTitles:nil];
    [alert show];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}



@end

