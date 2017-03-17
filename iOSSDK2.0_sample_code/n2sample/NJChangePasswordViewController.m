//
//  NJChangePasswordViewController.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJChangePasswordViewController.h"
#import <NISDK/NISDK.h>

@interface NJChangePasswordViewController ()

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

@implementation NJChangePasswordViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}]; 
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    self.navigationController.navigationBar.translucent = YES;
    
    _currentPin = @"";
    _savedPin = @"";
    _changeNewPin = @"";

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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(passwordSetupSuccess:) name:NJPenCommParserPenPasswordSutupSuccess object:nil];
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
    
    if([self.changeNewPin isEqualToString:@""]) {
        self.changeNewPin = self.currentPin;
        self.currentPin = @"";
        [_numberDot1 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
        [_numberDot2 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
        [_numberDot3 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
        [_numberDot4 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
        _passwordGuide.text = NSLocalizedString(@"Please re-enter to confirm", nil);
    }else {
        if ([self.currentPin isEqualToString:self.changeNewPin]) {
            [self processPin];
        }else{
            self.currentPin = @"";
            [_numberDot1 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
            [_numberDot2 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
            [_numberDot3 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
            [_numberDot4 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
            _passwordGuide.text = NSLocalizedString(@"Please re-enter to confirm", nil);
            [self passwordSetupFail];
        }
    }
}

- (void) processPin
{
    self.savedPin = [MyFunctions loadPasswd];
    if ([self.savedPin isEqualToString:@""]) {
        self.savedPin = @"0000";
    }
    [[NJPenCommManager sharedInstance] changePasswordFrom:self.savedPin To:self.currentPin];
    
    [_numberDot1 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
    [_numberDot2 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
    [_numberDot3 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
    [_numberDot4 setImage:[UIImage imageNamed:@"field_settings_empty.png"]];
}

- (void)passwordSetupSuccess:(NSNotification *)notification
{
    BOOL passwordChangeResult = [(notification.userInfo)[@"result"] boolValue];
    
    if([self.currentPin isEqualToString:@""]) return;
    
    if (passwordChangeResult) {
        [MyFunctions saveIntoKeyChainWithPasswd:self.currentPin];
        self.currentPin = @"";
        [self.navigationController popViewControllerAnimated:NO];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Password changed", nil)
                                                        message:NSLocalizedString(@"The pen password has been successfully changed.", nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
        [alert show];
    }else{
        [self.navigationController popViewControllerAnimated:NO];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:NSLocalizedString(@"Failed to change password. \nPlease try again.", nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
        [alert show];
    }
    
    
}

- (void)passwordSetupFail
{
    [self.navigationController popViewControllerAnimated:NO];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:NSLocalizedString(@"Failed to change password. \nPlease try again.", nil)
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                          otherButtonTitles:nil];
    [alert show];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

