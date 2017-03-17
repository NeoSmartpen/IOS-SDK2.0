//
//  NJPaperInfoManager
//  NISDK
//
//  Created by NamSang on 7/01/2016.
//  Copyright © 2017 Neolabconvergence. All rights reserved.
//

#import "NPPaperManager.h"
#import "NJXMLParser.h"
#import <zipzap/zipzap.h>


#define NEO_SDK_USE_NOTESERVER
#define kNPPaperInfoStore_Current_Max_NotebookId 90000
#define kNPPaperInfoStore_DownloadEntryFileName  @"kNPPaperInfoStore_DownloadEntryFileName"


@interface NJPaperInfoDownloadEntry : NSObject <NSCoding>
@property (strong, nonatomic) NSString *keyName;
@property (strong, nonatomic) NSDate *timeQueued;
@property (nonatomic) NSUInteger numOfTry;
@property (nonatomic) BOOL isInProcess;
@property (nonatomic) BOOL hasCompleted;
@end


@interface NPPaperManager ()

@property (strong, nonatomic) NSArray *notesSupportedArray;
@property (strong, nonatomic) NSMutableArray *notesSupportedMA;
@property (strong, nonatomic) NSTimer *downloadTimer;

@property (strong, nonatomic) NSMutableDictionary *notebookInfos;
@property (strong, nonatomic) NSMutableArray *nprojURLArray;
@end


@implementation NPPaperManager
{
    dispatch_queue_t _download_dispatch_queue;
    NSMutableArray *_downloadQueue;
}

+ (instancetype) sharedInstance
{
    static NPPaperManager *sharedInstance = nil;
    
    @synchronized(self) {
        if(!sharedInstance){
            sharedInstance = [[super allocWithZone:nil] init];
        }
    }
    return sharedInstance;
}
- (instancetype) init
{
    [self clearTmpDirectory];
    self.paperInfos = [NSMutableDictionary dictionary];
    
    self.notebookInfos = [NSMutableDictionary dictionary];
    
    self.nprojURLArray = [NSMutableArray array];
    
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"note_support_list" ofType:@"plist"];
    _notesSupportedArray = [[NSArray alloc] initWithContentsOfFile:plistPath];
    _notesSupportedMA = [NSMutableArray array];
    
    _download_dispatch_queue = dispatch_queue_create("download_dispatch_queue", DISPATCH_QUEUE_SERIAL);
    [self loadAllDownloadEntries_];
    if(!isEmpty(_downloadQueue))
        [self startDownloadTimer_];
    
    return self;
}
+ (NSString *) keyNameForNotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner
{
    NSString *keyName = [NSString stringWithFormat:@"%05tu_%05tu_%08tu",section,owner,notebookId];
    return keyName;
}
+ (BOOL) notebookId:(NSUInteger *)notebookId section:(NSUInteger *)section owner:(NSUInteger *)owner fromKeyName:(NSString *)keyName
{
    if(isEmpty(keyName)) return NO;
    NSArray *tokens = [keyName componentsSeparatedByString:@"_"];
    if(tokens.count != 3) return NO;
    
    *section = [[tokens objectAtIndex:0] integerValue];
    *owner = [[tokens objectAtIndex:1] integerValue];
    *notebookId = [[tokens objectAtIndex:2] integerValue];
    return YES;
}
- (void)reqAddUsingNote:(NSUInteger)notebookId section:(NSUInteger)sectionId owner:(NSUInteger)ownerId
{
    NSMutableDictionary *noteDictMD = [NSMutableDictionary dictionary];
    
    [self notesSupported];
    
    for (NSMutableDictionary *noteMutableDict in _notesSupportedMA) {
        if (([(NSNumber *)[noteMutableDict objectForKey:@"section"] isEqualToNumber:[NSNumber numberWithInteger:sectionId]])
            && ([(NSNumber *)[noteMutableDict objectForKey:@"owner"] isEqualToNumber:[NSNumber numberWithInteger:ownerId]])) {
            
            [noteDictMD setValue:[NSNumber numberWithInteger:sectionId] forKey:@"section"];
            [noteDictMD setValue:[NSNumber numberWithInteger:ownerId] forKey:@"owner"];
            
            NSMutableArray *noteIds = (NSMutableArray *)[noteMutableDict objectForKey:@"noteIds"];
            [noteIds addObject:[NSNumber numberWithInteger:notebookId]];
            [noteDictMD setObject:noteIds forKey:@"noteIds"];
            
            [_notesSupportedMA removeObject:noteMutableDict];
            [_notesSupportedMA addObject:noteDictMD];
            return;
        }
    }
    
    [noteDictMD setValue:[NSNumber numberWithInteger:sectionId] forKey:@"section"];
    [noteDictMD setValue:[NSNumber numberWithInteger:ownerId] forKey:@"owner"];
    NSMutableArray *noteIdArr = [NSMutableArray array];
    [noteIdArr addObject:[NSNumber numberWithInteger:notebookId]];
    [noteDictMD setObject:noteIdArr forKey:@"noteIds"];
    [_notesSupportedMA addObject:noteDictMD];

}
- (NSArray *) notesSupported
{
    if ([_notesSupportedMA count] == 0) {
        for (NSDictionary *noteDict in _notesSupportedArray) {
            NSNumber *sectionId = (NSNumber *)[noteDict objectForKey:@"section"];
            NSNumber *ownerId = (NSNumber *)[noteDict objectForKey:@"owner"];
            NSArray *noteIds = (NSArray *)[noteDict objectForKey:@"noteIds"];
            NSMutableArray *noteIdArr = [NSMutableArray arrayWithArray:noteIds];
            
            NSMutableDictionary *paramsMD = [NSMutableDictionary dictionary];
            [paramsMD setValue:sectionId forKey:@"section"];
            [paramsMD setValue:ownerId forKey:@"owner"];
            [paramsMD setObject:noteIdArr forKey:@"noteIds"];
            [_notesSupportedMA addObject:paramsMD];
        }
    }
    
    return [_notesSupportedMA copy];
}
- (void)removeNotebookInfoForKeyName:(NSString *)keyName
{
    
}
- (NPNotebookInfo *) getNotebookInfoForNotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner
{
    NSString *keyName = [[self class] keyNameForNotebookId:notebookId section:section owner:owner];
    return [self getNotebookInfoForKeyName_:keyName];
}
- (NPNotebookInfo *) getNotebookInfoForKeyName:(NSString *)keyName
{
    if(isEmpty(keyName)) return nil;
    if([keyName integerValue] >= kNPPaperInfoStore_Current_Max_NotebookId) return nil;
    return [self getNotebookInfoForKeyName_:keyName];
}
- (NPNotebookInfo *) getNotebookInfoForKeyName_:(NSString *)keyName
{
    NPNotebookInfo *notebookInfo = [self.paperInfos objectForKey:keyName];
    
    if(notebookInfo == nil) {
        // 1. try to fetch from DB, skip it in NISDK
        //notebookInfo = (NPNotebookInfo *)[self fetchForKeyName_:keyName pageNum:0 fetchPaperInfo:NO];
        
        if(notebookInfo == nil) {
            // 2. try to download from Note Server
            // assume we already downloaded from the server
            // starting from parsing process in background
            [self addDownloadEntryForKeyName_:keyName];
            
            // create default notebook Info
            notebookInfo = [NPNotebookInfo new];
            notebookInfo.title = @"Unknown Notebook";
            notebookInfo.pdfPageReferType = PDFPageReferTypeOne;
            notebookInfo.notebookType = NeoNoteTypeNormal;
            notebookInfo.maxPage = 1000;
            notebookInfo.isTemporal = YES;
        }

        @synchronized(self) {
            [self.paperInfos setObject:notebookInfo forKey:keyName];
        }
    } else {
//         NSLog(@"has in memory for notebookInfo (%@)",keyName);
    }
    
    return notebookInfo;
}
- (NPPaperInfo *) getPaperInfoForNotebookId:(NSUInteger)notebookId pageNum:(NSUInteger)pageNum section:(NSUInteger)section owner:(NSUInteger)owner
{
    NSString *keyName = [[self class] keyNameForNotebookId:notebookId section:section owner:owner];
    return [self getPaperInfoForKeyName_:keyName pageNum:pageNum];
}


