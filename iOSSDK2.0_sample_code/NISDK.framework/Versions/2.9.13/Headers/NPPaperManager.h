//
//  NJPaperInfoManager
//  NISDK
//
//  Created by NamSang on 7/01/2016.
//  Copyright © 2017 Neolabconvergence. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NPNotebookInfo.h"
#import "NPPaperInfo.h"


static NSString * const NPPaperInfoStorePaperBecomeAvailableNotification = @"NPPaperInfoStorePaperBecomeAvailableNotification";

@interface NPPaperManager : NSObject

@property (nonatomic) BOOL isDeveloperMode;
@property (strong, nonatomic) NSMutableDictionary *paperInfos;

+ (instancetype) sharedInstance;
+ (NSString *) keyNameForNotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner;
+ (BOOL) notebookId:(NSUInteger *)notebookId section:(NSUInteger *)section owner:(NSUInteger *)owner fromKeyName:(NSString *)keyName;


- (NSArray *) notesSupported;
- (void)reqAddUsingNote:(NSUInteger)notebookId section:(NSUInteger)sectionId owner:(NSUInteger)ownerId;
- (BOOL)installNotebookInfoForKeyName:(NSString *)keyName zipFilePath:(NSURL *)zipFilePath deleteExisting:(BOOL)deleteExisting;
- (NPNotebookInfo *) getNotebookInfoForKeyName:(NSString *)keyName;
- (NPNotebookInfo *) getNotebookInfoForNotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner;
- (NPPaperInfo *) getPaperInfoForNotebookId:(NSUInteger)notebookId pageNum:(NSUInteger)pageNum section:(NSUInteger)section owner:(NSUInteger)owner;



- (BOOL) hasPaperInfoForKeyName:(NSString *)keyName;
- (BOOL) hasPaperInfoFromSectionOwner:(NSString *)sectionOwnerName;
- (NSURL *) getPdfURLForNotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner;
- (UIImage *) getDefaultCoverImageForNotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner;
- (UIImage *) getDefaultBackGroundImageForPageNum:(NSUInteger)pageNum NotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner;
- (NSString *) getDefaultCoverNameForNotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner;


@end
