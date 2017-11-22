//
//  NJViewController.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJViewController.h"
#import <NISDK/NISDK.h>
#import "NJPageCanvasController.h"
#import "NJPenInfoViewController.h"
#import "NJOfflineSyncViewController.h"
#import "NJFWUpdateViewController.h"
#import "NJInputPasswordViewController.h"
#import <MessageUI/MFMailComposeViewController.h>
#import "NJPage.h"

typedef enum{
    BT_DISCONNECTED = 0,
    BT_CONNECTING,
    BT_CONNECTED,
    BT_UNREGISTERED,
}BT_STATUS;

@interface NJViewController () <UIActionSheetDelegate, NJPenStatusDelegate, NJPenPasswordDelegate,NJPenCommParserStartDelegate,NJPenCommParserCommandHandler,NJPenCommManagerNewPeripheral,MFMailComposeViewControllerDelegate>
@property (nonatomic, strong) NJPenCommManager *pencommManager;
@property (nonatomic) NSUInteger btStatus;
@property (nonatomic) NSInteger activeNotebookId;
@property (nonatomic) NSInteger activePageNumber;
@property (nonatomic, strong) NJPage *cPage;
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSMutableArray *discoveredPeripherals;
@property (strong, nonatomic) NSMutableArray *macArray;
@property (strong, nonatomic) NSMutableArray *serviceIdArray;
@property (strong, nonatomic) UIColor *color;
@property (nonatomic) UInt16 useHover;
@property (nonatomic) BOOL isNoteInfoInstalled;
@end

@implementation NJViewController
@synthesize pencommManager = pencommManager;
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.canvasCloseBtnPressed = NO;
    UIButton *menuBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 46, 44)]; //-20
    [menuBtn setImage:[UIImage imageNamed:@"btn_Navigation Drawer.png"] forState:UIControlStateNormal];
    [menuBtn addTarget:self action:@selector(menuBtnPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    UIView * menuButtonView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 46.0f, 44.0f)];
    [menuButtonView addSubview:menuBtn];
    
    UIBarButtonItem *revealMenuBarButtonItem = [[UIBarButtonItem alloc]initWithCustomView:menuButtonView ];
    self.navigationItem.leftBarButtonItem = revealMenuBarButtonItem;

    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    self.navigationController.navigationBar.translucent = YES;
    
    self.view.layer.cornerRadius = 5;
    self.view.layer.masksToBounds = YES;
    
    [self.view setBackgroundColor:[UIColor colorWithWhite:0.95f alpha:1]];
    
    UIImageView *bgImg = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [bgImg setImage:[UIImage imageNamed:@"bg_page_overlay"]];
    
    [self.view addSubview:bgImg];
  
    pencommManager = [NJPenCommManager sharedInstance];
    
    [self processStepInstallNewNotebookInfos];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(writingOnCanvasStart:) name:NJPenCommParserPageChangedNotification object:nil];
    
    [nc addObserver:self selector:@selector(btStatusChanged:) name:NJPenCommManagerPenConnectionStatusChangeNotification object:nil];
    
    [nc addObserver:self selector:@selector(penPasswordCompareSuccess:) name:NJPenCommParserPenPasswordSutupSuccess object:nil];

    if([pencommManager hasPenRegistered])
        _statusMessage.text = @"Neo Pen is not connected.";
    else
        _statusMessage.text = @"Neo Pen is not registered.";
}
- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [pencommManager setPenCommParserStartDelegate:self];
    [pencommManager setPenCommParserCommandHandler:self];

}
- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
}

