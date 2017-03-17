//
//  NJPageCanvasController.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJPageCanvasController.h"
#import "NJPageCanvasView.h"
#import "NJAppDelegate.h"
#import <NISDK/NISDK.h>
#import "NJOfflineSyncViewController.h"
#import "NJViewController.h"
#import "NJPage.h"

@interface NJPageCanvasController ()<NJPenCommParserStrokeHandler, UIActionSheetDelegate, UIPopoverControllerDelegate,UIScrollViewDelegate>
@property (strong, nonatomic) NJPageCanvasView *pageCanvas;
@property (strong, nonatomic) UIBarButtonItem *advertizeBarButton;
@property (strong, nonatomic) NSMutableArray *discoveredPeripherals;
@property (strong, nonatomic) NJPenCommManager * pencommManager;
@property (strong, nonatomic) UIButton *button;
@property (nonatomic, strong) UIImageView *menuAniButtonView;
@property (nonatomic, strong) CALayer *layer;
@property (nonatomic, strong) NSTimer *stopTimer;
@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic) BOOL menuBtnToggle;
@property (strong, nonatomic) UIView* lineView;
@property (nonatomic) BOOL firstEntry;
@property (strong, nonatomic) UIScrollView *scrollView;
@end

@implementation NJPageCanvasController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];     
    self.view.layer.cornerRadius = 5;
    self.view.layer.masksToBounds = YES;
    self.navigationController.navigationBar.layer.mask = [self roundedCornerNavigationBar];
    
    self.pencommManager = [NJPenCommManager sharedInstance];
 
    [self.view setBackgroundColor:[UIColor colorWithWhite:0.95f alpha:1]];
    
    self.pageCanvas = [[NJPageCanvasView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,0,self.view.frame.size.width,self.view.frame.size.height)];
    
    self.scrollView.contentSize = self.pageCanvas.bounds.size;
    self.view = self.scrollView;
    
    [self.scrollView setBackgroundColor:[UIColor colorWithWhite:0.95f alpha:1]];
    
    [self.view addSubview:self.pageCanvas];
    self.pageCanvas.scrollView = self.scrollView;    
 
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeBtn setFrame:CGRectMake(0, 0, 46, 44)];
    [closeBtn setBackgroundImage:[UIImage imageNamed:@"btn_back.png"] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
    
    _startDate = [NSDate date];
    
    _firstEntry = YES;
    
    self.scrollView.minimumZoomScale=1.0;
    self.scrollView.maximumZoomScale=6.0;
    self.scrollView.pagingEnabled = YES;
    self.scrollView.delegate=self;
    self.scrollView.userInteractionEnabled = YES;
    
    UIPanGestureRecognizer *singleFingerTap = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                      action:@selector(handleSingleTap:)];
    [self.scrollView addGestureRecognizer:singleFingerTap];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //disable phone sleep mode
    [UIApplication sharedApplication].idleTimerDisabled = YES;
   
    if (self.offlineSyncViewController) {
        self.pageCanvas.page = self.canvasPage;
        [self adjustCanvasView];
        [self.pageCanvas drawAllStroke];
        self.offlineSyncViewController = nil;
        
    }else{
        [[NJPenCommManager sharedInstance] setPenCommParserStrokeHandler:self];
        
        [[NJPenCommManager sharedInstance] setPenCommParserStartDelegate:nil];

        if (self.canvasPage) {
            self.pageCanvas.page = self.canvasPage;
        } else {
            NJPage *page = [[NJPage alloc] initWithNotebookId:(int)self.activeNotebookId andPageNumber:(int)self.activePageNumber];
            self.pageCanvas.page = page;
        }
        
        [self adjustCanvasView];

    }
    if (self.penColor) {
        self.pageCanvas.penUIColor = [self convertUIColorFromIntColor:self.penColor];
    }
}

