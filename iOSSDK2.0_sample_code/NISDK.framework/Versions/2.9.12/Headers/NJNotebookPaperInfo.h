//
//  NJNotebookPaperInfo.h
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NPPaperInfo.h"

@interface NJNotebookPaperInfo : NSObject
@property (nonatomic) int noteListLength;
@property (strong, nonatomic) NSMutableDictionary *notebookPuiInfo;
+ (NJNotebookPaperInfo *) sharedInstance;
- (BOOL) hasInfoForNotebookId:(int)notebookId;
- (BOOL) hasInfoForSectionId:(int)sectionId OwnerId:(int)ownerId;
- (BOOL) getPaperDotcodeRangeForNotebook:(int)notebookId PageNumber:(int)pageNumber Xmax:(float *)x Ymax:(float *)y;
- (BOOL) getPaperDotcodeStartForNotebook:(int)notebookId PageNumber:(int)pageNumber startX:(float *)x startY:(float *)y;

/* Deprecated : This function should not be used. BG has been replaced by dpf. */
- (NSString *) backgroundImageNameForNotebook:(int)notebookId atPage:(int)pageNumber;
- (UInt32) noteIdAt:(int)index;
- (UInt32) sectionOwnerIdAt:(int)index;
- (NSArray *) notesSupported;
/* Return background pdf file name. */
- (NSString *) backgroundFileNameForSection:(int)section owner:(UInt32)onwerId note:(UInt32)noteId;\
/* Return difference in page number between pdf and note. */
- (int) pdfPageOffsetForSection:(int)sectionId owner:(UInt32)onwerId note:(UInt32)noteId;
- (int) getPaperStartPageNumberForNotebook:(int)notebookId;
- (NPPaperInfo *) getNotePaperInfoForNotebook:(int)notebookId pageNum:(int)pageNum section:(int)sectionId owner:(int)ownerId;
@end
