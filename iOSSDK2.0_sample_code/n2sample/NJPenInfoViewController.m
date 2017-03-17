//
//  NJPenInfoViewController.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJPenInfoViewController.h"
#import <NISDK/NISDK.h>
#import "NJPenSensorCalViewController.h"
#import "NJPenAutoPwrOffTimeViewController.h"
#import "NJAppDelegate.h"
#import "NJChangePasswordViewController.h"

#define kViewTag			1
#define kAlertViewPenInfo 3

static NSString *kSectionTitleKey = @"sectionTitleKey";
static NSString *kRow1LabelKey = @"row1LabelKey";
static NSString *kRow2LabelKey = @"row2LabelKey";
static NSString *kRow3LabelKey = @"row3LabelKey";
static NSString *kRow4LabelKey = @"row4LabelKey";
static NSString *kRow5LabelKey = @"row5LabelKey";
static NSString *kRow1DetailLabelKey = @"row1DetailLabelKey";
static NSString *kRow2DetailLabelKey = @"row2DetailLabelKey";
static NSString *kRow1SourceKey = @"row1SourceKey";
static NSString *kRow2SourceKey = @"row2SourceKey";
static NSString *kRow3SourceKey = @"row3SourceKey";
static NSString *kRow4SourceKey = @"row4SourceKey";
static NSString *kRow1ViewKey = @"row1ViewKey";
static NSString *kRow2ViewKey = @"row2ViewKey";
static NSString *kRow3ViewKey = @"row3ViewKey";
static NSString *kViewController1Key = @"viewController1";
static NSString *kViewController2Key = @"viewController2";
static NSString *kViewController3Key = @"viewController3";
static NSString *kSwitchCellId = @"SwitchCell";
static NSString *kControlCellId = @"ControlCell";
static NSString *kDisplayCellId = @"DisplayCell";
static NSString *kSourceCellId = @"SourceCell";

@interface NJPenInfoCustomTableViewCell : UITableViewCell
@end

@implementation NJPenInfoCustomTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [super initWithStyle:style reuseIdentifier:reuseIdentifier];
}

@end

@interface NJPenInfoViewController ()
@property (nonatomic,retain) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *menuList;
@property (nonatomic, strong) UISwitch *pSwitchCtl;
@property (nonatomic, strong) UISwitch *dSwitchCtl;
@property (nonatomic) BOOL _penConnected;
@property (nonatomic, strong) NJPenCommManager *pencommManager;
@end

@implementation NJPenInfoViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.tableView = [[UITableView alloc] init];
        UIImageView *tempImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bg_settings.png"]];
        [tempImageView setFrame:self.tableView.frame];
        
        self.tableView.backgroundView = tempImageView;
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        
        [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
        
        [self.tableView setSeparatorInset:UIEdgeInsetsZero];
        [self.tableView setSeparatorColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"line_navidrawer.png"]]];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        [defaults synchronize];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _pencommManager = [NJPenCommManager sharedInstance];
    
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}]; //back
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    self.navigationController.navigationBar.translucent = YES;
    
    self.view.layer.cornerRadius = 5;
    self.view.layer.masksToBounds = YES;
    self.navigationController.navigationBar.layer.mask = [self roundedCornerNavigationBar];
    // Do any additional setup after loading the view.
    self.menuList = [NSMutableArray array];
    
    self.editing = NO;
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    NJChangePasswordViewController *changePasswordViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"changePWVC"];
    NJPenAutoPwrOffTimeViewController *penAutoPwrOffTimeViewController = [[NJPenAutoPwrOffTimeViewController alloc] initWithNibName:nil bundle:nil];
    NJPenSensorCalViewController *penSensorCalViewController = [[NJPenSensorCalViewController alloc] initWithNibName:nil bundle:nil];
    [self.menuList addObject:@{ kSectionTitleKey:NSLocalizedString(@"Setting", @""),
                                kRow1LabelKey:NSLocalizedString(@"Change Password", @""),
                                kRow2LabelKey:NSLocalizedString(@"Auto Power", @""),
                                kRow3LabelKey:NSLocalizedString(@"Shutdown Timer", @""),
                                kRow4LabelKey:NSLocalizedString(@"Sound", @""),
                                kRow5LabelKey:NSLocalizedString(@"Pen Sensor Pressure Tuning", @""),
                                kRow1SourceKey:NSLocalizedString(@"Power on Automatically", @""),
                                kRow2SourceKey:NSLocalizedString(@"Save battery without using pen", @""),
                                kRow3SourceKey:NSLocalizedString(@"Alarm in a new event or warning", @""),
                                kRow4SourceKey:NSLocalizedString(@"Pen Pressure Cal Descript", @""),
                                kRow1ViewKey:self.pSwitchCtl,
                                kRow2ViewKey:self.dSwitchCtl,
                                kViewController1Key:changePasswordViewController,
                                kViewController2Key:penAutoPwrOffTimeViewController,
                                kViewController3Key:penSensorCalViewController }];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    self.tableView.frame = self.view.bounds;
    [self.view addSubview:self.tableView];
    
}

