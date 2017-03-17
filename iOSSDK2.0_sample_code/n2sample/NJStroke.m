//
//  NJStroke.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJStroke.h"
#import <NISDK/NISDK.h>

#define MAX_NODE_NUMBER 1024

@interface NJStroke(){
    float colorRed, colorGreen, colorBlue, colorAlpah;
}
@property (strong, nonatomic) UIBezierPath *renderingPath;
@end
@implementation NJStroke
- (instancetype) init
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
     _penThickness = 0;
    return self;
}
- (instancetype) initWithRawDataX:(float *)x Y:(float*)y pressure:(float *)p time_diff:(int *)time
                         penColor:(UInt32)penColor penThickness:(NSUInteger)thickness startTime:(UInt64)start_at size:(int)size
{
    self = [self init];
    if (!self) return nil;
    int time_lapse = 0;
    int i = 0;
    if (size < 3) {
        //We nee at least 3 point to render.
        //Warning!! I'm assume x, y, p are c style arrays that have at least 3 spaces.
        for (i = size; i < 3; i++) {
            x[i] = x[size -1];
            y[i] = y[size -1];
            p[i] = p[size -1];
            time[i]=0;
        }
        size = 3;
    }
    _dataCount = size;
    point_x = (float *)malloc(sizeof(float) * size);
    point_y = (float *)malloc(sizeof(float) * size);
    point_p = (float *)malloc(sizeof(float) * size);
    time_stamp = (UInt64 *)malloc(sizeof(UInt64) * size);
    start_time = start_at;

    _penThickness = thickness - 1;
    memcpy(point_x, x, sizeof(float) * size);
    memcpy(point_y, y, sizeof(float) * size);
    memcpy(point_p, p, sizeof(float) * size);
    for (i=0; i<size; i++) {
        time_lapse += time[i];
        time_stamp[i] = start_at + time_lapse;
    }
    
    _inputScale = 1;
    if (penColor == 0) {
        [self initColor];
    }
    else {
        self.penColor = penColor;
    }
    return self;
}
- (instancetype) initWithRawDataX:(float *)x Y:(float*)y pressure:(float *)p time_diff:(int *)time
                                penColor:(UInt32)penColor penThickness:(NSUInteger)thickness startTime:(UInt64)start_at size:(int)size normalizer:(float)inputScale
{
    self = [self init];
    if (!self) return nil;
    int time_lapse = 0;
    int i = 0;
    if (size < 3) {
        //We nee at least 3 point to render.
        //Warning!! I'm assume x, y, p are c style arrays that have at least 3 spaces.
        for (i = size; i < 3; i++) {
            x[i] = x[size -1];
            y[i] = y[size -1];
            p[i] = p[size -1];
            time[i]=0;
        }
        size = 3;
    }
    _dataCount = size;
    point_x = (float *)malloc(sizeof(float) * size);
    point_y = (float *)malloc(sizeof(float) * size);
    point_p = (float *)malloc(sizeof(float) * size);
    time_stamp = (UInt64 *)malloc(sizeof(UInt64) * size);
    start_time = start_at;

    _penThickness = thickness - 1;
    memcpy(point_p, p, sizeof(float) * size);
    for (i=0; i<size; i++) {
        point_x[i] = x[i] / inputScale;
        point_y[i] = y[i] / inputScale;
        time_lapse += time[i];
        time_stamp[i] = start_at + time_lapse;
    }
    _inputScale = inputScale;
    if (penColor == 0) {
        [self initColor];
    }
    else {
        self.penColor = penColor;
    }
    return self;
}

- (void) dealloc
{
    free(point_x);
    free(point_y);
    free(point_p);
    free(time_stamp);
}
- (void) setPenColor:(UInt32)penColor
{
    _penColor = penColor;
    colorAlpah = (penColor>>24)/255.0f;
    colorRed = ((penColor>>16)&0x000000FF)/255.0f;
    colorGreen = ((penColor>>8)&0x000000FF)/255.0f;
    colorBlue = (penColor&0x000000FF)/255.0f;;
}
- (void)initColor
{
    colorRed = 0.2f;
    colorGreen = 0.2f;
    colorBlue = 0.2f;
    colorAlpah = 1.0f;
    UInt32 alpah = (UInt32)(colorAlpah * 255) & 0x000000FF;
    UInt32 red = (UInt32)(colorRed * 255) & 0x000000FF;
    UInt32 green = (UInt32)(colorGreen * 255) & 0x000000FF;
    UInt32 blue = (UInt32)(colorBlue * 255) & 0x000000FF;
    _penColor = (alpah << 24) | (red << 16) | (green << 8) | blue;
}
- (UIBezierPath *)renderingPath
{
    if (_renderingPath == nil) {
        _renderingPath = [UIBezierPath bezierPath];
        [_renderingPath setLineWidth:1.0];
        [_renderingPath fill];
    }
    return _renderingPath;
}

- (void)renderWithScale:(CGFloat)scale
{
    CGPoint pts[5]; // we now need to keep track of the four points of a Bezier segment and the first control point of the next segment
    uint ctr = 0;
    
    [self.renderingPath removeAllPoints];
    
    if(self.dataCount < 5) {
        
        CGPoint p = CGPointMake(point_x[0] * scale, point_y[0] * scale);
        [self.renderingPath moveToPoint:p];
        
        for(int i=1; i < self.dataCount; i++) {
            p = CGPointMake(point_x[i] * scale, point_y[i] * scale);
            [self.renderingPath addLineToPoint:p];
        }
        
        return;
    }
    
    for(int i=0; i < self.dataCount; i++) {
        
        CGPoint p = CGPointMake(point_x[i] * scale, point_y[i] * scale);
        if(i == 0) {
            pts[0] = p;
            continue;
        }
        ctr++;
        
        pts[ctr] = p;
        if (ctr == 4)
        {
            pts[3] = CGPointMake((pts[2].x + pts[4].x)/2.0, (pts[2].y + pts[4].y)/2.0);
            // move the endpoint to the middle of the line joining the second control point of
            // the first Bezier segment and the first control point of the second Bezier segment
            
            [self.renderingPath moveToPoint:pts[0]];
            [self.renderingPath addCurveToPoint:pts[3] controlPoint1:pts[1] controlPoint2:pts[2]];
            // add a cubic Bezier from pt[0] to pt[3], with control points pt[1] and pt[2]
            // replace points and get ready to handle the next segment
            pts[0] = pts[3];
            pts[1] = pts[4];
            ctr = 1;
        }
        
        if((i == (self.dataCount-1)) && (ctr > 0) && (ctr < 4)) {
            
            CGPoint ctr1;
            CGPoint ctr2;
            
            if(ctr == 1)
                [self.renderingPath addLineToPoint:pts[ctr]];
            else {
                ctr1 = ctr2 = pts[ctr - 2];
                if(ctr == 3)
                    ctr2 = pts[ctr -1];
                
                [self.renderingPath addCurveToPoint:pts[ctr] controlPoint1:ctr1 controlPoint2:ctr2];
            }
        }
    }
    [self.renderingPath stroke];
}

@end
