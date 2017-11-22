//
//  NJOfflineSyncViewController.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJOfflineSyncViewController.h"
#import <NISDK/NISDK.h>
#import "NJPage.h"
#import "NJStroke.h"
#import "NJPageCanvasController.h"

#define kViewTag			1
#define POINT_COUNT_MAX 1024*STROKE_NUMBER_MAGNITUDE

static NSString *kTitleKey = @"title";
static NSString *kViewKey = @"viewKey";
static NSString *kViewControllerKey = @"viewController";
static NSString *kSwitchCellId = @"SwitchCell";
static NSString *kControlCellId = @"ControlCell";
static NSString *kPauseCellId = @"PauseCell";

NSString * NJOfflineSyncNotebookCompleteNotification = @"NJOfflineSyncNotebookCompleteNotification";

typedef enum {
    OFFLINE_DOT_CHECK_NONE,
    OFFLINE_DOT_CHECK_FIRST,
    OFFLINE_DOT_CHECK_SECOND,
    OFFLINE_DOT_CHECK_THIRD,
    OFFLINE_DOT_CHECK_NORMAL
}OFFLINE_DOT_CHECK_STATE;

@interface NJOfflineSyncViewController () <NJOfflineDataDelegate>
{
    OffLineDataDotStruct offlineDotData0, offlineDotData1, offlineDotData2;
    OffLineData2DotStruct offline2DotData0, offline2DotData1, offline2DotData2;
    OFFLINE_DOT_CHECK_STATE offlineDotCheckState;
}

@property (nonatomic, strong) NSMutableArray *menuList;
@property (nonatomic, strong) UITableViewController *tableViewController;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) NSString *lastUpdated;
@property (nonatomic, strong) CALayer *layer;
@property (nonatomic) float progressValue;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic) UInt32 ownerIdToRequest;
@property (nonatomic) UInt32 noteIdToRequest;
@property (nonatomic, strong) NSNumber *noteId;
@property (nonatomic) BOOL noteChange;
@property (nonatomic, strong) UIButton *pButton;
@property (nonatomic) BOOL pauseBtn;
@property (nonatomic, strong) NSMutableArray *offlineIdList;
@property (nonatomic, strong) NSMutableArray *noteIdList;
@property (nonatomic, strong) NSMutableDictionary *noteDict;
@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic) UInt32 offlinePageId;
@property (strong, nonatomic) NSMutableArray *offlineOverStrokeArray;

@end

@implementation NJOfflineSyncViewController
{
    UInt64 startTime;
    UInt32 offlinePenColor;
    int point_index;
}
@synthesize showOfflineFileList;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;

    self.menuList = [NSMutableArray array];
    self.noteDict = [NSMutableDictionary dictionary];
    
    _offlinePageId = 0;
    _offlineOverStrokeArray = [NSMutableArray array];
    
}

#pragma mark - UIViewController delegate

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.indicator.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height/2);
    self.indicator.hidesWhenStopped = YES;
    [self.view addSubview:self.indicator];
    
    [[NJPenCommManager sharedInstance] setOfflineDataDelegate:self];
    
    NSIndexPath *tableSelection = [self.tableView indexPathForSelectedRow];
    [self.tableView deselectRowAtIndexPath:tableSelection animated:NO];
    
    // Register Listeners for pen notifications
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(nextOfflineNotebook:) name:NJOfflineSyncNotebookCompleteNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[NJPenCommManager sharedInstance] setOfflineDataDelegate:nil];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:NJOfflineSyncNotebookCompleteNotification object:nil];
    
    [super viewWillDisappear:animated];
    
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