- (NPPaperInfo *) getPaperInfoForKeyName_:(NSString *)keyName pageNum:(NSUInteger)pageNum
{
    __block NPNotebookInfo *notebookInfo = nil;
    __block NPPaperInfo *paperInfo = nil;

        notebookInfo = [self.paperInfos objectForKey:keyName];
        
        if(notebookInfo == nil)
            notebookInfo = [self getNotebookInfoForKeyName_:keyName];
        
        if(pageNum <= notebookInfo.maxPage) {
            
            paperInfo = [notebookInfo.pages objectForKey:[NSNumber numberWithInteger:pageNum]];
            //if(paperInfo == nil) {
                
                // 1. try to fetch from DB, skip it in NISDK
                //paperInfo = [self fetchForKeyName_:keyName pageNum:pageNum fetchPaperInfo:YES];
                if(paperInfo) {
                    
                    if(notebookInfo.pdfPageReferType == PDFPageReferTypeOne)
                        paperInfo.pdfPageNum = 1;
                    else if(notebookInfo.pdfPageReferType == PDFPageReferTypeEvenOdd)
                        paperInfo.pdfPageNum = ((pageNum % 2) == 0)? 2 : 1;
                    else
                        paperInfo.pdfPageNum = pageNum;
                    @synchronized(self) {
                        [notebookInfo.pages setObject:paperInfo forKey:[NSNumber numberWithInteger:pageNum]];
                    }
                } else {
                    // create default paper Info
                    paperInfo = [NPPaperInfo new];
                    paperInfo.pdfPageNum = 1;
                    paperInfo.startX = 0.0f;
                    paperInfo.startY = 0.0f;
                    paperInfo.width = 88.82f;
                    paperInfo.height = 125.7f;
                    paperInfo.isTemporal = YES;
                }

            //}
        }

    return paperInfo;
}
- (BOOL)insertPaperInfoFromXML_:(NSDictionary *)xml
{
    BOOL success = NO;
    
    NSString *nprojVersion = [xml objectForKey:@"_version"];
    if (![nprojVersion isEqualToString:@"2.2"]) {
        NSDictionary *book = [xml objectForKey:@"book"];
        if(isEmpty(book)) return success;
        NSUInteger section = [[book objectForKey:@"section"] integerValue];
        NSUInteger owner = [[book objectForKey:@"owner"] integerValue];
        NSUInteger notebookId = [[book objectForKey:@"code"] integerValue];
        NSString *title = ([book objectForKey:@"title"] == nil)? @"NO TITLE" : [book objectForKey:@"title"];
        NSString *keyName = [[self class] keyNameForNotebookId:notebookId section:section owner:owner];
        
        NeoNoteType noteType = NeoNoteTypeNormal;
        if([book objectForKey:@"kind"])
            noteType = [[book objectForKey:@"kind"] integerValue];
        
        PDFPageReferType pdfPageReferType = PDFPageReferTypeEvery;
        NSString *extra = nil;
        if((extra = [book objectForKey:@"extra_info"])) {
            if([extra hasPrefix:@"pdf_page_count"]) {
                NSArray *tokens = [extra componentsSeparatedByString:@"="];
                if(tokens.count == 2) {
                    NSUInteger num = [[tokens lastObject] integerValue];
                    if(num == 1)
                        pdfPageReferType = PDFPageReferTypeOne;
                    else if(num == 2)
                        pdfPageReferType = PDFPageReferTypeEvenOdd;
                }
            }
        }
        
        NSDictionary *pages = [xml objectForKey:@"pages"];
        NSUInteger maxPage = [[pages objectForKey:@"_count"] integerValue];

        NSUInteger segCurrentSeq = [[[book objectForKey:@"segment_info"] objectForKey:@"_current_sequence"] integerValue];
        NSUInteger segStartPage = [[[book objectForKey:@"segment_info"] objectForKey:@"_ncode_start_page"] integerValue];
        NSUInteger segEndPage = [[[book objectForKey:@"segment_info"] objectForKey:@"_ncode_end_page"] integerValue];
        NSUInteger segPageNum = [[[book objectForKey:@"segment_info"] objectForKey:@"_size"] integerValue];
        NSUInteger segSubCode = [[[book objectForKey:@"segment_info"] objectForKey:@"_sub_code"] integerValue];
        NSUInteger segTotalSize = [[[book objectForKey:@"segment_info"] objectForKey:@"_total_size"] integerValue];
        
        NPNotebookInfo *notebookInfo = [self.paperInfos objectForKey:keyName];
        if (isEmpty(notebookInfo)) {
            notebookInfo = [NPNotebookInfo new];
        }
        
        notebookInfo.notebookType = noteType;
        notebookInfo.title = title;
        if ([book objectForKey:@"segment_info"])
            notebookInfo.maxPage = segTotalSize;
        else
            notebookInfo.maxPage = maxPage;
        notebookInfo.pdfPageReferType = pdfPageReferType;
        
        [self.paperInfos setObject:notebookInfo forKey:keyName];
        
        CGFloat scale = 600.0f / 72.0f / 56.0f; // 600/72/56 ~ 0.149
        
        if ([book objectForKey:@"segment_info"]) {
            for(int i=segStartPage; i <= segEndPage; i++) {
                NPPaperInfo *paperInfo = [NPPaperInfo new];
                paperInfo.puiArray = [NSMutableArray array];
                [notebookInfo.pages setObject:paperInfo forKey:[NSNumber numberWithInteger:i]];
            }
        }else{
            for(int i=1; i <= maxPage; i++) {
                NPPaperInfo *paperInfo = [NPPaperInfo new];
                paperInfo.puiArray = [NSMutableArray array];
                [notebookInfo.pages setObject:paperInfo forKey:[NSNumber numberWithInteger:i]];
            }
        }
        
        CGFloat cStartX,cStartY,cWidth,cHeight;
        cStartX = cStartY = cWidth = cHeight = 0.0f;
        
        // use default A4 note
        cStartX = 36.0f;
        cStartY = 36.0f;
        cWidth = 596.099f;
        cHeight = 842.395f;
        
        id pageItems = [pages objectForKey:@"page_item"];
        if(pageItems != nil) {
            BOOL isArray = ([pageItems isKindOfClass:[NSArray class]]);
            NSArray *pageArray = (isArray)? pageItems : [NSArray arrayWithObject:pageItems];
            
            for (NSDictionary *dic in pageArray) {
                NSUInteger pageNum = [[dic objectForKey:@"_number"] integerValue];
                NPPaperInfo *paperInfo = [notebookInfo.pages objectForKey:[NSNumber numberWithInteger:(pageNum + 1)]];
                
                CGFloat x1 = [[dic objectForKey:@"_x1"] floatValue];
                CGFloat y1 = [[dic objectForKey:@"_y1"] floatValue];
                CGFloat x2 = [[dic objectForKey:@"_x2"] floatValue];
                CGFloat y2 = [[dic objectForKey:@"_y2"] floatValue];
                
                NSString *cropMargin = [dic objectForKey:@"_crop_margin"];
                NSArray* marginArray = [cropMargin componentsSeparatedByString: @","];
                CGFloat marginLeft = [[marginArray objectAtIndex:0] floatValue];
                CGFloat marginRight = [[marginArray objectAtIndex:1] floatValue];
                CGFloat marginTop = [[marginArray objectAtIndex:2] floatValue];
                CGFloat marginBtm = [[marginArray objectAtIndex:3] floatValue];
                
                cStartX = marginLeft;
                cStartY = marginTop;
                cWidth = x2 - x1 - marginLeft - marginRight;
                cHeight = y2 -y1 - marginTop - marginBtm;
                
                paperInfo.startX = cStartX * scale;
                paperInfo.startY = cStartY * scale;
                paperInfo.width = cWidth * scale;
                paperInfo.height = cHeight * scale;
                
                @synchronized(self) {
                    [notebookInfo.pages setObject:paperInfo forKey:[NSNumber numberWithInteger:(pageNum + 1)]];
                }
            }
            
        }
        
        id symbols = [[xml objectForKey:@"symbols"] objectForKey:@"symbol"];
        if(symbols != nil) {
            BOOL isArray = ([symbols isKindOfClass:[NSArray class]]);
            NSArray *symbolArray = (isArray)? symbols : [NSArray arrayWithObject:symbols];
            
            for(NSDictionary *symbol in symbolArray) {
                
                NSUInteger pageNum = [[symbol objectForKey:@"_page"] integerValue];
                NPPaperInfo *paperInfo = [notebookInfo.pages objectForKey:[NSNumber numberWithInteger:(pageNum + 1)]];
                
                CGFloat x = [[symbol objectForKey:@"_x"] floatValue];
                CGFloat y = [[symbol objectForKey:@"_y"] floatValue];
                CGFloat width = [[symbol objectForKey:@"_width"] floatValue];
                CGFloat height = [[symbol objectForKey:@"_height"] floatValue];
                NSDictionary *cmdDic = [symbol objectForKey:@"command"];
                NSString *action = [cmdDic objectForKey:@"_action"];
                NSString *name = [cmdDic objectForKey:@"_name"];
                NSString *cmd = [cmdDic objectForKey:@"_param"];
        
                if(cmd == nil) continue;
                
                NPPUIInfo * puiInfo = [NPPUIInfo new];
                PUICmdType cmdType = PUICmdTypeCustom;
                
                if([cmd hasPrefix:@"franklin_"]) {
                    NSArray *tokens = [cmd componentsSeparatedByString:@"_"];
                    NSString *type = [tokens objectAtIndex:1];
                    
                    if([type isEqualToString:@"m"])
                        cmdType = PUICmdTypeActivity;
                    else if([type isEqualToString:
                             @"d"])
                        cmdType = PUICmdTypeAlarm;
                    
                    puiInfo.extraInfo = [tokens lastObject];
                } else if([cmd hasPrefix:@"email"]){
                    PUICmdType cmdType = PUICmdTypeEmail;
                }
                
                puiInfo.cmdType = cmdType;
                puiInfo.shape = PUIShapeRectangle;
                puiInfo.startX = x * scale;
                puiInfo.startY = y * scale;
                puiInfo.width = width * scale;
                puiInfo.height = height * scale;
                puiInfo.param = cmd;
                puiInfo.action = action;
                puiInfo.name = name;
                
                [paperInfo.puiArray addObject:puiInfo];
                
                @synchronized(self) {
                    [notebookInfo.pages setObject:paperInfo forKey:[NSNumber numberWithInteger:(pageNum + 1)]];
                }
            }
        }
        
        if ([book objectForKey:@"segment_info"]) {
            for(int i=segStartPage; i <= segEndPage; i++) {
                NPPaperInfo *paperInfo = [notebookInfo.pages objectForKey:[NSNumber numberWithInteger:i]];
                if(isEmpty(paperInfo)){
                    NSLog(@"notebookId %ld pageNum %d title %@",notebookId, i, title);
                    continue;
                }
                CGFloat w = paperInfo.width;
                if((w <= 0.0)) {
                    paperInfo.startX = cStartX * scale;
                    paperInfo.startY = cStartY * scale;
                    paperInfo.width = cWidth * scale;
                    paperInfo.height = cHeight * scale;
                }
                [notebookInfo.pages setObject:paperInfo forKey:[NSNumber numberWithInteger:i]];
            }
        }else{
            for(int i=1; i <= maxPage; i++) {
                NPPaperInfo *paperInfo = [notebookInfo.pages objectForKey:[NSNumber numberWithInteger:i]];
                if(isEmpty(paperInfo)){
                    NSLog(@"notebookId %ld pageNum %d title %@",notebookId, i, title);
                    continue;
                }
                CGFloat w = paperInfo.width;
                if((w <= 0.0)) {
                    paperInfo.startX = cStartX * scale;
                    paperInfo.startY = cStartY * scale;
                    paperInfo.width = cWidth * scale;
                    paperInfo.height = cHeight * scale;
                }
                [notebookInfo.pages setObject:paperInfo forKey:[NSNumber numberWithInteger:i]];
            }
        }
        
        [self completeDownloadEntry_:keyName];
        
        success = YES;

    }else{
        
        NSDictionary *book = [xml objectForKey:@"book"];
        if(isEmpty(book)) return success;
        NSUInteger section = [[book objectForKey:@"section"] integerValue];
        NSUInteger owner = [[book objectForKey:@"owner"] integerValue];
        NSUInteger notebookId = [[book objectForKey:@"code"] integerValue];
        NSString *title = ([book objectForKey:@"title"] == nil)? @"NO TITLE" : [book objectForKey:@"title"];
        NSString *keyName = [[self class] keyNameForNotebookId:notebookId section:section owner:owner];
        
        NeoNoteType noteType = NeoNoteTypeNormal;
        if([book objectForKey:@"kind"])
            noteType = [[book objectForKey:@"kind"] integerValue];
        
        PDFPageReferType pdfPageReferType = PDFPageReferTypeEvery;
        NSString *extra = nil;
        if((extra = [book objectForKey:@"extra_info"])) {
            if([extra hasPrefix:@"pdf_page_count"]) {
                NSArray *tokens = [extra componentsSeparatedByString:@"="];
                if(tokens.count == 2) {
                    NSUInteger num = [[tokens lastObject] integerValue];
                    if(num == 1)
                        pdfPageReferType = PDFPageReferTypeOne;
                    else if(num == 2)
                        pdfPageReferType = PDFPageReferTypeEvenOdd;
                }
            }
        }
        
        NSDictionary *pages = [xml objectForKey:@"pages"];
        NSUInteger maxPage = [[pages objectForKey:@"_count"] integerValue];

        NPNotebookInfo *notebookInfo = [NPNotebookInfo new];
        notebookInfo.notebookType = noteType;
        notebookInfo.title = title;
        notebookInfo.maxPage = maxPage;
        notebookInfo.pdfPageReferType = pdfPageReferType;
        
        [self.paperInfos setObject:notebookInfo forKey:keyName];
        
        CGFloat scale = 600.0f / 72.0f / 56.0f; // 600/72/56 ~ 0.149

        for(int i=1; i <= maxPage; i++) {
            NPPaperInfo *paperInfo = [NPPaperInfo new];
            paperInfo.puiArray = [NSMutableArray array];
            [notebookInfo.pages setObject:paperInfo forKey:[NSNumber numberWithInteger:i]];
        }
    
        CGFloat cStartX,cStartY,cWidth,cHeight;
        cStartX = cStartY = cWidth = cHeight = 0.0f;
        // use default A4 note
        cStartX = 36.0f;
        cStartY = 36.0f;
        cWidth = 596.099f;
        cHeight = 842.395f;
        
        id pageItems = [pages objectForKey:@"page_item"];
        if(pageItems != nil) {
            BOOL isArray = ([pageItems isKindOfClass:[NSArray class]]);
            NSArray *pageArray = (isArray)? pageItems : [NSArray arrayWithObject:pageItems];
            NSDictionary *dic = [pageArray objectAtIndex:0];
            if(dic) {
                cStartX = [[dic objectForKey:@"_x1"] floatValue];
                cStartY = [[dic objectForKey:@"_y1"] floatValue];
                cWidth = [[dic objectForKey:@"_x2"] floatValue];
                cHeight = [[dic objectForKey:@"_y2"] floatValue];
            }
        }
        
        id symbols = [[xml objectForKey:@"symbols"] objectForKey:@"symbol"];
        if(symbols != nil) {
            BOOL isArray = ([symbols isKindOfClass:[NSArray class]]);
            NSArray *symbolArray = (isArray)? symbols : [NSArray arrayWithObject:symbols];
            
            for(NSDictionary *symbol in symbolArray) {
                
                NSUInteger pageNum = [[symbol objectForKey:@"_page"] integerValue];
                NPPaperInfo *paperInfo = [notebookInfo.pages objectForKey:[NSNumber numberWithInteger:(pageNum + 1)]];
                
                CGFloat x = [[symbol objectForKey:@"_x"] floatValue];
                CGFloat y = [[symbol objectForKey:@"_y"] floatValue];
                CGFloat width = [[symbol objectForKey:@"_width"] floatValue];
                CGFloat height = [[symbol objectForKey:@"_height"] floatValue];
                NSDictionary *cmdDic = [symbol objectForKey:@"command"];
                NSString *action = [cmdDic objectForKey:@"_action"];
                NSString *name = [cmdDic objectForKey:@"_name"];
                NSString *cmd = [cmdDic objectForKey:@"_param"];
                if(cmd == nil) continue;
                
                if((pageNum == 0) && [cmd isEqualToString:@"crop_area_common"]) {
                    cStartX = x;
                    cStartY = y;
                    cWidth = width;
                    cHeight = height;
                } else if ([cmd isEqualToString:@"crop_area"]) {
                    paperInfo.startX = x * scale;
                    paperInfo.startY = y * scale;
                    paperInfo.width = width * scale;
                    paperInfo.height = height * scale;
                    
                    
                    
                } else {
                    NPPUIInfo * puiInfo = [NPPUIInfo new];
                    PUICmdType cmdType = PUICmdTypeCustom;
                    
                    if([cmd hasPrefix:@"franklin_"]) {
                        NSArray *tokens = [cmd componentsSeparatedByString:@"_"];
                        NSString *type = [tokens objectAtIndex:1];
                        
                        if([type isEqualToString:@"m"])
                            cmdType = PUICmdTypeActivity;
                        else if([type isEqualToString:
                                 @"d"])
                            cmdType = PUICmdTypeAlarm;
                        
                        puiInfo.extraInfo = [tokens lastObject];
                    } else if([cmd hasPrefix:@"email"]){
                        PUICmdType cmdType = PUICmdTypeEmail;
                    }
                    
                    puiInfo.cmdType = cmdType;
                    puiInfo.shape = PUIShapeRectangle;
                    puiInfo.startX = x * scale;
                    puiInfo.startY = y * scale;
                    puiInfo.width = width * scale;
                    puiInfo.height = height * scale;
                    puiInfo.param = cmd;
                    puiInfo.action = action;
                    puiInfo.name = name;

                    [paperInfo.puiArray addObject:puiInfo];
                }
                @synchronized(self) {
                    [notebookInfo.pages setObject:paperInfo forKey:[NSNumber numberWithInteger:(pageNum + 1)]];
                }
            }
        }
        
        for(int i=1; i <= maxPage; i++) {
            NPPaperInfo *paperInfo = [notebookInfo.pages objectForKey:[NSNumber numberWithInteger:i]];
            if(isEmpty(paperInfo)){
                NSLog(@"notebookId %d pageNum %d title %@",notebookId, i, title);
                continue;
            }
            CGFloat w = paperInfo.width;
            if((w <= 0.0)) {
                paperInfo.startX = cStartX * scale;
                paperInfo.startY = cStartY * scale;
                paperInfo.width = cWidth * scale;
                paperInfo.height = cHeight * scale;
            }
            [notebookInfo.pages setObject:paperInfo forKey:[NSNumber numberWithInteger:i]];
        }
        

        [self completeDownloadEntry_:keyName];
        
        success = YES;
    }
    
    return success;
}