#pragma mark - UIViewController delegate

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
 
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}


- (BOOL)shouldShowMiniCanvas {
    
    return NO;
}

- (CAShapeLayer *)roundedCornerNavigationBar
{
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.navigationController.navigationBar.bounds
                                                   byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                                         cornerRadii:CGSizeMake(5.0, 5.0)];
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.navigationController.navigationBar.bounds;
    maskLayer.path = maskPath.CGPath;
    
    return maskLayer;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



#pragma mark - UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.menuList.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 5;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    float height;
    
    if ([indexPath row] == 0) {
        height = 54.5;
    } else {
        height = 74.5;
    }
    
    return height;
    
}

- (NJPenInfoCustomTableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    NJPenInfoCustomTableViewCell *cell = nil;
    
    if ([indexPath row] == 0){
        cell = [tableView dequeueReusableCellWithIdentifier:kControlCellId];
        if (cell == nil) {
            cell = [[NJPenInfoCustomTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kControlCellId];
        }
        NSString *kRowLabelKey = [NSString stringWithFormat:@"row%dLabelKey",(int)([indexPath row] + 1)];
        cell.textLabel.text = [[self.menuList objectAtIndex:0] objectForKey:kRowLabelKey];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.backgroundColor = [UIColor clearColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
    }else{
        cell = [tableView dequeueReusableCellWithIdentifier:kSwitchCellId];
        
        if (cell == nil) {
            cell = [[NJPenInfoCustomTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kSwitchCellId];
        }
        
        NSString *kTitleKey = [NSString stringWithFormat:@"row%dLabelKey",(int)([indexPath row] + 1)];
        cell.textLabel.text = [[self.menuList objectAtIndex:0] valueForKey:kTitleKey];
        cell.textLabel.textColor = [UIColor whiteColor];
        
        cell.detailTextLabel.textColor = [UIColor colorWithRed:190/255.0 green:190/255.0 blue:190/255.0 alpha:1];
        cell.detailTextLabel.numberOfLines = 3;
        cell.textLabel.highlightedTextColor = [UIColor blackColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
        NSString *kSourceKey = [NSString stringWithFormat:@"row%dSourceKey",(int)[indexPath row]];
        cell.detailTextLabel.text = [[self.menuList objectAtIndex: 0] valueForKey:kSourceKey];
        
        cell.backgroundColor = [UIColor clearColor];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        NSString *kViewKey;
        if ([indexPath row] == 1) {
            kViewKey = [NSString stringWithFormat:@"row%dViewKey",(int)[indexPath row]];
        }else if ([indexPath row] == 3) {
            kViewKey = [NSString stringWithFormat:@"row%dViewKey",(int)([indexPath row]-1)];
        }else if (([indexPath row] == 2) || ([indexPath row] == 4)) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        UIControl *control = [[self.menuList objectAtIndex:0] valueForKey:kViewKey];
        
        CGRect newFrame = control.frame;
        newFrame.origin.x = CGRectGetWidth(cell.contentView.frame) - CGRectGetWidth(newFrame) - 15.0;
        control.frame = newFrame;
        
        control.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        
        [cell.contentView addSubview:control];
    }
	   
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath row] == 0) {
        NSString *kViewControllerKey = [NSString stringWithFormat:@"viewController%d",(int)([indexPath row]+1)];
        UIViewController *targetViewController = [[self.menuList objectAtIndex:0] objectForKey:kViewControllerKey];
        [[self navigationController] pushViewController:targetViewController animated:YES];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }else if ([indexPath row] == 2) {
        NSString *kViewControllerKey = [NSString stringWithFormat:@"viewController%d",(int)[indexPath row]];
        UIViewController *targetViewController = [[self.menuList objectAtIndex:0] objectForKey:kViewControllerKey];
        [[self navigationController] pushViewController:targetViewController animated:YES];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }else if ([indexPath row] == 4) {
        NSString *kViewControllerKey = [NSString stringWithFormat:@"viewController%d",(int)([indexPath row]-1)];
        UIViewController *targetViewController = [[self.menuList objectAtIndex:0] objectForKey:kViewControllerKey];
        [[self navigationController] pushViewController:targetViewController animated:YES];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    

}

- (UIView*)tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section {
    
    NSString* sectionHeader = [[self.menuList objectAtIndex: section] objectForKey:kSectionTitleKey];;
    
    UIView* view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 24)];
    
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 24)];
    
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.text = sectionHeader;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [label.font fontWithSize:21.0f];
    
    UIView* separatorLowerLineView = [[UIView alloc] initWithFrame:CGRectMake(0, 40, self.view.bounds.size.width, 0.5)];
    separatorLowerLineView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"line_navidrawer.png"]];
    
    [view addSubview:separatorLowerLineView];
    [view addSubview:label];
    
    return view;
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 40;
}

