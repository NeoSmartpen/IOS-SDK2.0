//
//  NJPage.h
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>

#define MAX_NODE_NUMBER 1024

@class NJStroke;
@class NPPaperInfo;
@interface NJPage : NSObject
@property (strong, nonatomic) NSMutableArray *strokes;
@property (nonatomic) BOOL pageHasChanged;
@property (nonatomic) CGRect bounds;
@property (strong, nonatomic) UIImage *image;
@property (nonatomic) CGSize paperSize; //notebook size
@property (nonatomic) float screenRatio;
@property (nonatomic) int notebookId;
@property (nonatomic) int pageNumber;
@property (nonatomic) float inputScale;
@property (nonatomic) UInt32 penColor;
@property (nonatomic) float startX;
@property (nonatomic) float startY;
@property (strong, nonatomic) NPPaperInfo *paperInfo;

- (id) initWithNotebookId:(int)notebookId andPageNumber:(int)pageNumber;
- (void) addStrokes:(NJStroke *)stroke;
- (UIImage *) drawPageWithImage:(UIImage *)image size:(CGRect)bounds drawBG:(BOOL)drawBG opaque:(BOOL)opaque;
- (UIImage *) drawPageBackgroundImage:(UIImage *)image size:(CGRect)bounds;
- (UIImage *) drawStroke: (NJStroke *)stroke withImage:(UIImage *)image
                    size:(CGRect)bounds scale:(float)scale
                 offsetX:(float)offset_x offsetY:(float)offset_y drawBG:(BOOL)drawBG opaque:(BOOL)opaque;
- (CGRect)imageSize:(int)size;
+ (BOOL)section:(NSUInteger *)section owner:(NSUInteger *)owner fromNotebookId:(NSUInteger)notebookId;
@end