- (BOOL)hasPaperInfoForKeyName:(NSString *)keyName
{
    if(isEmpty(keyName)) return NO;
    
    if (isEmpty(self.paperInfos)) return NO;

    NSArray *allKeyName = [self.paperInfos allKeys];
    for (NSString *key in allKeyName) {
        if ([key isEqualToString:keyName]) {
            return YES;
        }
    }
    return NO;

}
- (BOOL)hasPaperInfoFromSectionOwner:(NSString *)sectionOwnerName
{
    if(isEmpty(sectionOwnerName)) return NO;

    if (isEmpty(self.paperInfos)) return NO;
    
    NSArray *allKeyName = [self.paperInfos allKeys];
    for (NSString *key in allKeyName) {
        if ([key containsString:sectionOwnerName]) {
            return YES;
        }
    }
    return NO;

}
- (NSURL *)getPdfURLForNotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner
{
    NSString *keyName = [[self class] keyNameForNotebookId:notebookId section:section owner:owner];
    NSURL *pdfURL = [[self bookPDFURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.pdf",keyName]];
    if(![[NSFileManager defaultManager] fileExistsAtPath:pdfURL.path]) return [[NSBundle mainBundle] URLForResource:@"00000_00000_00000000" withExtension:@"pdf" subdirectory:@"NeoPenSdkResources"];
    return pdfURL;
}
- (UIImage *) getDefaultCoverImageForNotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner
{
    NSString *coverImgName = nil;
    
    if(notebookId >= kNPPaperInfoStore_Current_Max_NotebookId) return nil;
    NSString *keyName = [[self class] keyNameForNotebookId:notebookId section:section owner:owner];
    coverImgName = [[self bookCoverURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",keyName]].path;
    UIImage *coverImg = [UIImage imageNamed:coverImgName];

    return coverImg;
}
- (UIImage *) getDefaultBackGroundImageForPageNum:(NSUInteger)pageNum NotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner
{
    NSString *bgImgName = nil;
    
    NSString *keyName = [[self class] keyNameForNotebookId:notebookId section:section owner:owner];
    NSString *keyName1 = [NSString stringWithFormat:@"%@_%05tu",keyName, pageNum];
    bgImgName = [[self bookBgImgURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",keyName1]].path;
    UIImage *bgImg = [UIImage imageNamed:bgImgName];
    if (isEmpty(bgImg)) {
        bgImgName = [[self bookBgImgURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg",keyName1]].path;
        bgImg = [UIImage imageNamed:bgImgName];
    }
    
    return bgImg;
}
- (NSString *) getDefaultCoverNameForNotebookId:(NSUInteger)notebookId section:(NSUInteger)section owner:(NSUInteger)owner
{
    NSString *coverTitle = nil;
    
    if(notebookId >= kNPPaperInfoStore_Current_Max_NotebookId) return @"Unknown Notebook";
    else {
        NSString *keyName = [[self class] keyNameForNotebookId:notebookId section:section owner:owner];
        NPNotebookInfo *notebookInfo = [self getNotebookInfoForKeyName_:keyName];
        coverTitle = notebookInfo.title;
    }
    
    return coverTitle;
}





- (void)startDownloadTimer_
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(_downloadTimer != nil)
            [self stopDownloadTimer_];
        
        _downloadTimer = [NSTimer scheduledTimerWithTimeInterval:30.0f
                                                          target:self
                                                        selector:@selector(processDownloadEntry_)
                                                        userInfo:nil
                                                         repeats:YES];
    });
}
- (void)stopDownloadTimer_
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
//        NSLog(@"download timer stopped");
        [_downloadTimer invalidate];
        _downloadTimer = nil;
    });
}
- (BOOL)loadAllDownloadEntries_
{
    NSString* path = [[self sdkDirectory_] URLByAppendingPathComponent:kNPPaperInfoStore_DownloadEntryFileName].path;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        NSData* data = [[NSData alloc] initWithContentsOfFile:path];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        
        if(isEmpty(unarchiver)) return NO;
        _downloadQueue = [unarchiver decodeObjectForKey:kNPPaperInfoStore_DownloadEntryFileName];
        [unarchiver finishDecoding];
        return YES;
        
    } else {
        _downloadQueue = [[NSMutableArray alloc] init];
        return NO;
    }
}
- (void)saveAllDownloadEntries_
{
    NSMutableData* data = [[NSMutableData alloc] init];
    NSKeyedArchiver* archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [archiver encodeObject:_downloadQueue forKey:kNPPaperInfoStore_DownloadEntryFileName];
    [archiver finishEncoding];
    NSString* path = [[self sdkDirectory_] URLByAppendingPathComponent:kNPPaperInfoStore_DownloadEntryFileName].path;
    [data writeToFile:path atomically:YES];
}
- (void)addDownloadEntryForKeyName_:(NSString *)keyName
{
    dispatch_async(_download_dispatch_queue, ^{
        
        NJPaperInfoDownloadEntry *entry = [NJPaperInfoDownloadEntry new];
        entry.keyName = keyName;
        
        if([_downloadQueue containsObject:entry]) return;

        entry.isInProcess = NO;
        entry.numOfTry = 0;
        entry.timeQueued = [NSDate date];
        
        [_downloadQueue addObject:entry];
        [self startDownloadTimer_];
        [self processDownloadEntry_];
//        NSLog(@"ADD: Download Queue --> %tu",_downloadQueue.count);
        [self saveAllDownloadEntries_];
    });
}
#define MAX_DOWNLOAD_TRY    10
- (void)processDownloadEntry_
{
//    NSLog(@"initiate prcoessing download entry...");
    dispatch_async(_download_dispatch_queue, ^{
        if(isEmpty(_downloadQueue)) return;
        NSUInteger maxTry = MAX_DOWNLOAD_TRY;
        
        NJPaperInfoDownloadEntry *entryToProcess;
        NSMutableArray *entryToDiscard = [NSMutableArray array];
        
        for(NJPaperInfoDownloadEntry *entry in _downloadQueue) {
            if(!entry.isInProcess) {
                if(entry.numOfTry >= MAX_DOWNLOAD_TRY) {
                    [entryToDiscard addObject:entry];
                    continue;
                }
                if(entry.numOfTry < maxTry) {
                    maxTry = entry.numOfTry;
                    entryToProcess = entry;
                }
            }
        }
        if(!isEmpty(entryToDiscard)) {
            for(NJPaperInfoDownloadEntry *entry in entryToDiscard) {
//                NSLog(@"EXCEED MAX TRY --> remove this entry: %@",entry.keyName);
                [_downloadQueue removeObject:entry];
            }
            [self saveAllDownloadEntries_];
        }
        
        if(entryToProcess == nil) return;
        entryToProcess.isInProcess = YES;
        entryToProcess.numOfTry++;
        
//        NSLog(@"PROCESS: keyName -> %@ , Try: %02tu",entryToProcess.keyName,entryToProcess.numOfTry);
//        [self requestNoteInfoForkeyName:entryToProcess.keyName];
        
    });
}
- (void)completeDownloadEntry_:(NSString *)keyName
{
    dispatch_async(_download_dispatch_queue, ^{
        
        NJPaperInfoDownloadEntry *entry = [NJPaperInfoDownloadEntry new];
        entry.keyName = keyName;
        [_downloadQueue removeObject:entry];
        
//        NSLog(@"COMPLETED --> Remove: Download Queue --> %tu",_downloadQueue.count);
        if(isEmpty(_downloadQueue))
            [self stopDownloadTimer_];
        
        [self saveAllDownloadEntries_];
    });
}
- (void)failDownloadEntry_:(NSString *)keyName
{
    dispatch_async(_download_dispatch_queue, ^{
        
        NJPaperInfoDownloadEntry *entryToProcess;
        for(NJPaperInfoDownloadEntry *entry in _downloadQueue) {
            if([entry.keyName isEqualToString:keyName]) {
                entryToProcess = entry;
                break;
            }
        }
        if(entryToProcess == nil) return;
        entryToProcess.isInProcess = NO;
    });
}

- (BOOL)unzipFile:(NSURL *)zipFile keyName:(NSString *)keyName
{
    NSUInteger count = 0;
    NSUInteger jpgCount = 0;
    [self.nprojURLArray removeAllObjects];
    ZZArchive* archive = [ZZArchive archiveWithURL:zipFile error:nil];
    
    for (ZZArchiveEntry* entry in archive.entries)
    {
        NSString *ext = entry.fileName.pathExtension;
        if(isEmpty(ext)) continue;
        NSString *lastComp = [entry.fileName lastPathComponent];
        if([lastComp hasPrefix:@"."]) continue;
        
        if([ext isEqualToString:@"nproj"])
            count++;
        else if([ext isEqualToString:@"jpg"])
            jpgCount++;
        else
            continue;
    }
    
    for (ZZArchiveEntry* entry in archive.entries)
    {
        if (entry.fileMode & S_IFDIR) {
//            this is directory
//            [fm createDirectoryAtURL:targetPath withIntermediateDirectories:YES attributes:nil error:nil];
        } else {
            
            
            NSString *ext = entry.fileName.pathExtension;
            if(isEmpty(ext)) continue;
            NSString *lastComp = [entry.fileName lastPathComponent];
            if([lastComp hasPrefix:@"."]) continue;
            
//            NSLog(@"file name ---> %@",entry.fileName);
            
            NSURL* targetPath = nil;
            if([ext isEqualToString:@"nproj"])
                targetPath = [self bookTmpURL_];
            else if([ext isEqualToString:@"png"])
                //targetPath = [self bookCoverURL];
                targetPath = [self bookBgImgURL];
            else if([ext isEqualToString:@"pdf"])
                targetPath = [self bookPDFURL];
            else if([ext isEqualToString:@"jpg"])
                targetPath = [self bookBgImgURL];
            else
                continue;
            
            NSArray *tokens = [entry.fileName componentsSeparatedByString:@"_"];
            
            if ((count > 1) && [ext isEqualToString:@"nproj"]) {
                NSString *segmentOrderStr;
                for(NSString *string in tokens){
                    if ([string containsString:@"nproj"]) {
                        segmentOrderStr = string;
                        break;
                    }
                }
                NSInteger segmentOrder = [segmentOrderStr integerValue];
                NSString *keyName1 = [NSString stringWithFormat:@"%@_%05tu",keyName, segmentOrder];
                targetPath = [targetPath URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",keyName1,ext] isDirectory:NO];
                [self.nprojURLArray addObject:targetPath];
            }else if([ext isEqualToString:@"jpg"]) {
                NSString *segmentOrderStr;
                for(NSString *string in tokens){
                    if ([string containsString:@"jpg"]) {
                        segmentOrderStr = string;
                        break;
                    }
                }
                NSInteger segmentOrder = [segmentOrderStr integerValue];
                NSString *keyName1 = [NSString stringWithFormat:@"%@_%05tu",keyName, segmentOrder];
                targetPath = [targetPath URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",keyName1,ext] isDirectory:NO];
            }else if([ext isEqualToString:@"png"]) {
                NSString *segmentOrderStr;
                for(NSString *string in tokens){
                    if ([string containsString:@"png"]) {
                        segmentOrderStr = string;
                        break;
                    }
                }
                NSInteger segmentOrder = [segmentOrderStr integerValue];
                NSString *keyName1 = [NSString stringWithFormat:@"%@_%05tu",keyName, segmentOrder];
                targetPath = [targetPath URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",keyName1,ext] isDirectory:NO];
            }else{
                targetPath = [targetPath URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",keyName,ext] isDirectory:NO];
            }
            
            [[entry newDataWithError:nil] writeToURL:targetPath atomically:NO];
        }
    }
    return YES;
}

- (BOOL)installNotebookInfoForKeyName:(NSString *)keyName zipFilePath:(NSURL *)zipFilePath deleteExisting:(BOOL)deleteExisting
{
    BOOL success = NO;
    // simple error check
    if(isEmpty(keyName)) return NO;
    if([keyName componentsSeparatedByString:@"_"].count != 3) return NO;
    
    [self unzipFile:zipFilePath keyName:keyName];
    
    if(self.nprojURLArray.count > 1){
        for(NSURL *url in self.nprojURLArray){
            NSString *filePath = url.path;
            if(filePath == nil) return NO;
            NSDictionary *xmlDoc = [NSDictionary dictionaryWithXMLFile:filePath];
            if(isEmpty(xmlDoc))
                return NO;
            else
                success = [self insertPaperInfoFromXML_:xmlDoc];
        }
    }else{
        NSString *filePath = [[self bookTmpURL_] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.nproj",keyName]].path;
        if(filePath == nil) return NO;
        NSDictionary *xmlDoc = [NSDictionary dictionaryWithXMLFile:filePath];
        if(isEmpty(xmlDoc))
            return NO;
        else
            success = [self insertPaperInfoFromXML_:xmlDoc];
    }
    return success;
}
- (NSURL *) sdkDirectory_
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libDicrectory = paths[0];
    NSURL *URL = [NSURL fileURLWithPath:[libDicrectory stringByAppendingPathComponent:@"NeoSDK"]];
    [URL setResourceValue:[NSNumber numberWithBool:YES] forKey:@"NSURLIsExcludedFromBackupKey" error:nil];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if(![fm fileExistsAtPath:URL.path])
        [fm createDirectoryAtURL:URL withIntermediateDirectories:NO attributes:nil error:NULL];
    
    return URL;
}
- (NSURL *)dbStoreURL_
{
    NSURL *URL = [[self sdkDirectory_] URLByAppendingPathComponent:@"NeoSDK_v2.sqlite"];
    [URL setResourceValue:[NSNumber numberWithBool:YES] forKey:@"NSURLIsExcludedFromBackupKey" error:nil];
    return URL;
}
- (NSURL *) bookTmpURL_
{
    NSURL *URL = [[self sdkDirectory_] URLByAppendingPathComponent:@"tmp"];
    [URL setResourceValue:[NSNumber numberWithBool:YES] forKey:@"NSURLIsExcludedFromBackupKey" error:nil];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if(![fm fileExistsAtPath:URL.path])
        [fm createDirectoryAtURL:URL withIntermediateDirectories:NO attributes:nil error:NULL];
    
    return URL;
}
- (NSURL *) bookCoverURL
{
    NSURL *URL = [[self sdkDirectory_] URLByAppendingPathComponent:@"book_cover"];
    [URL setResourceValue:[NSNumber numberWithBool:YES] forKey:@"NSURLIsExcludedFromBackupKey" error:nil];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if(![fm fileExistsAtPath:URL.path])
        [fm createDirectoryAtURL:URL withIntermediateDirectories:NO attributes:nil error:NULL];
    
    return URL;
}
- (NSURL *) bookPDFURL
{
    NSURL *URL = [[self sdkDirectory_] URLByAppendingPathComponent:@"book_pdf"];
    [URL setResourceValue:[NSNumber numberWithBool:YES] forKey:@"NSURLIsExcludedFromBackupKey" error:nil];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if(![fm fileExistsAtPath:URL.path])
        [fm createDirectoryAtURL:URL withIntermediateDirectories:NO attributes:nil error:NULL];
    
    return URL;
}
- (NSURL *) bookBgImgURL
{
    NSURL *URL = [[self sdkDirectory_] URLByAppendingPathComponent:@"book_bgimg"];
    [URL setResourceValue:[NSNumber numberWithBool:YES] forKey:@"NSURLIsExcludedFromBackupKey" error:nil];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if(![fm fileExistsAtPath:URL.path])
        [fm createDirectoryAtURL:URL withIntermediateDirectories:NO attributes:nil error:NULL];
    
    return URL;
}
- (void)clearTmpDirectory
{
    NSString *tmpPath = [self bookTmpURL_].path;
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpPath error:NULL];
    for (NSString *file in tmpDirectory) {
        [[NSFileManager defaultManager] removeItemAtPath:[tmpPath stringByAppendingPathComponent:file] error:NULL];
    }
}
@end









#define kNJPaperInfoDownloadEntryKeyName                @"kNJPaperInfoDownloadEntryKeyName"
#define kNJPaperInfoDownloadEntryTimeQueued             @"kNJPaperInfoDownloadEntryTimeQueued"
#define kNJPaperInfoDownloadEntryNumOfTry               @"kNJPaperInfoDownloadEntryNumOfTry"
#define kNJPaperInfoDownloadEntryIsInProcess            @"kNJPaperInfoDownloadEntryIsInProcess"
#define kNJPaperInfoDownloadEntryHasCompleted           @"kNJPaperInfoDownloadEntryHasCompleted"

@implementation NJPaperInfoDownloadEntry

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if(self) {
        [self setKeyName:[aDecoder decodeObjectForKey:@"kNJPaperInfoDownloadEntryKeyName"]];
        [self setTimeQueued:[aDecoder decodeObjectForKey:@"kNJPaperInfoDownloadEntryTimeQueued"]];
        [self setNumOfTry:[aDecoder decodeIntegerForKey:@"kNJPaperInfoDownloadEntryNumOfTry"]];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_keyName forKey:@"kNJPaperInfoDownloadEntryKeyName"];
    [aCoder encodeObject:_timeQueued forKey:@"kNJPaperInfoDownloadEntryTimeQueued"];
    [aCoder encodeInteger:_numOfTry forKey:@"kNJPaperInfoDownloadEntryNumOfTry"];
}
- (BOOL)isEqual:(id)object
{
    NJPaperInfoDownloadEntry *rhs = (NJPaperInfoDownloadEntry *)object;
    return [self.keyName isEqualToString:rhs.keyName];
}

@end



