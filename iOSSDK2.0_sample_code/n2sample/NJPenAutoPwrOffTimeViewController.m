//
//  NJPenAutoPwrOffTimeViewController.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJPenAutoPwrOffTimeViewController.h"
#import <NISDK/NISDK.h>

#define kPwrOffTime1 10
#define kPwrOffTime2 20
#define kPwrOffTime3 40
#define kPwrOffTime4 60

static NSString *kSectionTitleKey = @"sectionTitleKey";
static NSString *kSourceKey = @"sourceKey";
static NSString *kRow1LabelKey = @"row1LabelKey";
static NSString *kRow2LabelKey = @"row2LabelKey";
static NSString *kRow3LabelKey = @"row3LabelKey";
static NSString *kRow4LabelKey = @"row4LabelKey";

static NSString *kCheckCellID = @"kCheckCellID";
static NSString *kSourceCellID = @"SourceCellID";

@interface NJPenAutoPwrOffTimeViewController ()
@property (nonatomic,retain) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *menuList;
@property (nonatomic, strong) NSIndexPath *lastIndexPath;

@end


#pragma mark -

@implementation NJPenAutoPwrOffTimeViewController

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
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    self.navigationController.navigationBar.translucent = YES;
    
    self.menuList = [NSMutableArray array];
    
    self.editing = NO;
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    self.tableView.frame = self.view.bounds;
    [self.view addSubview:self.tableView];
    
}

- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    
    if ([self.menuList count]) {
        [self.menuList removeAllObjects];
    }
    
    [self.menuList addObject:@{ kSectionTitleKey:NSLocalizedString(@"Shutdown Timer", @""),
                                kSourceKey:NSLocalizedString(@"If setting time is long, usable time of the is shorter.", @""),
                                kRow1LabelKey:NSLocalizedString(@"10 minutes", @""),
                                kRow2LabelKey:NSLocalizedString(@"20 minutes", @""),
                                kRow3LabelKey:NSLocalizedString(@"40 minutes", @""),
                                kRow4LabelKey:NSLocalizedString(@"60 minutes", @"")}];
    
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [self setAutoPwrOffTime];
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
    return 5;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ([indexPath row] == 4) ? 65.0 : 54.5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    if ([indexPath row] == 4)
    {
        cell = [tableView dequeueReusableCellWithIdentifier:kSourceCellID];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kSourceCellID];
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor colorWithRed:190/255.0 green:190/255.0 blue:190/255.0 alpha:1];
        cell.textLabel.numberOfLines = 3;
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.highlightedTextColor = [UIColor blackColor];
        cell.textLabel.font = [UIFont systemFontOfSize:12.0];
        
        cell.textLabel.text = [[self.menuList objectAtIndex: 0] valueForKey:kSourceKey];
    }
    else{
        cell = [tableView dequeueReusableCellWithIdentifier:kCheckCellID];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCheckCellID];
        }
        
        NSString *kLabelKey = [NSString stringWithFormat:@"row%dLabelKey",(int)[indexPath row] + 1];
        cell.textLabel.text = [[self.menuList objectAtIndex:0] objectForKey:kLabelKey];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.backgroundColor = [UIColor clearColor];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSNumber *nAutoPwrOff = [defaults objectForKey:@"autoPwrOff"];
        UInt16 autoPwrOff = [nAutoPwrOff intValue];
        NSUInteger index;
        
        switch (autoPwrOff) {
            case kPwrOffTime1:
                index = 0;
                break;
            case kPwrOffTime2:
                index = 1;
                break;
            case kPwrOffTime3:
                index = 2;
                break;
            case kPwrOffTime4:
                index = 3;
                break;
            default:
                index = 1;
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

- (void)setAutoPwrOffTime
{
    UInt16 autoPwrOff;
    
    switch ([self.lastIndexPath row]) {
        case 0:
            autoPwrOff = kPwrOffTime1;
            break;
        case 1:
            autoPwrOff = kPwrOffTime2;
            break;
        case 2:
            autoPwrOff = kPwrOffTime3;
            break;
        case 3:
            autoPwrOff = kPwrOffTime4;
            break;
        default:
            autoPwrOff = kPwrOffTime2;
            break;
    }
    
    [[NJPenCommManager sharedInstance] setPenStateWithAutoPwrOffTime:autoPwrOff];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInt:autoPwrOff] forKey:@"autoPwrOff"];
    [defaults synchronize];
}

@end