- (void)processStepInstallNewNotebookInfos
{

    if (_isNoteInfoInstalled) {
        _isNoteInfoInstalled = YES;
        return;
    }
    
    self.progressView.hidden = NO;
    self.progressLabel.hidden = NO;
    self.progressView.progress = 0.0f;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSArray *notebookInfos = [[NSBundle mainBundle] pathsForResourcesOfType:@"zip" inDirectory:@"books_2016_02"];
        NSUInteger tot = notebookInfos.count;
        __block NSUInteger count = 0;
        for(NSString *path in notebookInfos) {
            NSURL *fileURL = [NSURL fileURLWithPath:path];
            NSString *fileName = [[path lastPathComponent] stringByDeletingPathExtension];;
            if(![fileName hasPrefix:@"note_"]) continue;
            
            
            NSUInteger notebookId = 0;
            NSArray *tokens = [fileName componentsSeparatedByString:@"_"];
            BOOL shouldDeleteExisiting = YES;
            if(tokens.count > 3 || tokens.count < 2) continue;
            
            if(tokens.count == 3) {
                shouldDeleteExisiting = ([[tokens objectAtIndex:2] integerValue] == 0)? YES : NO;
                notebookId = [[tokens objectAtIndex:1] integerValue];
            } else if(tokens.count == 2) {
                notebookId = [[tokens objectAtIndex:1] integerValue];
            }
            
            if(notebookId <= 0) continue;
            NSUInteger section,owner;
            [NJPage section:&section owner:&owner fromNotebookId:notebookId];
            NSString *keyName = [NPPaperManager keyNameForNotebookId:notebookId section:section owner:owner];
            [[NPPaperManager sharedInstance] installNotebookInfoForKeyName:keyName zipFilePath:fileURL deleteExisting:shouldDeleteExisiting];
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.progressView.progress = ((float)++count)/((float)tot);
                if (self.progressView.progress == 1.0f) {
                    self.progressView.hidden = YES;
                    self.progressLabel.hidden = YES;
                }
            });
        }

    });
    
}

