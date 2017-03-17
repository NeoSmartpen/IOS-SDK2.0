//
//  NJPage.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJPage.h"
#import "NJStroke.h"
#import <NISDK/NISDK.h>

@interface NJPage()

@property (strong, nonatomic) UIBezierPath *renderingPath;
@property (nonatomic) float page_x;
@property (nonatomic) float page_y;

@end

@implementation NJPage

- (void)dealloc
{
    _strokes = nil;
    _renderingPath = nil;
    _paperInfo = nil;
}

- (id) initWithNotebookId:(int)notebookId andPageNumber:(int)pageNumber
{
    self = [super init];
    if(!self) {
        return nil;
    }
    self.notebookId = notebookId;
    self.pageNumber = pageNumber;
    self.strokes = [[NSMutableArray alloc] init];
    
    NSUInteger section,owner;
    [[self class] section:&section owner:&owner fromNotebookId:notebookId];
    
    //from both plist and nproj
    self.paperInfo = [[NJNotebookPaperInfo sharedInstance] getNotePaperInfoForNotebook:(int)notebookId pageNum:(int)pageNumber section:(int)section owner:(int)owner];
    _page_x = self.paperInfo.width;
    _page_y = self.paperInfo.height;
    _startX = self.paperInfo.startX;
    _startY = self.paperInfo.startY;
    
    CGSize paperSize;
    paperSize.width = _page_x;
    paperSize.height = _page_y;
    /* set paper size and input scale. Input scale is used to nomalize stroke data */
    self.paperSize = paperSize;

    _pageHasChanged = NO;

    return self;
}

- (void) setPaperSize:(CGSize)paperSize
{
    _paperSize = paperSize;
    _inputScale = MAX(paperSize.width, paperSize.height);
    
}

- (void) addStrokes:(NJStroke *)stroke
{
    [self.strokes addObject:stroke];
    _pageHasChanged = YES;
}

- (UIImage *)getBackgroundImage
{
    UIImage * image = nil;
    NSUInteger noteId = self.notebookId;
    NSUInteger pageNum = self.pageNumber;

    NSUInteger section, owner;
    [[self class] section:&section owner:&owner fromNotebookId:noteId];
    //from nproj
    image = [[NPPaperManager sharedInstance] getDefaultBackGroundImageForPageNum:pageNum NotebookId:noteId section:section owner:owner];
    
    if (isEmpty(image)) {
        //from plist
        NSString *pdfFileName = [[NJNotebookPaperInfo sharedInstance] backgroundFileNameForSection:0 owner:0 note:(int)noteId];
        if (pdfFileName) {
            NSURL *pdfURL = [[NSBundle mainBundle] URLForResource:pdfFileName withExtension:nil];
            CGPDFDocumentRef PDFDocRef = CGPDFDocumentCreateWithURL( (__bridge CFURLRef) pdfURL );
            
            if (PDFDocRef != NULL)
            {
                if (pageNum < 1) pageNum = 1;
                NSInteger pages = CGPDFDocumentGetNumberOfPages(PDFDocRef);
                if (pageNum > pages) pageNum = pages;
                
                CGPDFPageRef pdfPage = CGPDFDocumentGetPage(PDFDocRef, pageNum);
                if (pdfPage == NULL)
                    CGPDFDocumentRelease(PDFDocRef), PDFDocRef = NULL;
                image = [PDFPageConverter convertPDFPageToImage:pdfPage withResolution:144];
            }
        }
    }

    return image;
}
- (UIImage *) drawPageWithImage:(UIImage *)image size:(CGRect)bounds drawBG:(BOOL)drawBG opaque:(BOOL)opaque
{
    CGRect imageBounds = bounds;
    if (image==nil)
    {
        if(drawBG)
            image = [self getBackgroundImage];
    }
    else {
        // For drawInRect, if the image size does not fit it will resize image.
        imageBounds.size = [image size];
    }
    @autoreleasepool {
        
        UIGraphicsBeginImageContextWithOptions(bounds.size, opaque, 0.0);
        if (image) {
            [image drawInRect:imageBounds];
        }
        else {
            if (opaque) {
                UIBezierPath *rectpath = [UIBezierPath bezierPathWithRect:bounds];
                [[UIColor colorWithWhite:0.95f alpha:1] setFill];
                [rectpath fill];
            }
        }
        
        CGSize paperSize=self.paperSize;
        float xRatio=bounds.size.width/paperSize.width;
        float yRatio=bounds.size.height/paperSize.height;
        float screenRatio = (xRatio > yRatio) ? yRatio:xRatio;
        
        for (int i=0; i < [self.strokes count]; i++) {
            NJStroke *stroke = self.strokes[i];
            [stroke renderWithScale:screenRatio];
        }
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return newImage;
    }
}

- (UIImage *) drawStroke: (NJStroke *)stroke withImage:(UIImage *)image
                    size:(CGRect)bounds scale:(float)scale
                 offsetX:(float)offset_x offsetY:(float)offset_y drawBG:(BOOL)drawBG opaque:(BOOL)opaque
{
    CGRect imageBounds = bounds;
    if (image==nil)
    {
        if(drawBG)
            image = [self getBackgroundImage];
    }
    else {
        // For drawInRect, if the image size does not fit it will resize image.
        imageBounds.size = [image size];
    }
    @autoreleasepool {
        // autoreleasepool added by namSSan 2015-02-13 - refer to
        //http://stackoverflow.com/questions/19167732/coregraphics-drawing-causes-memory-warnings-crash-on-ios-7
        //UIGraphicsBeginImageContextWithOptions(bounds.size, YES, 0.0);
        UIGraphicsBeginImageContextWithOptions(bounds.size, opaque, 0.0);
        if (image) {
            
            [image drawInRect:imageBounds];
        }
        else {
            if (opaque) {
                UIBezierPath *rectpath = [UIBezierPath bezierPathWithRect:bounds];
                [[UIColor colorWithWhite:0.95f alpha:1] setFill];
                [rectpath fill];
            }
        }
        CGSize paperSize=self.paperSize;
        float xRatio=bounds.size.width/paperSize.width;
        float yRatio=bounds.size.height/paperSize.height;
        float screenRatio = (xRatio > yRatio) ? yRatio:xRatio;
        
        [stroke renderWithScale:self.inputScale];
        UIImage *newImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return newImg;
    }
}
- (CGRect)imageSize:(int)size
{
    float targetShortSize = ((size == 0)? 1024.0f : size);
    float ratio = 1;
    float shortSize;
    if (self.page_x < self.page_y) {
        shortSize = self.page_x;
    }
    else {
        shortSize = self.page_y;
    }
    ratio = targetShortSize/shortSize;
    
    CGSize retSize;
    retSize.width = self.page_x*ratio;
    retSize.height = self.page_y*ratio;
    CGRect ret;
    ret.size = retSize;
    CGPoint origin = {0.0f, 0.0f};
    ret.origin = origin;
    return ret;
}

+ (BOOL)section:(NSUInteger *)section owner:(NSUInteger *)owner fromNotebookId:(NSUInteger)notebookId
{
    *section = 3;
    *owner = 27;
    if((notebookId == 605) || (notebookId == 606) || (notebookId == 608))
        *section = 0;
    
    if ((notebookId == 101) || (notebookId == 6)) {
        *section = 5;
        *owner = 6;
    }

    return YES;
}
@end
