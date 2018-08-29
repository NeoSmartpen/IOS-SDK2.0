//
//  NeoPageInfo.h
//  NISDK
//
//  Created by NamSang on 12/01/2016.
//  Copyright © 2017 Neolabconvergence. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NPPaperInfo : NSObject

@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat height;
@property (nonatomic) CGFloat startX;
@property (nonatomic) CGFloat startY;
@property (nonatomic) NSUInteger pdfPageNum;
@property (nonatomic) BOOL isTemporal;
@property (strong, nonatomic) NSMutableArray *puiArray;

@end