- (void)setBtStatus:(NSUInteger)btStatus
{
    if (btStatus == BT_DISCONNECTED) {
        [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
        _statusMessage.text = @"Neo Pen is not connected.";
        
    }
    else if (btStatus == BT_CONNECTING) {
        [_connectButton setTitle:@"Connecting" forState:UIControlStateNormal];
        _statusMessage.text = @"Scanning Neo Pen.";
    }
    else if (btStatus == BT_CONNECTED) {
        [_connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        NSString *mac = [pencommManager regUuid];
        NSString *protocolVersion = [pencommManager protocolVersion];
        NSString *subName = [pencommManager subName];
        _statusMessage.text = @"Neo Pen is connected.";
    } else if (btStatus == BT_UNREGISTERED) {
        [_connectButton setTitle:@"Register" forState:UIControlStateNormal];
        _statusMessage.text = @"Neo Pen is not registered.";
        
    }
    _btStatus = btStatus;
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

}
- (IBAction)actionButton:(id)sender {
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:@"Menu"
                                  delegate:self
                                  cancelButtonTitle:@"Cancel"
                                  destructiveButtonTitle:@"Do something else"
                                  otherButtonTitles:@"connect",@"disconnect", nil];
    
    [actionSheet showFromBarButtonItem:sender animated:YES];
    
    if ((_btStatus == BT_DISCONNECTED) || (_btStatus == BT_UNREGISTERED)) {
        [pencommManager btStart];
        self.btStatus = BT_CONNECTING;
    }
    else if (_btStatus == BT_CONNECTED) {
        [pencommManager disConnect];
    }
}

- (void)writingOnCanvasStart:(NSNotification *)notification
{
    if (self.canvasCloseBtnPressed) {
        self.pageCanvasController= nil;
        self.canvasCloseBtnPressed = NO;
    }
    
    if (!self.pageCanvasController) {
        self.pageCanvasController = [[NJPageCanvasController alloc] initWithNibName:nil bundle:nil];
        self.pageCanvasController.parentController = self;
        self.pageCanvasController.activeNotebookId = self.activeNotebookId;
        self.pageCanvasController.activePageNumber = self.activePageNumber;
        self.pageCanvasController.canvasPage = self.cPage;

        if (_color) {
            self.pageCanvasController.penColor = [self convertUIColorToAlpahRGB:_color];
        }
        [self presentViewController:self.pageCanvasController animated:YES completion:^{
        }];
    }
}

- (void)btStatusChanged:(NSNotification *)notification
{
    NSInteger penConnctionStatus = [[[notification userInfo] valueForKey:@"info"] integerValue];
    [self checkBtStatus:penConnctionStatus];
}
- (void) checkBtStatus:(NSInteger)penConnectionStatus
{
    if(penConnectionStatus == NJPenCommManPenConnectionStatusConnected){
        self.btStatus = BT_CONNECTED;
    } else if(penConnectionStatus == NJPenCommManPenConnectionStatusScanStarted){
        self.btStatus = BT_CONNECTING;
    }
    else {
        if([pencommManager hasPenRegistered])
            self.btStatus = BT_DISCONNECTED;
        else
            self.btStatus = BT_UNREGISTERED;
    }
}

- (void)menuBtnPressed:(UIBarButtonItem *)sender
{
    UIActionSheet *actionSheet;
    
    if ([pencommManager hasPenRegistered]) {
        actionSheet = [[UIActionSheet alloc]
                                      initWithTitle:@"Menu"
                                      delegate:self
                                      cancelButtonTitle:@"Cancel"
                                      destructiveButtonTitle:nil
                                      otherButtonTitles:@"Connect",@"Disconnect",@"Pen Unregistration",@"Setting",@"OfflineData list",@"Show OfflineData", @"Pen Firmware Update", @"Pen Status", @"Transferable Note ID",@"Change canvas Color",@"Pen Tip Color",@"BT List", @"Battery Level and Memory Space", @"BT ID", nil];
    }else{
        actionSheet = [[UIActionSheet alloc]
                                      initWithTitle:@"Menu"
                                      delegate:self
                                      cancelButtonTitle:@"Cancel"
                                      destructiveButtonTitle:nil
                                      otherButtonTitles:@"Register",@"Disconnect",@"Pen Unregistration",@"Setting",@"OfflineData list",@"Show OfflineData", @"Pen Firmware Update", @"Pen Status", @"Transferable Note ID",@"Change canvas Color",@"Pen Tip Color",@"BT List",@"Battery Level and Memory Space", @"BT ID", nil];
    }

    [actionSheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
    [actionSheet showFromRect:self.view.bounds inView:self.view animated:YES];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *choice = [actionSheet buttonTitleAtIndex:buttonIndex];
    if (buttonIndex == [actionSheet destructiveButtonIndex]) {

    } else if ([choice isEqualToString:@"Connect"]||[choice isEqualToString:@"Register"]){
            [pencommManager setHandleNewPeripheral:nil];
            [pencommManager setPenPasswordDelegate:self];
            [pencommManager setPenStatusDelegate:self];
            [pencommManager btStart];
            self.btStatus = BT_CONNECTING;
    } else if ([choice isEqualToString:@"Disconnect"]){
            [pencommManager disConnect];
            [pencommManager setPenPasswordDelegate:nil];
            self.btStatus = BT_DISCONNECTED;
    } else if ([choice isEqualToString:@"Pen Unregistration"]){
        
        [pencommManager resetPenRegistration];
        self.btStatus = BT_UNREGISTERED;
    } else if ([choice isEqualToString:@"Setting"]){
        if (_btStatus == BT_CONNECTED) {
            [pencommManager setPenStatusDelegate:self];
            NJPenInfoViewController *penInfoViewController = [[NJPenInfoViewController alloc] initWithNibName:nil bundle:nil];
            [self.navigationController pushViewController:penInfoViewController animated:NO];
        }
        
    } else if ([choice isEqualToString:@"OfflineData list"]){
        if (_btStatus == BT_CONNECTED) {
            UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
            NJOfflineSyncViewController *offlineSyncViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"OffSyncVC"];
            offlineSyncViewController.showOfflineFileList = YES;

            [self.navigationController pushViewController:offlineSyncViewController animated:NO];
        }
        
    } else if ([choice isEqualToString:@"Show OfflineData"]){
        if (_btStatus == BT_CONNECTED) {
            UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
            NJOfflineSyncViewController *offlineSyncViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"OffSyncVC"];
            offlineSyncViewController.showOfflineFileList = NO;
            offlineSyncViewController.parentController = self;
            [self.navigationController pushViewController:offlineSyncViewController animated:NO];
        }
        
    } else if ([choice isEqualToString:@"Pen Firmware Update"]){
        if (_btStatus == BT_CONNECTED) {
            UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
             NJFWUpdateViewController *fwUpdateViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"FWUpdateVC"];
            [self.navigationController pushViewController:fwUpdateViewController animated:NO];
        }
    } else if ([choice isEqualToString:@"Pen Status"]){
        if (_btStatus == BT_CONNECTED) {
            [pencommManager setPenStatusDelegate:self];
            [pencommManager setPenState];
        }
    } else if ([choice isEqualToString:@"Transferable Note ID"]){
        if (_btStatus == BT_CONNECTED) {
            NSUInteger notebookId = 610; NSUInteger sectionId = 3; NSUInteger ownerId = 27;
            [[NPPaperManager sharedInstance] reqAddUsingNote:notebookId section:sectionId owner:ownerId];
            
            [pencommManager setNoteIdListFromPList];
        }
    } else if ([choice isEqualToString:@"Change canvas Color"]){
        if (_btStatus == BT_CONNECTED) {
            _color = [UIColor redColor];
        }
    } else if ([choice isEqualToString:@"Pen Tip Color"]){
        if (_btStatus == BT_CONNECTED) {
            UInt32 penColor = [self convertUIColorToAlpahRGB:[UIColor blueColor]];
            [pencommManager setPenStateWithRGB:penColor];
        }
    } else if ([choice isEqualToString:@"BT List"]){
        [pencommManager setHandleNewPeripheral:self];
        [pencommManager setPenPasswordDelegate:self];
        
        [pencommManager btStartForPeripheralsList];
        
        [self startScanTimer:3.0f];

    } else if ([choice isEqualToString:@"Battery Level and Memory Space"]){
        if (_btStatus == BT_CONNECTED) {
            [self getPenBatteryLevelAndMemoryUsedSpace];
        }
    } else if ([choice isEqualToString:@"BT ID"]){
        NSArray *btIDList = [NSArray arrayWithObjects:@"NWP-F110", @"NWP-F120", nil];
        [pencommManager setBTIDForPenConnection:btIDList];
    }
}

