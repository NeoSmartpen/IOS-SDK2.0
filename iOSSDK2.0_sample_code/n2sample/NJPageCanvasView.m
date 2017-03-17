//
//  NJPageCanvasView.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJPageCanvasView.h"
#import <NISDK/NISDK.h>
#import "NJPage.h"
#import "NJStroke.h"

#define MAX_NODE 1024

extern NSString * NJPageChangedNotification;
@interface NJPageCanvasView ()
@property (nonatomic) int strokeRenderedIndex;
@end

@implementation NJPageCanvasView
{
    float mX[MAX_NODE], mY[MAX_NODE], mFP[MAX_NODE];
    int mN;
    
    float point_x[MAX_NODE];
    float point_y[MAX_NODE];
    float point_p[MAX_NODE];
    int time_diff[MAX_NODE];
    int point_count;
}
@synthesize location;
@synthesize nodes=_nodes;
@synthesize page = _page;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setMultipleTouchEnabled:NO];
        [self setBackgroundColor:[UIColor whiteColor]];
        self.tempPath = [UIBezierPath bezierPath];
        [self.tempPath setLineWidth:1.2];
        self.pageChanging = YES;
        self.dataUpdating = NO;
        self.scrollView = nil;
        self.screenScale = 1.0f;
        self.penUIColor = [UIColor blackColor];
    }
    return self;
}

- (void) setPage:(NJPage *)page
{
    _page = page;
    _page.bounds = self.bounds;
    self.strokeRenderedIndex = (int)[self.page.strokes count] - 1;
    // pass nil for bgimage. This will generate bg imgage from pdf
    if (!CGSizeEqualToSize(self.bounds.size,CGSizeZero)) {
        self.incrementalImage = [self.page drawPageWithImage:nil size:self.bounds drawBG:YES opaque:YES];
    }
    
    self.pageChanging = NO;
    [self.tempPath removeAllPoints];
    NSLog(@"canvas view page opened");
    [self setNeedsDisplay];
}

- (void) setScrollView:(UIScrollView *)scrollView
{
    _scrollView = scrollView;
    [self.scrollView scrollRectToVisible:CGRectMake(self.frame.origin.x, self.frame.origin.y,
                                                    self.scrollView.frame.size.width,
                                                    self.scrollView.frame.size.height)  animated:NO];
}
- (void) touchBeganX: (float)x_coordinate Y: (float)y_coordinate
{
    CGPoint currentLocation;
    currentLocation.x = x_coordinate * self.page.screenRatio;
    currentLocation.y = y_coordinate * self.page.screenRatio;
    
    point_count = 0;
    point_x[point_count] = currentLocation.x;
    point_y[point_count] = currentLocation.y;
    point_p[point_count] = 50.0f;
    time_diff[point_count] = [[NSDate date] timeIntervalSince1970];
    point_count++;
    
    [self.tempPath moveToPoint:currentLocation];
    
    if (self.scrollView != nil) {
        float start_x = (currentLocation.x * self.screenScale)- self.scrollView.frame.size.width/2.;
        if (start_x < 0.0f) start_x = 0.0f;
        float start_y = (currentLocation.y * self.screenScale) - self.scrollView.frame.size.height/2.;
        if (start_y < 0.0f) start_y = 0.0f;
        //NSLog(@"frame origin x %f, y %f", self.frame.origin.x, self.frame.origin.y);
        [self.scrollView scrollRectToVisible:CGRectMake(start_x + self.frame.origin.x, start_y + self.frame.origin.y,
                                                        self.scrollView.frame.size.width,
                                                        self.scrollView.frame.size.height)  animated:YES];
    }
}

- (void) touchMovedX:(float)x_coordinate Y:(float)y_coordinate{
    
    CGPoint currentLocation;
    currentLocation.x = x_coordinate * self.page.screenRatio;
    currentLocation.y = y_coordinate * self.page.screenRatio;
    
    point_x[point_count] = currentLocation.x;
    point_y[point_count] = currentLocation.y;
    point_p[point_count] = 50.0f;
    time_diff[point_count] = [[NSDate date] timeIntervalSince1970];
    point_count++;
    
    [self.tempPath addLineToPoint:currentLocation];
    [self setNeedsDisplay];
}

- (void)drawRect: (CGRect)rect
{
    if (self.pageChanging || self.dataUpdating) {
        return;
    }
    
    if (self.penUIColor) {
        UIColor *strokeColor = self.penPenColor ? self.penPenColor:self.penUIColor;
        [strokeColor setStroke];
    }
    
    [self.incrementalImage drawInRect:rect];
    [self.tempPath stroke];
}

- (void) strokeUpdated
{
    UInt32 penUIColor = [self convertUIColorToAlpahRGB:self.penUIColor];
    
    NJStroke *stroke = [[NJStroke alloc] initWithRawDataX:point_x Y:point_y pressure:point_p time_diff:time_diff
                                                 penColor:penUIColor penThickness:0 startTime:[[NSDate date] timeIntervalSince1970] size:point_count
                                               normalizer:self.page.inputScale];
    [self.page addStrokes:stroke];

    int lastIndex = (int)[self.page.strokes count] - 1;
    if (self.strokeRenderedIndex >= lastIndex) {
        return;
    }
    for (int i = self.strokeRenderedIndex+1;i <= lastIndex; i++) {
        NJStroke *stroke = [[self.page strokes] objectAtIndex:i];

        self.incrementalImage = [self.page drawStroke:stroke withImage:self.incrementalImage
                                                 size:self.bounds scale:1.0 offsetX:0.0 offsetY:0.0 drawBG:YES opaque:YES];
        NSLog(@"self.incrementalImage:%d", self.incrementalImage? YES:NO);
    }
    self.strokeRenderedIndex = lastIndex;
    [self.tempPath removeAllPoints];
    [self setNeedsDisplay];
}

- (void) drawAllStroke
{
    self.strokeRenderedIndex = (int)[self.page.strokes count] - 1;
    
    UIImage *write_image = [self.page drawPageWithImage:nil size:self.bounds drawBG:YES opaque:YES];
    self.incrementalImage = write_image;
    
    self.pageChanging = NO;
    [self setNeedsDisplay];
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


@end