- (UISwitch *)pSwitchCtl
{
    if (_pSwitchCtl == nil)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        CGRect frame = CGRectMake(239.0, 12.0, 66.0, 32.0);
        _pSwitchCtl = [[UISwitch alloc] initWithFrame:frame];
        [_pSwitchCtl addTarget:self action:@selector(switchAction:) forControlEvents:UIControlEventValueChanged];
        
        // in case the parent view draws with a custom color or gradient, use a transparent color
        BOOL penAutoPower = [defaults boolForKey:@"penAutoPower"];
        
        if (penAutoPower) {
            [_pSwitchCtl setOn:YES];
        } else {
            [_pSwitchCtl setOn:NO];
        }
        
        _pSwitchCtl.backgroundColor = [UIColor clearColor];
        
        _pSwitchCtl.tag = kViewTag;
    }
    return _pSwitchCtl;
}

- (UISwitch *)dSwitchCtl
{
    if (_dSwitchCtl == nil)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        CGRect frame = CGRectMake(239.0, 12.0, 66.0, 32.0);
        _dSwitchCtl = [[UISwitch alloc] initWithFrame:frame];
        [_dSwitchCtl addTarget:self action:@selector(dSwitchAction:) forControlEvents:UIControlEventValueChanged];
        
        // in case the parent view draws with a custom color or gradient, use a transparent color
        _dSwitchCtl.backgroundColor = [UIColor clearColor];
        
        BOOL penSound = [defaults boolForKey:@"penSound"];
        
        if (penSound) {
            [_dSwitchCtl setOn:YES];
        } else {
            [_dSwitchCtl setOn:NO];
        }
        
        _dSwitchCtl.tag = kViewTag;
    }
    return _dSwitchCtl;
}

#define ON 1
#define OFF 2

- (void)switchAction:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL penAutoPower;
    
    BOOL penConnected = [NJPenCommManager sharedInstance].isPenConnected;
    BOOL penRegister = [NJPenCommManager sharedInstance].hasPenRegistered;
    
    if (!penConnected || !penRegister) {
        return;
    }
    
    if([sender isOn]){
        penAutoPower = YES;
        [defaults setBool:penAutoPower forKey:@"penAutoPower"];
        [defaults synchronize];
        [_pSwitchCtl setOn:YES];
    } else {
        penAutoPower = NO;
        [defaults setBool:penAutoPower forKey:@"penAutoPower"];
        [defaults synchronize];
        [_pSwitchCtl setOn:NO];
    }
    
    unsigned char pAutoPwer = penAutoPower? ON : OFF ;
    unsigned char pSound;
    
    if (![NJPenCommManager sharedInstance].isPenSDK2) {
        BOOL penSound = [defaults boolForKey:@"penSound"];
        pSound = penSound? ON : OFF ;
    } else {
        pAutoPwer = penAutoPower;
        pSound = 0xFF;
    }
    
    [[NJPenCommManager sharedInstance] setPenStateAutoPower:pAutoPwer Sound:pSound];
    
    return;
}

- (void)dSwitchAction:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL penSound;
    
    BOOL penConnected = [NJPenCommManager sharedInstance].isPenConnected;
    BOOL penRegister = [NJPenCommManager sharedInstance].hasPenRegistered;
    
    if (!penConnected || !penRegister) {
        return;
    }
    
    if([sender isOn]){
        penSound = YES;
        [defaults setBool:penSound forKey:@"penSound"];
        [defaults synchronize];
        [_dSwitchCtl setOn:YES];
    } else {
        penSound = NO;
        [defaults setBool:penSound forKey:@"penSound"];
        [defaults synchronize];
        [_dSwitchCtl setOn:NO];
    }
    
    unsigned char pSound = penSound? ON : OFF ;
    unsigned char pAutoPwer;
    
    if (![NJPenCommManager sharedInstance].isPenSDK2) {
        BOOL penAutoPower = [defaults boolForKey:@"penAutoPower"];
        pAutoPwer = penAutoPower? ON : OFF ;
    } else {
        pAutoPwer = 0xFF;
        pSound = penSound;
    }
    
    [[NJPenCommManager sharedInstance] setPenStateAutoPower:pAutoPwer Sound:pSound];
    
    return;
}

- (void)startStopAdvertizing:(id)sender
{
    
}

@end