- (void)startScanTimer:(CGFloat)duration
{
    if (!_timer)
    {
        _timer = [NSTimer timerWithTimeInterval:duration
                                         target:self
                                       selector:@selector(discoveredPeripheralsAndConnect)
                                       userInfo:nil
                                        repeats:NO];
        
        [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
    }
}

- (void)stopScanTimer
{
    [_timer invalidate];
    _timer = nil;
}

- (void)discoveredPeripheralsAndConnect
{
    CBPeripheral *foundPeripheral;
    NSString *penName;
    
    [self stopScanTimer];
    NSLog(@"discoveredPeripheralsAndConnect");
    self.discoveredPeripherals = [pencommManager discoveredPeripherals];
    self.macArray = [pencommManager macArray];
    self.serviceIdArray = [pencommManager serviceIdArray];
    if ([self.discoveredPeripherals count] > 0) {
        //example, if index 0 of discoveredPeripherals should be connected
        NSInteger index = 0;
        
        NSString *serviceUUID;
        if ([self.serviceIdArray count] > 0)
            serviceUUID = [self.serviceIdArray objectAtIndex:0];
            
            // 1.try macAddr first
         foundPeripheral = self.discoveredPeripherals[0];
         penName = foundPeripheral.name;
        if ([serviceUUID isEqualToString:@"19F0"] || [serviceUUID isEqualToString:@"19F1"]) {
            pencommManager.isPenSDK2 = YES;
            NSLog(@"Pen SDK2.0");
        } else {
            pencommManager.isPenSDK2 = NO;
            NSLog(@"Pen SDK1.0");
        }
        
        [pencommManager connectPeripheralAt:index];
    }
}

//NJPenCommManagerNewPeripheral
- (void) connectionResult:(BOOL)success
{
    [pencommManager btStop];
    if (success) {
        NSLog(@"Pen connection success");
    } else {
        NSLog(@"Pen connection failure or pen disconnection");
    }
    
}

//NJPenStatusDelegate
- (void) penStatusData:(PenStateStruct *)penStatus
{
    NSLog(@"viewController penstatus");
    NSLog(@"penStatus %d, timezoneOffset %d, timeTick %llu", penStatus->penStatus, penStatus->timezoneOffset, penStatus->timeTick);
    NSLog(@"pressureMax %d, battery %d, memory %d", penStatus->pressureMax, penStatus->battLevel, penStatus->memoryUsed);
    NSLog(@"autoPwrOffTime %d, penPressure %d", penStatus->autoPwrOffTime, penStatus->penPressure);
    
    NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970]*1000;
    NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
    NSInteger millisecondsFromGMT = 1000 * [localTimeZone secondsFromGMT] + [localTimeZone daylightSavingTimeOffset]*1000;
    
    if (pencommManager.isPenSDK2) {
        if ((fabs(penStatus->timeTick - timeInMiliseconds) > 2000)) {
            [pencommManager setPenStateWithTimeTick];
        }
    }else{
        if ((fabs(penStatus->timeTick - timeInMiliseconds) > 2000)
            || (penStatus->timezoneOffset != millisecondsFromGMT)) {
            [pencommManager setPenStateWithTimeTick];
        }
    }
    
    
    BOOL penAutoPower = YES, penSound = YES;
    
    if (pencommManager.isPenSDK2) {
        if (penStatus->usePenTipOnOff == 1) {
            penAutoPower = YES;
        }else if (penStatus->usePenTipOnOff == 0) {
            penAutoPower = NO;
        }
        
        if (penStatus->beepOnOff == 1) {
            penSound = YES;
        }else if (penStatus->beepOnOff == 0) {
            penSound = NO;
        }
    } else {
        if (penStatus->usePenTipOnOff == 1) {
            penAutoPower = YES;
        }else if (penStatus->usePenTipOnOff == 2) {
            penAutoPower = NO;
        }
        
        if (penStatus->beepOnOff == 1) {
            penSound = YES;
        }else if (penStatus->beepOnOff == 2) {
            penSound = NO;
        }
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL savedPenAutoPower = [defaults boolForKey:@"penAutoPower"];
    if (penAutoPower != savedPenAutoPower) {
        [defaults setBool:penAutoPower forKey:@"penAutoPower"];
        [defaults synchronize];
    }
    
    BOOL savedPenSound = [defaults boolForKey:@"penSound"];
    if (penSound != savedPenSound) {
        [defaults setBool:penSound forKey:@"penSound"];
        [defaults synchronize];
    }
    
    NSNumber *penPressure = [NSNumber numberWithInt:penStatus->penPressure];
    NSNumber *savedPenPressure = [defaults objectForKey:@"penPressure"];
    if (![savedPenPressure isEqualToNumber:penPressure]) {
        [defaults setObject:penPressure forKey:@"penPressure"];
        [defaults synchronize];
    }
    
    NSNumber *autoPwrOff = [NSNumber numberWithInt:penStatus->autoPwrOffTime];
    NSNumber *savedAutoPwrOff = [defaults objectForKey:@"autoPwrOff"];
    if (![savedAutoPwrOff isEqualToNumber:autoPwrOff]) {
        [defaults setObject:autoPwrOff forKey:@"autoPwrOff"];
        [defaults synchronize];
    }
    
    if(pencommManager.isPenSDK2){
        if((penStatus -> battLevel & 0x80) == 0x80 ){
            if ((penStatus -> battLevel & 0x7F) == 100) {
                NSLog(@"Battery is fully charged");
            }
            NSLog(@"Battery is being charged");
            return;
        }
    }

}

- (void) getPenBatteryLevelAndMemoryUsedSpace
{
    [pencommManager getPenBattLevelAndMemoryUsedSize:^(unsigned char remainedBattery, unsigned char usedMemory){
        unsigned char battery = remainedBattery;
        unsigned char  memory = 100 - usedMemory;
        
        NSLog(@"Battery Remainder: %d, Unused Memory Space: %d", battery, memory);
    }];
}

//NJPenPasswordDelegate
- (void) penPasswordRequest:(PenPasswordRequestStruct *)request
{
    NSString *password = [MyFunctions loadPasswd];
    int resetCount = (int)request->resetCount;
    int retryCount = (int)request->retryCount;
    int count = resetCount - retryCount;

    if(count <= 1) {
        // last attempt was failed we delete registration and disconnect pen
        [[NJPenCommManager sharedInstance] setBTComparePassword:@"0000"];
        [[NJPenCommManager sharedInstance] resetPenRegistration];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NJPenCommParserPenPasswordValidationFail object:nil userInfo:nil];
        });
        
        return;
    }
    
    if ([password isEqualToString:@""]) {
        password = @"0000";
        [MyFunctions saveIntoKeyChainWithPasswd:password];

        [[NJPenCommManager sharedInstance] setBTComparePassword:password];
    }else{
        if(request->retryCount == 0){
            [[NJPenCommManager sharedInstance] setBTComparePassword:password];
        }else{
            UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
            NJInputPasswordViewController *inputPasswordViewController = [mainStoryboard instantiateViewControllerWithIdentifier:@"inputPWVC"];
            [self presentViewController:inputPasswordViewController animated:YES completion:nil];
        }
    }
    
}