-(void) nextOfflineNotebook:(NSNotification *)notification
{
    UInt32 noteIdToRequest = 0;
    UInt32 ownerIdToRequest = 0;
    
    [self.menuList removeObjectAtIndex:0];
    [self.noteDict removeObjectForKey:self.noteId];
    
    if (([self.menuList count] && (self.pauseBtn == NO))) {
        NSNumber *noteId = [self.menuList objectAtIndex:0];
        noteIdToRequest = (UInt32)[noteId unsignedIntegerValue];
        self.noteId = noteId;
        NSNumber *ownerId = [self.noteDict objectForKey:noteId];
        ownerIdToRequest = (UInt32)[ownerId unsignedIntegerValue];
        if(ownerIdToRequest != 0) {
            //from the second notebook
            [[NJPenCommManager sharedInstance] requestOfflineDataWithOwnerId:ownerIdToRequest noteId:noteIdToRequest];
            
        }
        
    }
    [self.tableView reloadData];
    
    if ([self.menuList count] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Offline Sync", @"")
                                                        message:NSLocalizedString(@"Offline Sync Completion", @"")
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                              otherButtonTitles:nil];
        
        [alert show];
        if ([self.noteDict count]) {
            [self.noteDict removeAllObjects];
        }

        [NJPenCommManager sharedInstance].penCommParser.shouldSendPageChangeNotification = YES;
        
        NJPageCanvasController *pageCanvasController = [[NJPageCanvasController alloc] initWithNibName:nil bundle:nil];
        pageCanvasController.offlineSyncViewController = self;
        pageCanvasController.parentController = self.parentController;
        pageCanvasController.canvasPage = self.oPage;
        [self presentViewController:pageCanvasController animated:YES completion:^{
        }];
    }
}

#pragma mark - NJOfflineDataDelegate
// NJOfflineDataDelegate sample implementation
- (void) offlineDataDidReceiveNoteList:(NSDictionary *)noteListDic
{
    BOOL needNext = YES;
    UInt32 ownerIdToRequest = 0;
    UInt32 noteIdToRequest = 0;
    NSEnumerator *enumerator = [noteListDic keyEnumerator];
    
    // Parse NoteListDictionary
    while (needNext) {
        NSNumber *ownerId = [enumerator nextObject];
        if (ownerId == nil) {
            NSLog(@"Offline data : no more owner ID left");
            break;
        }
        if (ownerIdToRequest == 0 || noteIdToRequest == 0) {
            ownerIdToRequest = (UInt32)[ownerId unsignedIntegerValue];
            
        }
        NSLog(@"** Owner Id : %@", ownerId);
        NSArray *noteList = [noteListDic objectForKey:ownerId];
        self.menuList = [noteList mutableCopy];
        for (NSNumber *noteId in noteList) {
            if (noteIdToRequest == 0) {
                noteIdToRequest = (UInt32)[noteId unsignedIntegerValue];
            }
            [self.noteDict setObject:ownerId forKey:noteId];
            NSLog(@"   - Note Id : %@", noteId);
        }
    }
    
    NSArray *keysArray = [self.noteDict allKeys];
    self.menuList = [keysArray mutableCopy];
    NSUInteger count = [self.menuList count];
    if (count) {
        NSNumber *noteId = [self.menuList objectAtIndex:0];
        noteIdToRequest = (UInt32)[noteId unsignedIntegerValue];
        self.noteId = noteId;
        NSNumber *ownerId = [self.noteDict objectForKey:noteId];
        ownerIdToRequest = (UInt32)[ownerId unsignedIntegerValue];
        
    }
    
    if ([self.menuList count]) {
        [self.tableView reloadData];
    }
    //for the only first notebook
    if((ownerIdToRequest != 0) && !showOfflineFileList) {
        [[NJPenCommManager sharedInstance] requestOfflineDataWithOwnerId:ownerIdToRequest noteId:noteIdToRequest];
    }
}

- (void) offlineDataReceiveStatus:(OFFLINE_DATA_STATUS)status percent:(float)percent
{
    NSLog(@"offlineDataReceiveStatus : status %d, percent %f", status, percent);

    [self.indicator startAnimating];
    
    if (status == OFFLINE_DATA_RECEIVE_END) {
        [self.indicator stopAnimating];
        if ([self.menuList count]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NJOfflineSyncNotebookCompleteNotification object:nil userInfo:nil];

        }
        
    }
}

- (void) offlineDataReceivePercent:(float)percent
{
    NSLog(@"offlineDataReceiveStatus : percent %f", percent);
    self.progressView.progress = percent/100.0f;
    
}

- (void)offlineDataDidReceiveNoteListCount:(int)noteCount ForSectionOwnerId:(UInt32)sectionOwnerId
{
    unsigned char section = (sectionOwnerId >> 24) & 0xFF;
    UInt32 ownerId = sectionOwnerId & 0x00FFFFFF;
    
    int offlineDataListNoteCount = noteCount;
    NSLog(@"offline Data Note List Count: %d for sectionId %d, ownerId %d", offlineDataListNoteCount, section, ownerId);
}

