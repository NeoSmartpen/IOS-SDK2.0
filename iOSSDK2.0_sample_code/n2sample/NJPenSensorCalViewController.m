//
//  NJPenSensorCalViewController.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJPenSensorCalViewController.h"
#import <NISDK/NISDK.h>

#define kPenPressureValue1 4
#define kPenPressureValue2 3
#define kPenPressureValue3 2
#define kPenPressureValue4 1
#define kPenPressureValue5 0

static NSString *kSectionTitleKey = @"sectionTitleKey";
static NSString *kSourceKey = @"sourceKey";
static NSString *kRow1LabelKey = @"row1LabelKey";
static NSString *kRow2LabelKey = @"row2LabelKey";
static NSString *kRow3LabelKey = @"row3LabelKey";
static NSString *kRow4LabelKey = @"row4LabelKey";
static NSString *kRow5LabelKey = @"row5LabelKey";

static NSString *kCheckCellID = @"kCheckCellID";
static NSString *kSourceCellID = @"SourceCellID";

@interface NJPenSensorCalViewController ()
@property (nonatomic,retain) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *menuList;
@property (nonatomic, strong) NSIndexPath *lastIndexPath;

@end


#pragma mark -

@implementation NJPenSensorCalViewController

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
        
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}]; //back
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    self.navigationController.navigationBar.translucent = YES;
    
     self.menuList = [NSMutableArray array];
    
    self.editing = NO;
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCheckCellID];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kSourceCellID];
    
    self.tableView.frame = self.view.bounds;
    [self.view addSubview:self.tableView];
    
}

- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    
    if ([self.menuList count]) {
        [self.menuList removeAllObjects];
    }
    
    [self.menuList addObject:@{ kSectionTitleKey:NSLocalizedString(@"Pen Sensor Pressure Tuning", @""),
                                kSourceKey:NSLocalizedString(@"Pen pressure is more insensitive as close as level 1.", @""),
                                kRow1LabelKey:NSLocalizedString(@"Level 1", @""),
                                kRow2LabelKey:NSLocalizedString(@"Level 2", @""),
                                kRow3LabelKey:NSLocalizedString(@"Level 3", @""),
                                kRow4LabelKey:NSLocalizedString(@"Level 4", @""),
                                kRow5LabelKey:NSLocalizedString(@"Level 5 (The most sensitive)", @"")}];
    
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [self setPenPressureCalibration];
    
    [super viewWillDisappear:animated];
}

- (BOOL)shouldShowMiniCanvas
{
    return NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.menuList count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 6;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ([indexPath row] == 5) ? 65.0 : 54.5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    if ([indexPath row] == 5)
    {
        cell = [tableView dequeueReusableCellWithIdentifier:kSourceCellID forIndexPath:indexPath];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor colorWithRed:190/255.0 green:190/255.0 blue:190/255.0 alpha:1];
        cell.textLabel.numberOfLines = 3;
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.highlightedTextColor = [UIColor blackColor];
        cell.textLabel.font = [UIFont systemFontOfSize:12.0];
        
        cell.textLabel.text = [[self.menuList objectAtIndex: 0] valueForKey:kSourceKey];
    }
    else
    {
        cell = [tableView dequeueReusableCellWithIdentifier:kCheckCellID forIndexPath:indexPath];
        
        NSString *kLabelKey = [NSString stringWithFormat:@"row%dLabelKey",(int)([indexPath row] + 1)];
        cell.textLabel.text = [[self.menuList objectAtIndex:0] objectForKey:kLabelKey];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.backgroundColor = [UIColor clearColor];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSNumber *nPenPressure = [defaults objectForKey:@"penPressure"];
        UInt16 penPressure = [nPenPressure intValue];
        NSUInteger index;
        
        switch (penPressure) {
            case kPenPressureValue1:
                index = 0;
                break;
            case kPenPressureValue2:
                index = 1;
                break;
            case kPenPressureValue3:
                index = 2;
                break;
            case kPenPressureValue4:
                index = 3;
                break;
            case kPenPressureValue5:
                index = 4;
                break;
            default:
                index = 4;
                break;
        }
        if ([indexPath row] == index) {
            self.lastIndexPath = indexPath;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }else{
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath row] != 5) {
        
        if ([self.lastIndexPath row] != [indexPath row])
        {
            UITableViewCell *newCell = [tableView cellForRowAtIndexPath: indexPath];
            newCell.accessoryType = UITableViewCellAccessoryCheckmark;
            
            UITableViewCell *oldCell = [tableView cellForRowAtIndexPath:self.lastIndexPath];
            oldCell.accessoryType = UITableViewCellAccessoryNone;
            
            self.lastIndexPath = indexPath;
        }
        else {
            UITableViewCell *newCell = [tableView cellForRowAtIndexPath: indexPath];
            newCell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        
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

- (void)setPenPressureCalibration
{
    UInt16 penPressure;
    
    switch ([self.lastIndexPath row]) {
        case 0:
            penPressure = kPenPressureValue1;
            break;
        case 1:
            penPressure = kPenPressureValue2;
            break;
        case 2:
            penPressure = kPenPressureValue3;
            break;
        case 3:
            penPressure = kPenPressureValue4;
            break;
        case 4:
            penPressure = kPenPressureValue5;
            break;
        default:
            penPressure = kPenPressureValue5;
            break;
    }
    
    [[NJPenCommManager sharedInstance] setPenStateWithPenPressure:penPressure];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInt:penPressure] forKey:@"penPressure"];
    [defaults synchronize];
}

@end