- (void)penPasswordCompareSuccess:(NSNotification *)notification
{
    NSLog(@"setBTComparePassword success");

}

- (UInt32)convertUIColorToAlpahRGB:(UIColor *)color
{
    const CGFloat* components = CGColorGetComponents(color.CGColor);
    NSLog(@"Red: %f", components[0]);
    NSLog(@"Green: %f", components[1]);
    NSLog(@"Blue: %f", components[2]);
    NSLog(@"Alpha: %f", CGColorGetAlpha(color.CGColor));
    
    CGFloat colorRed = components[0];
    CGFloat colorGreen = components[1];
    CGFloat colorBlue = components[2];
    CGFloat colorAlpah = 1.0f;
    UInt32 alpah = (UInt32)(colorAlpah * 255) & 0x000000FF;
    UInt32 red = (UInt32)(colorRed * 255) & 0x000000FF;
    UInt32 green = (UInt32)(colorGreen * 255) & 0x000000FF;
    UInt32 blue = (UInt32)(colorBlue * 255) & 0x000000FF;
    UInt32 penColor = (alpah << 24) | (red << 16) | (green << 8) | blue;
    
    return penColor;
}

//NJPenCommParserStartDelegate
- (void) activeNoteIdForFirstStroke:(int)noteId pageNum:(int)pageNumber sectionId:(int)section ownderId:(int)owner
{
    NSLog(@"noteID:%d, page number:%d, sectionId:%d, ownerId:%d",noteId, pageNumber, section, owner);
    
    self.activeNotebookId = noteId;
    self.activePageNumber = pageNumber;
    
    self.cPage = [[NJPage alloc] initWithNotebookId:noteId andPageNumber:pageNumber];
    
}

