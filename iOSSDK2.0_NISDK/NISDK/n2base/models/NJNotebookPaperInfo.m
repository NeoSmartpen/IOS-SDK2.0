//
//  NJNotebookPaperInfo.m
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "NJNotebookPaperInfo.h"
#import "NPPaperManager.h"

typedef struct {
    unsigned section_id;
    UInt32 owner_id;  // 3 bytes
    UInt32 note_id;
    int max_page;
    int width;
    int heght;
    int dx;
    int dy;
    float startX;
    float startY;
    char *page_1;
    char *page_2;
    char *page_even;
    char *page_odd;
} NotebookInfoType;

NotebookInfoType notebookTypeArray[] = {
    {0, 19, 1, 102, 62, 89, 4, 1, 1.2f, 1.0f, "", "", "Note_ID_1_even.png", "Note_ID_1_odd.png"},   // Season Notebook Default Note
    {3, 27, 101, 64, 78, 109, 2, 2, 0.0f, 0.0f, "", "", "", ""}, // Neo1 Large
    {3, 27, 102, 64, 65, 92, 2, 2, 0.0f, 0.0f, "", "", "", ""},  // Neo1 Medium
    {3, 27, 103, 160, 41, 57, 2, 2, 0.0f, 0.0f, "", "", "", ""}, // Neo1 Small
    {3, 27, 201, 64, 84, 107, 2, 2, 0.0f, 0.0f, "", "", "", ""}, // SnowCat Large
    {3, 27, 202, 64, 69, 95, 2, 2, 0.0f, 0.0f, "", "", "", ""},  // SnowCat Medium
    {3, 27, 203, 64, 56, 77, 2, 2, 0.0f, 0.0f, "", "", "", ""},   // SnowCat Small
    {3, 27, 301, 64, 74, 106, 0, 0, 4.8f, 4.8f, "", "", "", ""}, // Neo Basic 01"
    {3, 27, 302, 64, 74, 106, 0, 0, 4.8f, 4.8f, "", "", "", ""}, // Neo Basic 02"
    {3, 27, 303, 64, 74, 106, 0, 0, 4.8f, 4.8f, "", "", "", ""}, // Neo Basic 03"
};

//13bits:data(4bit year,4bit month, 5bit date, ex:14 08 28)
//3bits: cmd, (no need => 1bit:dirty bit)
typedef enum {
    None = 0x00,
    Email = 0x01,
    Alarm = 0x02,
    Activity = 0x04
} PageArrayCommandState;

typedef struct{
    int page_id;
    float activeStartX;
    float activeStartY;
    float activeWidth;
    float activeHeight;
    float spanX;
    float spanY;
    int arrayX; //email:action array, alarm|activity: month start array, alarm :startPage
    int arrayY; //email:action array, alarm|activity: month start array, alarm :endPage
    int startDate;
    int endDate;
    int remainedDate;
    int month;
    int year;
    PageArrayCommandState cmd;
} PageInfoType;