- (void) viewWillDisappear:(BOOL)animated
{
    
    
    //disable phone sleep mode
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    [[NJPenCommManager sharedInstance] setPenCommParserStrokeHandler:nil];
    
    [_lineView removeFromSuperview];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)adjustCanvasView
{
    
    CGRect frame = self.view.frame;
    CGSize paperSize=self.pageCanvas.page.paperSize;
    
    if (CGSizeEqualToSize(paperSize,CGSizeZero)) {
        NSLog(@"paperSize == 0");
    }
 
    float xRatio=frame.size.width/paperSize.width;
    float yRatio=frame.size.height/paperSize.height;
    float ratio = MIN(yRatio, xRatio);
    self.pageCanvas.page.screenRatio = ratio;
    float xSize=ratio*paperSize.width;
    float ySize=ratio*paperSize.height;
    
    float xMargin = (frame.size.width - xSize)/2;
    float yMargin = (frame.size.height - ySize)/2;
    CGPoint canvasPoint={(frame.origin.x + xMargin), (frame.origin.y + yMargin)};
    CGSize canvasSize={xSize, ySize};
    CGRect canvasFrame={canvasPoint, canvasSize};
    if (self.pageCanvas == nil) {
        self.pageCanvas = [[NJPageCanvasView alloc] initWithFrame:canvasFrame];
        [self.view addSubview:self.pageCanvas];
    }
    else
        self.pageCanvas.frame = canvasFrame;
    
    self.pageCanvas.backgroundColor=[UIColor colorWithWhite:0.95f alpha:1];
    
    _lineView = [[UIView alloc] initWithFrame:CGRectMake(0, frame.origin.y + yMargin, 320, 0.5)];
    _lineView.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:_lineView];
}