- (void)offlineDataPathBeforeParsed:(NSString *)path
{
    NSString *offlineDataPath = path;
    NSLog(@"offline raw data path: %@", offlineDataPath);
}
//SDK1.0
- (BOOL) parseOfflinePenData:(NSData *)penData
{
    int dataPosition = 0;
    unsigned long dataLength = [penData length];
    int headerSize = sizeof(OffLineDataFileHeaderStruct);
    dataLength -= headerSize;
    NSRange range = {dataLength, headerSize};
    OffLineDataFileHeaderStruct header;
    [penData getBytes:&header range:range];
    UInt32 noteId = header.nNoteId;
    UInt32 pageId = header.nPageId;
    UInt32 ownerId = (header.nOwnerId & 0x00FFFFFF);
    UInt32 sectionId = ((header.nOwnerId >> 24) & 0x000000FF);
    NSMutableArray *offlineStrokeArray = [NSMutableArray array];
    
    unsigned char char1, char2;
    OffLineDataStrokeHeaderStruct strokeHeader;
    
    UInt64 offlineLastStrokeStartTime = 0;
    while (dataPosition < dataLength) {
        if ((dataLength - dataPosition) < (sizeof(OffLineDataStrokeHeaderStruct) + 2)) break;
        range.location = dataPosition++;
        range.length = 1;
        [penData getBytes:&char1 range:range];
        range.location = dataPosition++;
        [penData getBytes:&char2 range:range];
        if (char1 == 'L' && char2 == 'N') {
            range.location = dataPosition;
            range.length = sizeof(OffLineDataStrokeHeaderStruct);
            [penData getBytes:&strokeHeader range:range];
            dataPosition += sizeof(OffLineDataStrokeHeaderStruct);
            if ((dataLength - dataPosition) < (strokeHeader.nDotCount * sizeof(OffLineDataDotStruct))) break;
            NJStroke *stroke = [self parseOfflineDots:penData startAt:dataPosition withFileHeader:&header andStrokeHeader:&strokeHeader];
            dataPosition += (strokeHeader.nDotCount * sizeof(OffLineDataDotStruct));
            offlineLastStrokeStartTime = strokeHeader.nStrokeStartTime; // addedby namSSan 2015-03-10
            [offlineStrokeArray addObject:stroke];
        }
    }
    //should check if it is working
    if ((strokeHeader.nDotCount > MAX_NODE_NUMBER) && ([_offlineOverStrokeArray count] > 0)) {
        offlineStrokeArray = [[offlineStrokeArray arrayByAddingObjectsFromArray:_offlineOverStrokeArray] mutableCopy];
        [_offlineOverStrokeArray removeAllObjects];
    }
    NSDate *lastStrokeTime = [NSDate dateWithTimeIntervalSince1970:(offlineLastStrokeStartTime / 1000.0)];

    [self didReceiveOfflineStrokes:offlineStrokeArray forNotebookId:noteId pageNumber:pageId section:sectionId owner:ownerId lastStrokeTime:lastStrokeTime];
    
    return YES;
}
- (void)didReceiveOfflineStrokes:(NSArray<NJStroke *> *)strokes forNotebookId:(NSUInteger)notebookId pageNumber:(NSUInteger)pageNum section:(NSUInteger)section owner:(NSUInteger)owner lastStrokeTime:(NSDate *)time
{
    for(NJStroke *stroke in strokes) {
        [self.oPage addStrokes:stroke];
    }
    
}
- (NJStroke *) parseOfflineDots:(NSData *)penData startAt:(int)position withFileHeader:(OffLineDataFileHeaderStruct *)pFileHeader
                andStrokeHeader:(OffLineDataStrokeHeaderStruct *)pStrokeHeader
{
    OffLineDataDotStruct dot;

    NSRange range = {position, sizeof(OffLineDataDotStruct)};
    int dotCount = MIN(MAX_NODE_NUMBER, pStrokeHeader->nDotCount);
    float *point_x_buff = malloc(sizeof(float)* dotCount);
    float *point_y_buff = malloc(sizeof(float)* dotCount);
    float *point_p_buff = malloc(sizeof(float)* dotCount);
    int *time_diff_buff = malloc(sizeof(int)* dotCount);
    
    if ((point_x_buff == nil) || (point_y_buff == nil) || (point_p_buff == nil) || (time_diff_buff == nil)) return nil;
    
    point_index = 0;
    
    offlineDotCheckState = OFFLINE_DOT_CHECK_FIRST;
    startTime = pStrokeHeader->nStrokeStartTime;
    UInt32 color = pStrokeHeader->nLineColor;
    if (/*(color & 0xFF000000) == 0x01000000 && */(color & 0x00FFFFFF) != 0x00FFFFFF && (color & 0x00FFFFFF) != 0x00000000) {
        offlinePenColor = color | 0xFF000000; // set Alpha to 255
    }
    else
        offlinePenColor = 0;
    
    NSLog(@"offlinePenColor 0x%x", (unsigned int)offlinePenColor);
    
    if (!self.oPage) {
        self.oPage = [[NJPage alloc] initWithNotebookId:pFileHeader->nNoteId andPageNumber:pFileHeader->nPageId];
    }

    for (int i =0; i < pStrokeHeader->nDotCount; i++) {
        [penData getBytes:&dot range:range];
        
        [self dotCheckerForOfflineSync:&dot pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
        if(point_index >= MAX_NODE_NUMBER){
            
            NJStroke *stroke = [[NJStroke alloc] initWithRawDataX:point_x_buff Y:point_y_buff pressure:point_p_buff time_diff:time_diff_buff
                                                         penColor:offlinePenColor penThickness:1 startTime:startTime size:point_index
                                                       normalizer:self.oPage.inputScale];
            [_offlineOverStrokeArray addObject:stroke];
            
            point_index = 0;
            startTime += 1;
        }
        position += sizeof(OffLineDataDotStruct);
        range.location = position;
    }
    [self offlineDotCheckerLastPointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];

    NJStroke *stroke = [[NJStroke alloc] initWithRawDataX:point_x_buff Y:point_y_buff pressure:point_p_buff time_diff:time_diff_buff
                                                 penColor:offlinePenColor penThickness:1 startTime:startTime size:point_index
                                               normalizer:self.oPage.inputScale];
    point_index = 0;
    
    if (point_x_buff)
        free(point_x_buff);
    
    if (point_y_buff)
        free(point_y_buff);
    
    if (point_p_buff)
        free(point_p_buff);
    
    if (time_diff_buff)
        free(time_diff_buff);
    
    return stroke;
}

//SDK2.0
- (BOOL) parseSDK2OfflinePenData:(NSData *)penData AndOfflineDataHeader:(OffLineData2HeaderStruct* )offlineDataHeader
{
    UInt32 pageId = 0;
    UInt32 noteId = offlineDataHeader->nNoteId;
    UInt32 ownerId = (offlineDataHeader->nSectionOwnerId & 0x00FFFFFF);
    UInt32 sectionId = ((offlineDataHeader->nSectionOwnerId >> 24) & 0x000000FF);
    NSMutableDictionary *offlineDataDic = [[NSMutableDictionary alloc] init];

    int dataPosition=0;
    unsigned long dataLength = [penData length];
    NSRange range;
    NSMutableArray *offlineStrokeArray = [NSMutableArray array];
    NSDate *lastStrokeTime;
    _offlinePageId = 0;
    
    OffLineData2StrokeHeaderStruct strokeHeader;
    UInt64 offlineLastStrokeStartTime = 0;
    
    while (dataPosition < dataLength) {
        if ((dataLength - dataPosition) < (sizeof(OffLineData2StrokeHeaderStruct) + 2)) break;
        range.location = dataPosition;
        range.length = sizeof(OffLineData2StrokeHeaderStruct);
        [penData getBytes:&strokeHeader range:range];
        dataPosition += sizeof(OffLineData2StrokeHeaderStruct);
        if ((dataLength - dataPosition) < (strokeHeader.nDotCount * sizeof(OffLineData2DotStruct))) {
            break;
        }
        pageId = strokeHeader.nPageId;
        
        if((_offlinePageId != 0) && (_offlinePageId != pageId) && ([offlineStrokeArray count] > 0))
        {
            NSNumber *pageIdNum = [NSNumber numberWithUnsignedInteger:_offlinePageId];
            lastStrokeTime = [NSDate dateWithTimeIntervalSince1970:(offlineLastStrokeStartTime / 1000.0)];
            NSMutableArray *offlineStrokeArrayTemp = [offlineStrokeArray mutableCopy];
            NSDictionary *offlineDataDicForPageId = [NSDictionary dictionaryWithObjectsAndKeys:
                                                     offlineStrokeArrayTemp, @"stroke",
                                                     lastStrokeTime, @"time",
                                                     nil];
            [offlineDataDic setObject:offlineDataDicForPageId forKey:pageIdNum];
            
            [offlineStrokeArray removeAllObjects];
            _offlinePageId = pageId;
            
        } else {
            _offlinePageId = pageId;
        }
        NJStroke *stroke = [self parseSDK2OfflineDots:penData startAt:dataPosition withOfflineDataHeader:offlineDataHeader andStrokeHeader:&strokeHeader];
        [offlineStrokeArray addObject:stroke];
        
        dataPosition += (strokeHeader.nDotCount * sizeof(OffLineData2DotStruct));
        offlineLastStrokeStartTime = strokeHeader.nStrokeStartTime;
        
        if ((strokeHeader.nDotCount > MAX_NODE_NUMBER) && ([_offlineOverStrokeArray count] > 0)) {
            offlineStrokeArray = [[offlineStrokeArray arrayByAddingObjectsFromArray:_offlineOverStrokeArray] mutableCopy];
            [_offlineOverStrokeArray removeAllObjects];
        }
    }
    
    if ([offlineStrokeArray count] > 0) {
        NSNumber *pageIdNum = [NSNumber numberWithUnsignedInteger:pageId];
        lastStrokeTime = [NSDate dateWithTimeIntervalSince1970:(offlineLastStrokeStartTime / 1000.0)];
        NSMutableArray *offlineStrokeArrayTemp = [offlineStrokeArray mutableCopy];
        NSDictionary *offlineDataDicForPageId = [NSDictionary dictionaryWithObjectsAndKeys:
                                                 offlineStrokeArrayTemp, @"stroke",
                                                 lastStrokeTime, @"time",
                                                 nil];
        [offlineDataDic setObject:offlineDataDicForPageId forKey:pageIdNum];
        
        [offlineStrokeArray removeAllObjects];
    }
    
    NSEnumerator *enumerator = [offlineDataDic keyEnumerator];
    
    while (YES) {
        NSNumber *page_Id = [enumerator nextObject];
        if (page_Id == nil) {
            NSLog(@"Offline data : no more page_Id left");
            break;
        }
        NSLog(@"** pageId: %@", page_Id);
        NSDictionary *offlineDataDicForPageId = [offlineDataDic objectForKey:page_Id];
        UInt32 pageId = (UInt32)[page_Id unsignedIntegerValue];
        NSMutableArray *offlineStrokeArrayTemp = [offlineDataDicForPageId objectForKey:@"stroke"];
        NSDate *lastStrokeTimeTemp = [offlineDataDicForPageId objectForKey:@"time"];
        [self didReceiveOfflineStrokes:offlineStrokeArrayTemp forNotebookId:noteId pageNumber:pageId section:sectionId owner:ownerId lastStrokeTime:lastStrokeTimeTemp];
    }
    
    return YES;
}

- (NJStroke *) parseSDK2OfflineDots:(NSData *)penData startAt:(int)position withOfflineDataHeader:(OffLineData2HeaderStruct *)pFileHeader
                    andStrokeHeader:(OffLineData2StrokeHeaderStruct *)pStrokeHeader
{
    OffLineData2DotStruct dot;
    //    float pressure, x, y;
    NSRange range = {position, sizeof(OffLineData2DotStruct)};
    int dotCount = MIN(MAX_NODE_NUMBER, (pStrokeHeader->nDotCount));
    float *point_x_buff = malloc(sizeof(float)* dotCount);
    float *point_y_buff = malloc(sizeof(float)* dotCount);
    float *point_p_buff = malloc(sizeof(float)* dotCount);
    int *time_diff_buff = malloc(sizeof(int)* dotCount);
    
    if ((point_x_buff == nil) || (point_y_buff == nil) || (point_p_buff == nil) || (time_diff_buff == nil)) return nil;
    
    point_index = 0;
    offlineDotCheckState = OFFLINE_DOT_CHECK_FIRST;
    startTime = pStrokeHeader->nStrokeStartTime;
    //    NSLog(@"offline time %llu", startTime);
    UInt32 color = pStrokeHeader->nLineColor;
    if (/*(color & 0xFF000000) == 0x01000000 && */(color & 0x00FFFFFF) != 0x00FFFFFF && (color & 0x00FFFFFF) != 0x00000000) {
        offlinePenColor = color | 0xFF000000; // set Alpha to 255
    }
    else
        offlinePenColor = 0;

    if (!self.oPage) {
        self.oPage = [[NJPage alloc] initWithNotebookId:pFileHeader->nNoteId andPageNumber:pStrokeHeader->nPageId];
    }
    
    for (int i =0; i < pStrokeHeader->nDotCount; i++) {
        [penData getBytes:&dot range:range];
        
        [self dotCheckerForOfflineSync2:&dot pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
        
        if(point_index >= MAX_NODE_NUMBER){
            
            NJStroke *stroke = [[NJStroke alloc] initWithRawDataX:point_x_buff Y:point_y_buff pressure:point_p_buff time_diff:time_diff_buff
                                                         penColor:offlinePenColor penThickness:1 startTime:startTime size:point_index];

            [_offlineOverStrokeArray addObject:stroke];
            
            point_index = 0;
            startTime += 1;
        }
        position += sizeof(OffLineData2DotStruct);
        range.location = position;
    }
    [self offlineDotCheckerLastPointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
    
    NJStroke *stroke = [[NJStroke alloc] initWithRawDataX:point_x_buff Y:point_y_buff pressure:point_p_buff time_diff:time_diff_buff
                                                 penColor:offlinePenColor penThickness:1 startTime:startTime size:point_index];

    point_index = 0;
    
    if (point_x_buff)
        free(point_x_buff);
    
    if (point_y_buff)
        free(point_y_buff);
    
    if (point_p_buff)
        free(point_p_buff);
    
    if (time_diff_buff)
        free(time_diff_buff);
    
    return stroke;
}

//SDK1.0
- (void) dotCheckerForOfflineSync:(OffLineDataDotStruct *)aDot pointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    if (offlineDotCheckState == OFFLINE_DOT_CHECK_NORMAL) {
        if ([self offlineDotCheckerForMiddle:aDot]) {
            [self offlineDotAppend:&offlineDotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
            offlineDotData0 = offlineDotData1;
            offlineDotData1 = offlineDotData2;
        }
        else {
            NSLog(@"offlineDotChecker error : middle");
        }
        offlineDotData2 = *aDot;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_FIRST) {
        offlineDotData0 = *aDot;
        offlineDotData1 = *aDot;
        offlineDotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_SECOND;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_SECOND) {
        offlineDotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_THIRD;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_THIRD) {
        if ([self offlineDotCheckerForStart:aDot]) {
            [self offlineDotAppend:&offlineDotData1 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
            if ([self offlineDotCheckerForMiddle:aDot]) {
                [self offlineDotAppend:&offlineDotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
                offlineDotData0 = offlineDotData1;
                offlineDotData1 = offlineDotData2;
            }
            else {
                NSLog(@"offlineDotChecker error : middle2");
            }
        }
        else {
            offlineDotData1 = offlineDotData2;
            NSLog(@"offlineDotChecker error : start");
        }
        offlineDotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_NORMAL;
    }
}

- (void) offlineDotAppend:(OffLineDataDotStruct *)dot pointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    float pressure, x, y;
    
    x = (float)dot->x + (float)dot->fx * 0.01f;
    y = (float)dot->y + (float)dot->fy * 0.01f;
    pressure = [[NJPenCommManager sharedInstance] processPressure:(float)dot->force];
    point_x_buff[point_index] = x - self.oPage.startX;//*self.oPage.screenRatio;
    point_y_buff[point_index] = y - self.oPage.startY;//*self.oPage.screenRatio;
    point_p_buff[point_index] = pressure;
    time_diff_buff[point_index] = dot->nTimeDelta;
    point_index++;
}

- (BOOL) offlineDotCheckerForStart:(OffLineDataDotStruct *)aDot
{
    static const float delta = 10.0f;
    if (offlineDotData1.x > 150 || offlineDotData1.x < 1) return NO;
    if (offlineDotData1.y > 150 || offlineDotData1.y < 1) return NO;
    if ((aDot->x - offlineDotData1.x) * (offlineDotData2.x - offlineDotData1.x) > 0
        && ABS(aDot->x - offlineDotData1.x) > delta && ABS(offlineDotData1.x - offlineDotData2.x) > delta)
    {
        return NO;
    }
    if ((aDot->y - offlineDotData1.y) * (offlineDotData2.y - offlineDotData1.y) > 0
        && ABS(aDot->y - offlineDotData1.y) > delta && ABS(offlineDotData1.y - offlineDotData2.y) > delta)
    {
        return NO;
    }
    return YES;
}
- (BOOL) offlineDotCheckerForMiddle:(OffLineDataDotStruct *)aDot
{
    static const float delta = 10.0f;
    if (offlineDotData2.x > 150 || offlineDotData2.x < 1) return NO;
    if (offlineDotData2.y > 150 || offlineDotData2.y < 1) return NO;
    if ((offlineDotData1.x - offlineDotData2.x) * (aDot->x - offlineDotData2.x) > 0
        && ABS(offlineDotData1.x - offlineDotData2.x) > delta && ABS(aDot->x - offlineDotData2.x) > delta)
    {
        return NO;
    }
    if ((offlineDotData1.y - offlineDotData2.y) * (aDot->y - offlineDotData2.y) > 0
        && ABS(offlineDotData1.y - offlineDotData2.y) > delta && ABS(aDot->y - offlineDotData2.y) > delta)
    {
        return NO;
    }
    
    return YES;
}
- (BOOL) offlineDotCheckerForEnd
{
    static const float delta = 10.0f;
    if (offlineDotData2.x > 150 || offlineDotData2.x < 1) return NO;
    if (offlineDotData2.y > 150 || offlineDotData2.y < 1) return NO;
    if ((offlineDotData2.x - offlineDotData0.x) * (offlineDotData2.x - offlineDotData1.x) > 0
        && ABS(offlineDotData2.x - offlineDotData0.x) > delta && ABS(offlineDotData2.x - offlineDotData1.x) > delta)
    {
        return NO;
    }
    if ((offlineDotData2.y - offlineDotData0.y) * (offlineDotData2.y - offlineDotData1.y) > 0
        && ABS(offlineDotData2.y - offlineDotData0.y) > delta && ABS(offlineDotData2.y - offlineDotData1.y) > delta)
    {
        return NO;
    }
    return YES;
}

- (void) offlineDotCheckerLastPointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    if ([self offlineDotCheckerForEnd]) {
        [self offlineDotAppend:&offlineDotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
        offlineDotData2.x = 0.0f;
        offlineDotData2.y = 0.0f;
    }
    else {
        NSLog(@"offlineDotChecker error : end");
    }
    offlineDotCheckState = OFFLINE_DOT_CHECK_NONE;
}

//////////////////////////////////////////////////////////////////
//
//
//            Offline Dot Checker
//
//////////////////////////////////////////////////////////////////
//SDK2.0
- (void) dotCheckerForOfflineSync2:(OffLineData2DotStruct *)aDot pointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    if (offlineDotCheckState == OFFLINE_DOT_CHECK_NORMAL) {
        if ([self offline2DotCheckerForMiddle:aDot]) {
            [self offline2DotAppend:&offline2DotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
            offline2DotData0 = offline2DotData1;
            offline2DotData1 = offline2DotData2;
        }
        else {
            NSLog(@"offlineDotChecker error : middle");
        }
        offline2DotData2 = *aDot;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_FIRST) {
        offline2DotData0 = *aDot;
        offline2DotData1 = *aDot;
        offline2DotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_SECOND;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_SECOND) {
        offline2DotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_THIRD;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_THIRD) {
        if ([self offline2DotCheckerForStart:aDot]) {
            [self offline2DotAppend:&offline2DotData1 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
            if ([self offline2DotCheckerForMiddle:aDot]) {
                [self offline2DotAppend:&offline2DotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
                offline2DotData0 = offline2DotData1;
                offline2DotData1 = offline2DotData2;
            }
            else {
                NSLog(@"offlineDotChecker error : middle2");
            }
        }
        else {
            offline2DotData1 = offline2DotData2;
            NSLog(@"offlineDotChecker error : start");
        }
        offline2DotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_NORMAL;
    }
}

- (void) offline2DotAppend:(OffLineData2DotStruct *)dot pointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    float pressure, x, y;
    
    x = (float)dot->x + (float)dot->fx * 0.01f;
    y = (float)dot->y + (float)dot->fy * 0.01f;
    
    pressure = [[NJPenCommManager sharedInstance] processPressure:(float)dot->force];
    
    point_x_buff[point_index] = x - self.oPage.startX;
    point_y_buff[point_index] = y - self.oPage.startY;
    point_p_buff[point_index] = pressure;
    time_diff_buff[point_index] = dot->nTimeDelta;
    point_index++;
}

- (BOOL) offline2DotCheckerForStart:(OffLineData2DotStruct *)aDot
{
    static const float delta = 10.0f;
    if (offline2DotData1.x > 150 || offline2DotData1.x < 1) return NO;
    if (offline2DotData1.y > 150 || offline2DotData1.y < 1) return NO;
    if ((aDot->x - offline2DotData1.x) * (offline2DotData2.x - offline2DotData1.x) > 0
        && ABS(aDot->x - offline2DotData1.x) > delta && ABS(offline2DotData1.x - offline2DotData2.x) > delta)
    {
        return NO;
    }
    if ((aDot->y - offline2DotData1.y) * (offline2DotData2.y - offline2DotData1.y) > 0
        && ABS(aDot->y - offline2DotData1.y) > delta && ABS(offline2DotData1.y - offline2DotData2.y) > delta)
    {
        return NO;
    }
    return YES;
}
- (BOOL) offline2DotCheckerForMiddle:(OffLineData2DotStruct *)aDot
{
    static const float delta = 10.0f;
    if (offline2DotData2.x > 150 || offline2DotData2.x < 1) return NO;
    if (offline2DotData2.y > 150 || offline2DotData2.y < 1) return NO;
    if ((offline2DotData1.x - offline2DotData2.x) * (aDot->x - offline2DotData2.x) > 0
        && ABS(offline2DotData1.x - offline2DotData2.x) > delta && ABS(aDot->x - offline2DotData2.x) > delta)
    {
        return NO;
    }
    if ((offline2DotData1.y - offline2DotData2.y) * (aDot->y - offline2DotData2.y) > 0
        && ABS(offline2DotData1.y - offline2DotData2.y) > delta && ABS(aDot->y - offline2DotData2.y) > delta)
    {
        return NO;
    }
    
    return YES;
}
- (BOOL) offline2DotCheckerForEnd
{
    static const float delta = 10.0f;
    if (offline2DotData2.x > 150 || offline2DotData2.x < 1) return NO;
    if (offline2DotData2.y > 150 || offline2DotData2.y < 1) return NO;
    if ((offline2DotData2.x - offline2DotData0.x) * (offline2DotData2.x - offline2DotData1.x) > 0
        && ABS(offline2DotData2.x - offline2DotData0.x) > delta && ABS(offline2DotData2.x - offline2DotData1.x) > delta)
    {
        return NO;
    }
    if ((offline2DotData2.y - offline2DotData0.y) * (offline2DotData2.y - offline2DotData1.y) > 0
        && ABS(offline2DotData2.y - offline2DotData0.y) > delta && ABS(offline2DotData2.y - offline2DotData1.y) > delta)
    {
        return NO;
    }
    return YES;
}

- (void) offline2DotCheckerLastPointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    if ([self offline2DotCheckerForEnd]) {
        [self offline2DotAppend:&offline2DotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
        offline2DotData2.x = 0.0f;
        offline2DotData2.y = 0.0f;
    }
    else {
        NSLog(@"offlineDotChecker error : end");
    }
    offlineDotCheckState = OFFLINE_DOT_CHECK_NONE;
}

#pragma mark - UITableViewDelegate

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.menuList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *kOffSyncTableCell = @"UITableViewCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kOffSyncTableCell];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kOffSyncTableCell];
    }
    
    NSUInteger noteId = [[self.menuList objectAtIndex:indexPath.row] integerValue];
    cell.textLabel.text = [self noteTitle:noteId];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.backgroundColor = [UIColor clearColor];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    cell.textLabel.opaque = NO;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55.0;
}

- (NSString *) noteTitle:(NSInteger)type
{
    NSString *notebookTitle;
    
    switch (type) {
        case 601:
            notebookTitle = @"Pocket Note";
            break;
        case 602:
            notebookTitle = @"Memo Note";
            break;
        case 603:
            notebookTitle = @"Spring Note";
            break;
        case 605:
            notebookTitle = @"FP Memo Pad";
            break;
        default:
            notebookTitle = @"Unknown Note";
            break;
    }
    return notebookTitle;
}


@end

