//
//  NeoNotebookInfo.h
//  NISDK
//
//  Created by NamSang on 12/01/2016.
//  Copyright © 2017 Neolabconvergence. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM (NSInteger, PDFPageReferType) {
    PDFPageReferTypeEvery,
    PDFPageReferTypeOne,
    PDFPageReferTypeEvenOdd,
};

typedef NS_ENUM (NSInteger, NeoNoteType) {
    NeoNoteTypeNormal,
    NeoNoteTypeFranklin,
};

@interface NPNotebookInfo : NSObject

@property (nonatomic) NeoNoteType notebookType;
@property (strong, nonatomic) NSString *title;
@property (nonatomic) PDFPageReferType pdfPageReferType;
@property (nonatomic) NSUInteger maxPage;
@property (nonatomic) BOOL isTemporal;
@property (strong, nonatomic) NSMutableDictionary *pages;

@end