- (void) activeNoteId:(int)noteId pageNum:(int)pageNumber sectionId:(int)section ownderId:(int)owner
{
    NSLog(@"noteID:%d, page number:%d, section Id:%d, owner Id:%d",noteId,pageNumber,section,owner);
    
    if ((self.activeNotebookId != noteId) || (self.activePageNumber != pageNumber)) {
        self.activeNotebookId = noteId;
        self.activePageNumber = pageNumber;
        self.pageCanvas.page = [[NJPage alloc] initWithNotebookId:noteId andPageNumber:pageNumber];
        [self adjustCanvasView];
        [self.view setNeedsDisplay];
    }
    
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer
{
    NSLog(@"single tap detected...");
}

#pragma mark - NJPenCommParserStrokeHandler
- (void) processStroke:(NSDictionary *)stroke
{
    static BOOL penDown = NO;
    static BOOL startNode = NO;


    NSString *type = [stroke objectForKey:@"type"];
    
    if ([type isEqualToString: @"stroke"]) {
        if (_firstEntry) {
            penDown = YES;
            startNode = YES;
            _firstEntry = NO;
        }
        if (penDown == NO) return;
        
        NJNode *node = [stroke objectForKey:@"node"];
        float x = node.x;
        float y = node.y;
        NSLog(@"processStroke X %f, Y %f, startX %f, startY %f", x, y,self.pageCanvas.page.paperInfo.startX, self.pageCanvas.page.paperInfo.startY);
        
        if (startNode == NO) {
            [self.pageCanvas touchMovedX: x Y: y];
        } else {
            [self.pageCanvas touchBeganX: x Y: y];
            startNode = NO;
        }
        
        [self findApplicableSymbolsX:x andY:y];
        
    } else if ([type isEqualToString: @"updown"]) {
        
        NSString *status = [stroke objectForKey:@"status"];
        
        if ([status isEqualToString:@"down"]) {
            
            penDown = YES;
            startNode = YES;
            
        } else {
            
            penDown = NO;
            [self.pageCanvas strokeUpdated];
        }
    }
}

- (void)findApplicableSymbolsX:(float)x andY:(float)y
{
    if(isEmpty(self.pageCanvas.page.paperInfo)) return;

    BOOL found = NO;
    PUICmdType cmdType = PUICmdTypeNone;
    NPPUIInfo *pui = nil;
    NPPaperInfo *paperInfo = self.pageCanvas.page.paperInfo;
    x = x + paperInfo.startX;
    y = y + paperInfo.startY;
    
    for(pui in paperInfo.puiArray) {
        CGFloat padding = 0.0f;
        if((pui.width > 5.0f) && (pui.height > 5.0f))
            padding = MIN(pui.width,pui.height) * 0.1;
        
        if(x < (pui.startX + padding)) continue;
        if(y < (pui.startY + padding)) continue;
        if(x > (pui.startX + pui.width - padding)) continue;
        if(y > (pui.startY + pui.height - padding)) continue;
        
        found = YES;
        cmdType = pui.cmdType;
        break;
    }
    if(cmdType == PUICmdTypeNone) return;
    
    NSLog(@"param:%@, action:%@, name:%@",pui.param, pui.action, pui.name);
    NSLog(@"Symbol X %f, Y %f, startX %f, startY %f", x, y,paperInfo.startX, paperInfo.startY);
  
}

- (void)notifyPageChanging
{
    self.pageCanvas.pageChanging = YES;
}

- (void)notifyDataUpdating:(BOOL)updating
{

}

- (void)closeBtnPressed
{
    [[NJPenCommManager sharedInstance] requestNewPageNotification];
    [self dismissViewControllerAnimated:YES completion:^{
        self.parentController.canvasCloseBtnPressed = YES;
    }];
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

- (void)didColorChanged:(UIColor *)color
{
    if(color){
        NSLog(@"color ===> %@",color);
        self.penColor = [self convertUIColorToAlpahRGB:color];
        self.pageCanvas.penUIColor = color;

        NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
        [[NSUserDefaults standardUserDefaults] setObject:colorData forKey:@"penColor"];
        [[NJPenCommManager sharedInstance] setPenStateWithRGB:_penColor];
    }
    
}


- (void)didThicknessChanged:(NSUInteger)thickness
{
    // line thickness changed...
    // value between 1~3 levels;
    NSLog(@"line thickness --> %d",(int)thickness);
    
}


- (UInt32)setPenColor
{
    UInt32 colorRed = 0.2f;
    UInt32 colorGreen = 0.2f;
    UInt32 colorBlue = 0.2f;
    UInt32 colorAlpah = 1.0f;
    UInt32 alpah = (UInt32)(colorAlpah * 255) & 0x000000FF;
    UInt32 red = (UInt32)(colorRed * 255) & 0x000000FF;
    UInt32 green = (UInt32)(colorGreen * 255) & 0x000000FF;
    UInt32 blue = (UInt32)(colorBlue * 255) & 0x000000FF;
    UInt32 color = (alpah << 24) | (red << 16) | (green << 8) | blue;
    
    if (self.penColor) {
        color = self.penColor;
    }
    return color;
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

- (UIColor *)convertUIColorFromIntColor:(UInt32)intColor
{
    float colorA = (intColor>>24)/255.0f;
    float colorR = ((intColor>>16)&0x000000FF)/255.0f;
    float colorG = ((intColor>>8)&0x000000FF)/255.0f;
    float colorB = (intColor&0x000000FF)/255.0f;
    
    return [[UIColor alloc] initWithRed:colorR green:colorG blue:colorB alpha:colorA];
}

/***********************************************************************
 //
 //  UIScrollView delegate callback, called when the user starts zooming
 //
 //
 //
 ***********************************************************************/
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.pageCanvas;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view
{
    
    for (UIGestureRecognizer *gestureRecognizer in self.scrollView.gestureRecognizers) {
        if ([gestureRecognizer  isKindOfClass:[UIPanGestureRecognizer class]]) {
            UIPanGestureRecognizer *panGR = (UIPanGestureRecognizer *) gestureRecognizer;
            panGR.minimumNumberOfTouches = 1;
        }
    }
    
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale
{
    
    self.pageCanvas.screenScale = scale;
    
    
    if (scale == 1.0f) {
        
        self.scrollView.contentSize = self.pageCanvas.bounds.size;
    }
    
}
@end