- (void) setPenCommNoteIdList
{
    NSUInteger notebookId = 625; NSUInteger sectionId = 3; NSUInteger ownerId = 27;
    [[NPPaperManager sharedInstance] reqAddUsingNote:notebookId section:sectionId owner:ownerId];
    
    //[pencommManager setNoteIdListFromPList];
    [pencommManager setAllNoteIdList];
}

//NJPenCommParserCommandHandler
- (void) findApplicableSymbols:(NSString *)param action:(NSString *)action andName:(NSString *)name
{
    //NSLog(@"param:%@, action:%@, name:%@",param, action, name);
}

- (void)sendEmailWithPdf
{
    
    if ([MFMailComposeViewController canSendMail]) {
        
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        
        mc.mailComposeDelegate = self;
        [mc setSubject:@"iOS SDK sample"];
        [mc setMessageBody:@"<h>Created with <a href='http://www.neosmartpen.com'>Neo smartpen</a> and sent from <a href='http://www.neosmartpen.com'>iOS Sample App</a> </h>" isHTML:YES];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.presentedViewController) {
                [self dismissViewControllerAnimated:YES completion:^{
                    [self presentViewController:mc animated:YES completion:nil];
                }];
            }
        });
    }
}

- (void) penConnectedByOtherApp:(BOOL)penConnected
{
    if (penConnected) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:@"Your pen has been connected by the one of other apps. Please disconnect it from the app and please try again"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}


- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail sent");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            break;
        default:
            break;
    }
    
    [self dismissViewControllerAnimated:YES completion:^{
        self.canvasCloseBtnPressed = YES;
        [NJPenCommManager sharedInstance].penCommParser.shouldSendPageChangeNotification = YES;
    }];
    
}

@end
