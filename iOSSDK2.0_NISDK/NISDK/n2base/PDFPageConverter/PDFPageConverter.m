//
//  PDFPageConverter.m
//
//  Created by Sorin Nistor on 3/23/11.
//  Copyright 2011 iPDFdev.com. All rights reserved.
//

#import "PDFPageConverter.h"
#import "PDFPageRenderer.h"

@implementation PDFPageConverter

+ (UIImage *) convertPDFPageToImage: (CGPDFPageRef) page withResolution: (float) resolution {
	
	CGRect cropBox = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
	int pageRotation = CGPDFPageGetRotationAngle(page);
	
	if ((pageRotation == 0) || (pageRotation == 180) ||(pageRotation == -180)) {
		UIGraphicsBeginImageContextWithOptions(cropBox.size, NO, resolution / 72); 
	}
	else {
		UIGraphicsBeginImageContextWithOptions(CGSizeMake(cropBox.size.height, cropBox.size.width), NO, resolution / 72); 
	}
	
	CGContextRef imageContext = UIGraphicsGetCurrentContext();   
	
    [PDFPageRenderer renderPage:page inContext:imageContext];
	
    UIImage *pageImage = UIGraphicsGetImageFromCurrentImageContext();
    CGSize size = [pageImage size];
    NSLog(@"PDF Width %f, height %f", size.width, size.height);
	
    UIGraphicsEndImageContext();
	
	return pageImage;
}

@end
