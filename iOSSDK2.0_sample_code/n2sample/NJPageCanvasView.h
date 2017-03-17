//
//  NJPageCanvasView.h
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NJPageCanvasController.h"

@class NJPage;
@interface NJPageCanvasView : UIView
@property CGPoint location;
@property (strong, nonatomic) NJPageCanvasController *btlePeripheral;
@property (strong, nonatomic) NSMutableArray *nodes;
@property (strong, nonatomic) NJPage *page;
@property (strong, nonatomic) UIBezierPath *tempPath;
@property (strong, nonatomic) UIBezierPath *renderingPath;
@property (strong, nonatomic) UIImage *incrementalImage;
@property (weak, nonatomic) UIScrollView *scrollView;
@property (nonatomic) BOOL pageChanging;
@property (nonatomic) BOOL dataUpdating;
@property (nonatomic) UIColor *penUIColor;
@property (nonatomic) UIColor *penPenColor;// Color from pen
@property (nonatomic) CGFloat screenScale;

- (void) touchBeganX:(float)x_coordinate Y:(float)y_coordinate;
- (void) touchMovedX:(float)x_coordinate Y:(float)y_coordinate;
- (void) strokeUpdated;
- (void) drawAllStroke;
@end