PageInfoType s_1_infoType[] = {
    {3, 57.0f, 83.0f, 4.0f, 4.0f, 4.0f, 4.0f, 0, 0, 0, 0, 0, 0, 0,Email},
    {4, 18.0f, 83.0f, 4.0f, 4.0f, 4.0f, 4.0f, 0, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType m_2_infoType[] = {
    {1, 73.5f, 105.3f, 2.5f, 2.5f, 2.5f, 2.5f, 0, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_101_infoType[] = {
    {3, 70.0f, 8.4f, 3.0f, 2.0f, 3.0f, 2.0f, 0, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_102_infoType[] = {
    {3, 59.0f, 8.5f, 2.0f, 1.5f, 2.0f, 1.5f, 0, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_103_infoType[] = {
    {3, 36.0f, 6.0f, 2.0f, 1.4f, 2.0f, 1.4f, 0, 0, 0, 0, 0, 0, 0,Email},
    {4, 7.7f, 6.0f, 2.0f, 1.4f, 2.0f, 1.4f, 0, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_201_infoType[] = {
    {1, 5.0f, 5.0f, 67, 96, 3, 3, 1, 1, 0, 0, 0, 0, 0,None},
    {2, 5.0f, 5.0f, 67, 96, 3, 3, 10, 31, 0, 0, 0, 0, 0,Email},
    {3, 5.0f, 5.0f, 67, 96, 3, 3, 14, 31, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_202_infoType[] = {
    {1, 5.0f, 5.0f, 67, 96, 3, 2, 1, 1, 0, 0, 0, 0, 0,None},
    {2, 5.0f, 5.0f, 67, 96, 3, 2, 0, 0, 0, 0, 0, 0, 0,Email},
    {3, 5.0f, 5.0f, 67, 96, 3, 2, 21, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_203_infoType[] = {
    {1, 5.0f, 5.0f, 67, 96, 3, 2, 1, 1, 0, 0, 0, 0, 0,None},
    {2, 5.0f, 5.0f, 67, 96, 3, 2, 0, 0, 0, 0, 0, 0, 0,Email},
    {3, 5.0f, 5.0f, 67, 96, 3, 2, 21, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_1_infoType[] = {
    {1, 9.8f, 9.8f, 67, 96, 3, 2, 1, 1, 0, 0, 0, 0, 0,None},
    {2, 9.8f, 9.8f, 67, 96, 3, 2, 0, 0, 0, 0, 0, 0, 0,Email},
    {3, 9.8f, 9.8f, 67, 96, 3, 2, 21, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_2_infoType[] = {
    {1, 9.8f, 9.8f, 67, 96, 3, 2, 1, 1, 0, 0, 0, 0, 0,None},
    {2, 9.8f, 9.8f, 67, 96, 3, 2, 0, 0, 0, 0, 0, 0, 0,Email},
    {3, 9.8f, 9.8f, 67, 96, 3, 2, 21, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_3_infoType[] = {
    {1, 9.8f, 9.8f, 67, 96, 3, 2, 1, 1, 0, 0, 0, 0, 0,None},
    {2, 9.8f, 9.8f, 67, 96, 3, 2, 0, 0, 0, 0, 0, 0, 0,Email},
    {3, 9.8f, 9.8f, 67, 96, 3, 2, 21, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_602_infoType[] = {
    {1, 36.0f, 8.6f, 2.0f, 2.0f, 2.0f, 2.0f, 0, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_604_infoType[] = {
    {1, 70.2f, 10.2f, 3.5f, 2.5f, 3.5f, 2.5f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_610_infoType[] = {
    {1, 70.2f, 10.2f, 3.5f, 2.5f, 3.5f, 2.5f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_611_infoType[] = {
    {1, 70.2f, 10.2f, 3.5f, 2.5f, 3.5f, 2.5f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_612_infoType[] = {
    {1, 70.2f, 10.2f, 3.5f, 2.5f, 3.5f, 2.5f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_613_infoType[] = {
    {1, 70.2f, 10.2f, 3.5f, 2.5f, 3.5f, 2.5f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_614_infoType[] = {
    {1, 84.75f, 11.25f, 3.24f, 2.29f, 3.24f, 2.29f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_615_infoType[] = {
    {1, 56.17f, 10.4f, 3.03f, 2.63f, 3.03f, 2.63f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_616_infoType[] = {
    {1, 37.77f, 9.12f, 2.44f, 2.17f, 2.44f, 2.17f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_617_infoType[] = {
    {1, 85.94f, 11.28f, 4.08f, 2.87f, 4.08f, 2.87f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_618_infoType[] = {
    {1, 85.94f, 11.28f, 4.08f, 2.87f, 4.08f, 2.87f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_619_infoType[] = {
    {1, 85.94f, 11.28f, 4.08f, 2.87f, 4.08f, 2.87f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_609_infoType[] = {
    {1, 86.4f, 20.9f, 3.7f, 2.5f, 3.7f, 2.5f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_620_infoType[] = {
    {1, 52.12f, 19.16f, 3.2f, 2.4f, 3.2f, 2.4f, 0, 0, 0, 0, 0, 0, 0,Email},
};

PageInfoType n_700_infoType[] = {
    {1, 46.43f, 4.45f, 3.9f, 2.6f, 3.4f, 2.1f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_701_infoType[] = {
    {1, 49.75f, 7.56f, 3.3f, 2.3f, 3.3f, 2.3f, 0, 0, 0, 0, 0, 0, 0,Email},
};
PageInfoType n_702_infoType[] = {
    {1, 49.75f, 7.56f, 3.3f, 2.3f, 3.3f, 2.3f, 0, 0, 0, 0, 0, 0, 0,Email},
};

typedef struct {
    UInt32 note_id;
    PageInfoType *pageInfo;
} NotebookPuiInfoType;

NotebookPuiInfoType notebookPuiTypeArray[] = {
    {602, n_602_infoType}, //memo note
};

@interface NJNotebookPaperInfo()
@property (strong, nonatomic) NSDictionary *notebookInfos;
@property (strong, nonatomic) NSDictionary *notesbookPuiInfos;
@property (nonatomic) int activeNoteId;
@property (nonatomic) int activePageId;
@property (strong, nonatomic) NPPaperInfo *paperInfo;
@end

@implementation NJNotebookPaperInfo
+ (NJNotebookPaperInfo *) sharedInstance
{
    static NJNotebookPaperInfo *shared = nil;
    
    @synchronized(self) {
        if(!shared){
            shared = [[NJNotebookPaperInfo alloc] init];
        }
    }
    
    return shared;
}
- (id) init
{
    self = [super init];

    if(self) {
        NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"note_paper_info" ofType:@"plist"];
        _notebookInfos = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
        _noteListLength = -1;
        
        int infoSize = sizeof(notebookPuiTypeArray)/sizeof(NotebookPuiInfoType);

        self.notebookPuiInfo = [[NSMutableDictionary alloc] initWithCapacity:infoSize];
        
        for (int i = 0; i < infoSize; i++) {
            NotebookPuiInfoType info = notebookPuiTypeArray[i];
            NSDictionary *puiInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[NSValue valueWithPointer:info.pageInfo], @"page_info", nil];
            [self.notebookPuiInfo setObject:puiInfo forKey:[NSNumber numberWithInt:info.note_id]];
        }
        
    }
    
    return self;
}
- (int)noteListLength
{
    if (_noteListLength == -1) {
        _noteListLength = (int)[_notebookInfos count];
    }
    return _noteListLength;
}
//from only plist, remove from DB (note server)
- (BOOL) hasInfoForNotebookId:(int)notebookId
{
    for (NSDictionary *noteDict in self.notesSupported) {
        if ([(NSArray *)[noteDict objectForKey:@"noteIds"] indexOfObject:[NSNumber numberWithInt:notebookId]] != NSNotFound) {
            return YES;
        }
    }
    return NO;
}
//from both plist and DB (note server)
- (BOOL) hasInfoForSectionId:(int)sectionId OwnerId:(int)ownerId
{
    for (NSDictionary *noteDict in self.notesSupported) {
        if (([(NSNumber *)[noteDict objectForKey:@"section"] isEqualToNumber:[NSNumber numberWithInt:sectionId]])
            && ([(NSNumber *)[noteDict objectForKey:@"owner"] isEqualToNumber:[NSNumber numberWithInt:ownerId]])) {
            return YES;
        }
    }
    
    NSString *sectionOwnerStr = [NSString stringWithFormat:@"%05tu_%05tu",(NSUInteger)sectionId,(NSUInteger)ownerId];
    
    if([[NPPaperManager sharedInstance] hasPaperInfoFromSectionOwner:sectionOwnerStr]) return YES;
    
    return NO;
}
//from only plist, remove DB (note server)
- (UInt32) sectionIdAndOwnerIdFromNotebookID:(UInt32)notebookId
{
    UInt32 ownerId;
    unsigned char sectionId;
    UInt32 sectionOwnerId = 0;
    
    BOOL notebookExisted = [self hasInfoForNotebookId:notebookId];
    
    if (notebookExisted) {
        for (NSDictionary *noteDict in self.notesSupported) {
            if ([(NSArray *)[noteDict objectForKey:@"noteIds"] indexOfObject:[NSNumber numberWithInt:notebookId]] != NSNotFound){
                sectionId = [(NSNumber *)[noteDict objectForKey:@"section"] unsignedCharValue];
                ownerId = (UInt32)[(NSNumber *)[noteDict objectForKey:@"owner"] unsignedIntegerValue];
                sectionOwnerId = (sectionId << 24) | ownerId;
            }
        }

    } else {
        return 0;
    }
                           
    return sectionOwnerId;
}

- (BOOL) getPaperDotcodeRangeForNotebook:(int)notebookId PageNumber:(int)pageNumber Xmax:(float *)x Ymax:(float *)y
{
    // Temporary code. We are getting section id and owner id from a pen.
    // But it's not implemented to use the ids. Have a look at note_paper_info.plist
    unsigned int sectionId = 0;
    unsigned int ownerId = 0;
    if (sectionId == 0 && ownerId == 0) {
        if (notebookId == 1) {
            sectionId = 0;
            ownerId = 19;
        }
        else {
            sectionId = 3;
            ownerId = 27;
        }
    }
    
    UInt32 sectionOwnerID = [self sectionIdAndOwnerIdFromNotebookID:notebookId];
    
    if(sectionOwnerID != 0){
        sectionId = (sectionOwnerID >> 24) & 0xFF;
        ownerId = sectionOwnerID & 0x00FFFFFF;
    }
    
    NSString *keyName;
    if ((notebookId == 606) && (pageNumber > 60)) {
        keyName = [NSString stringWithFormat:@"%02d_%02d_%04d_1", (unsigned int)sectionId, (unsigned int)ownerId, (unsigned int)notebookId];
    }else{
        keyName = [NSString stringWithFormat:@"%02d_%02d_%04d", (unsigned int)sectionId, (unsigned int)ownerId, (unsigned int)notebookId];
    }
    
    NSDictionary *info = [self.notebookInfos objectForKey:keyName];
    if (info == nil) {
        // Reached here. It means there is no matching information. Just use default one.
        keyName = @"00_00_0000";
        info = [self.notebookInfos objectForKey:keyName];
        if (info == nil) {
            *x = -1.0f;
            *y = -1.0f;
            return NO;
        }
    }
    float width = [(NSNumber *)[info objectForKey:@"width"] floatValue];
    float height = [(NSNumber *)[info objectForKey:@"height"] floatValue];
    *x = width;
    *y = height;
    return YES;
}
- (BOOL) getPaperDotcodeStartForNotebook:(int)notebookId PageNumber:(int)pageNumber startX:(float *)x startY:(float *)y
{
    // Temporary code. We are getting section id and owner id from a pen.
    // But it's not implemented to use the ids. Have a look at note_paper_info.plist
    unsigned int sectionId = 0;
    unsigned int ownerId = 0;
    if (sectionId == 0 && ownerId == 0) {
        if (notebookId == 1) {
            sectionId = 0;
            ownerId = 19;
        }
        else {
            sectionId = 3;
            ownerId = 27;
        }
    }
    
    UInt32 sectionOwnerID = [self sectionIdAndOwnerIdFromNotebookID:notebookId];
    
    if(sectionOwnerID != 0){
        sectionId = (sectionOwnerID >> 24) & 0xFF;
        ownerId = sectionOwnerID & 0x00FFFFFF;
    }
    
    NSString *keyName;
    if ((notebookId == 606) && (pageNumber > 60)) {
        keyName = [NSString stringWithFormat:@"%02d_%02d_%04d_1", (unsigned int)sectionId, (unsigned int)ownerId, (unsigned int)notebookId];
    }else{
        keyName = [NSString stringWithFormat:@"%02d_%02d_%04d", (unsigned int)sectionId, (unsigned int)ownerId, (unsigned int)notebookId];
    }
    
    NSDictionary *info = [self.notebookInfos objectForKey:keyName];
    if (info == nil) {
        
        *x = 0.0f;
        *y = 0.0f;
        return NO;
    }
    *x = [(NSNumber *)[info objectForKey:@"startX"] floatValue];
    *y = [(NSNumber *)[info objectForKey:@"startY"] floatValue];
    return YES;
}/* Deprecated : This function should not be used. BG has been replaced by dpf. */
- (NSString *) backgroundImageNameForNotebook:(int)notebookId atPage:(int)pageNumber
{
    return nil;
}
/* Return background pdf file name. */
- (NSString *) backgroundFileNameForSection:(int)sectionId owner:(UInt32)onwerId note:(UInt32)noteId
{
    // Temporary code. We are getting section id and owner id from a pen.
    // But it's not implemented to use the ids. Have a look at note_paper_info.plist
    if (sectionId == 0 && onwerId == 0) {
        if (noteId == 1) {
            sectionId = 0;
            onwerId = 19;
        }
        else {
            sectionId = 3;
            onwerId = 27;
        }
    }
    
    UInt32 sectionOwnerID = [self sectionIdAndOwnerIdFromNotebookID:noteId];
    
    if(sectionOwnerID != 0){
        sectionId = (sectionOwnerID >> 24) & 0xFF;
        onwerId = sectionOwnerID & 0x00FFFFFF;
    }
    
    NSString *keyName = [NSString stringWithFormat:@"%02d_%02d_%04d", (unsigned int)sectionId, (unsigned int)onwerId, (unsigned int)noteId];
    NSDictionary *noteInfo = [_notebookInfos objectForKey:keyName];
    NSString *fileName = nil;
    if (noteInfo != nil) {
        fileName = [noteInfo objectForKey:@"bgFileName"];
    }
    return fileName;
}
/* Return difference in page number between pdf and note. */
- (int) pdfPageOffsetForSection:(int)sectionId owner:(UInt32)onwerId note:(UInt32)noteId
{
    // Temporary code. We are getting section id and owner id from a pen.
    // But it's not implemented to use the ids. Have a look at note_paper_info.plist
    if (sectionId == 0 && onwerId == 0) {
        if (noteId == 1) {
            sectionId = 0;
            onwerId = 19;
        }
        else {
            sectionId = 3;
            onwerId = 27;
        }
    }
    
    UInt32 sectionOwnerID = [self sectionIdAndOwnerIdFromNotebookID:noteId];
    
    if(sectionOwnerID != 0){
        sectionId = (sectionOwnerID >> 24) & 0xFF;
        onwerId = sectionOwnerID & 0x00FFFFFF;
    }
    
    NSString *keyName = [NSString stringWithFormat:@"%02d_%02d_%04d", (unsigned int)sectionId, (unsigned int)onwerId, (unsigned int)noteId];
    NSDictionary *noteInfo = [_notebookInfos objectForKey:keyName];
    NSNumber *pdfPageOffset = [noteInfo objectForKey:@"pdfPageOffset"];
    if (pdfPageOffset != nil) {
        return [pdfPageOffset integerValue];
    }
    return 0;
}

- (int) getPaperStartPageNumberForNotebook:(int)notebookId
{
    unsigned int sectionId = 0;
    unsigned int ownerId = 0;
    if (sectionId == 0 && ownerId == 0) {
        if (notebookId == 1) {
            sectionId = 0;
            ownerId = 19;
        }
        else {
            sectionId = 3;
            ownerId = 27;
        }
    }
    
    UInt32 sectionOwnerID = [self sectionIdAndOwnerIdFromNotebookID:notebookId];
    
    if(sectionOwnerID != 0){
        sectionId = (sectionOwnerID >> 24) & 0xFF;
        ownerId = sectionOwnerID & 0x00FFFFFF;
    }
    
    NSString *keyName = [NSString stringWithFormat:@"%02d_%02d_%04d", (unsigned int)sectionId, (unsigned int)ownerId, (unsigned int)notebookId];
    NSDictionary *noteInfo = [_notebookInfos objectForKey:keyName];
    NSNumber *startPageNumber = [noteInfo objectForKey:@"startPageNumber"];
    if (startPageNumber != nil) {
        return [startPageNumber integerValue];
    }
    return 1;
}

- (UInt32) noteIdAt:(int)index
{
    if (index >= self.noteListLength) {
        return 0;
    }
    return notebookTypeArray[index].note_id;
}
- (UInt32) sectionOwnerIdAt:(int)index
{
    if (index >= self.noteListLength) {
        return 0;
    }
    unsigned char section = notebookTypeArray[index].section_id;
    UInt32 owner = notebookTypeArray[index].owner_id;
    
    return (section << 24) | owner;
}
- (NSArray *) notesSupported
{
    return [[NPPaperManager sharedInstance] notesSupported];
}

- (NPPaperInfo *) getNotePaperInfoForNotebook:(int)notebookId pageNum:(int)pageNum section:(int)sectionId owner:(int)ownerId
{

    
        NSString *keyName = [NSString stringWithFormat:@"%02d_%02d_%04d", sectionId, ownerId, notebookId];
        NSDictionary *noteInfo = [_notebookInfos objectForKey:keyName];
        
        NPPaperInfo *paperInfo;
        
        if (noteInfo != nil) {
            paperInfo = [NPPaperInfo new];
            paperInfo.width = [[noteInfo objectForKey:@"width"] floatValue];
            paperInfo.height = [[noteInfo objectForKey:@"height"] floatValue];
            paperInfo.startX = [[noteInfo objectForKey:@"startX"] floatValue];
            paperInfo.startY = [[noteInfo objectForKey:@"startY"] floatValue];
        } else {
            paperInfo = [[NPPaperManager sharedInstance] getPaperInfoForNotebookId:notebookId pageNum:pageNum section:sectionId owner:ownerId];
        }
        self.paperInfo = paperInfo;
        
        self.activeNoteId = notebookId;
        self.activePageId = pageNum;
        
    return self.paperInfo;
}
@end
