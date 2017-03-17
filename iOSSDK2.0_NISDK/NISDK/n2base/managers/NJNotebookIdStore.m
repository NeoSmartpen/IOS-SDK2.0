//
//  NJNotebookNameStore.m
//  NISDK
//
//  Created by NamSSan on 17/09/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJNotebookIdStore.h"
#import "configure.h"
static NSString * const kNoteboookUUIDTableFileName = @"nj_notebook_uuid_table_fn";

@interface NJNotebookIdEntry : NSObject <NSCoding>
@property (nonatomic) NSUInteger noteType;
@property (nonatomic, strong) NSString *UUID;
@property (nonatomic, strong) NSDate *timeCreated;
@end

@implementation NJNotebookIdStore



+ (NJNotebookIdStore *)sharedStore
{
    static NJNotebookIdStore *sharedStore = nil;
    
    @synchronized(self) {
        
        if(!sharedStore) {
            sharedStore = [[super allocWithZone:nil] init];
            
        }
    }
    return sharedStore;
}




- (id)init
{
    self = [super init];
    
    if(self) {
        
        // load existing table -- last active uuid for each note type
        // or re-construct table from every launching of the app --> not works
        
    }
    return self;
}


- (NSString *)itemArchivePath
{
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
    
	return [documentsDirectory stringByAppendingPathComponent:kNoteboookUUIDTableFileName];
}





- (BOOL)loadAllItems
{
	NSString* path = [self itemArchivePath];
    
	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
        
		NSData* data = [[NSData alloc] initWithContentsOfFile:path];
		NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        
        _notebook_uuid_table = [unarchiver decodeObjectForKey:kNoteboookUUIDTableFileName];
		[unarchiver finishDecoding];
        [self _printAllItems];
        return YES;
        
    } else {
        
        _notebook_uuid_table = [[NSMutableArray alloc] init];
        //[self addSampleItems];
        return NO;
	}
}



- (void)_printAllItems
{
    if(isEmpty(_notebook_uuid_table)) return;
    
    NSLog(@"\n\n");
    NSLog(@"**************** NotebookID Table **********************\n");
    NSLog(@"   INDEX     |    NOTE_TYPE     |           UUID        \n");
    NSLog(@"********************************************************\n");
    int count = 0;
    
    for(NJNotebookIdEntry *entry in _notebook_uuid_table) {
    
        NSLog(@"%d       |      %ld         | %@",++count,(unsigned long)entry.noteType,entry.UUID);
        
    }
    NSLog(@"********************************************************\n");
}



- (void)saveAllItems
{
    NSMutableData* data = [[NSMutableData alloc] init];
    
    NSKeyedArchiver* archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    
    [archiver encodeObject:_notebook_uuid_table forKey:kNoteboookUUIDTableFileName];
    
    [archiver finishEncoding];
    [data writeToFile:[self itemArchivePath] atomically:YES];
    NSLog(@"Saving All Notebook ID entries to...%@\n",[self itemArchivePath]);
}




- (NSString *)notebookIdName:(NSUInteger)notebookId
{
    NSString *notebookUuid = nil;
    if(((NSInteger)notebookId) <= 0 || notebookId > 99999999) {
        
        // if this error happenes. we will have to check source code and modify according to new uuid protocol
        //NSAssert(NO, @"got cha!! notebook ID %lu is invalid, will create unknown notebook and folders",(unsigned long)notebookUuid);
        return nil;
    }
    
    for(NJNotebookIdEntry *entry in _notebook_uuid_table) {
        
        if(entry.noteType == notebookId) {
            notebookUuid = entry.UUID;
            return notebookUuid;
        }
    }
    
    return [self _notebookIdName:notebookId];
}

- (NSString *)_notebookIdName:(NSUInteger)notebookId
{
    
    NSString *notebookUuid = nil;
    //if not exist in the table - create one
    // crate NEW
    notebookUuid = [NSString stringWithFormat:@"%05ld_%@",(unsigned long)notebookId,[NJNotebookIdStore createUuid]];
    
    // add New entry into table
    NJNotebookIdEntry *entry = [[NJNotebookIdEntry alloc] init];
    entry.noteType = notebookId;
    entry.UUID = notebookUuid;
    entry.timeCreated = [NSDate date];
    [_notebook_uuid_table addObject:entry];
    [self saveAllItems];
    [self _printAllItems];
    
    return notebookUuid;
}

+ (BOOL)isDigitalNote:(NSString *)notebookId
{
    
    NSString *noteUUID = [notebookId stringByDeletingPathExtension];
    NSArray *numbers = [noteUUID componentsSeparatedByString:@"_"];
    
    NSUInteger firstTerm = [(NSString *)numbers[0] integerValue];
    
    if(firstTerm == kNOTEBOOK_ID_DIGITAL)
        return YES;
    
    return NO;
}

+ (NSString *)createUuid
{
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYYMMddHHmmss"];
    NSString *uuid_date = [formatter stringFromDate:[NSDate date]];
    NSString *uuid_rnd = [NJNotebookIdStore _createRandom6];
    NSString *uuid = [NSString stringWithFormat:@"%@_%@",uuid_date,uuid_rnd];
    
    return uuid;
}


+ (NSString *)_createRandom6
{
    int count = 0;
    NSMutableString *rndStr = [[NSMutableString alloc] initWithCapacity:5];
    
    BOOL number;
    char gen;
    
    while(count++ < 5) {
        
        number = arc4random() % 2;
        if(number)
            gen = '0' + (arc4random() % 10);
        else
            gen = 'A' + (arc4random() % 24);
        
        [rndStr appendString:[NSString stringWithFormat:@"%c",gen]];
    }
    
    return rndStr;
}
@end




static NSString * const kNoteobookIdEntryNoteType =         @"njnotebookId_note_type";
static NSString * const kNoteobookIdEntryNoteUUID =         @"njnotebookId_note_uuid";

@implementation NJNotebookIdEntry

- (id)init
{
    self = [super init];
    
    if(self) {
        
        
    }
    return self;
}





- (id)initWithCoder:(NSCoder *)aDecoder
{
    
    self = [super init];
    
    if(self) {
        [self setNoteType:[aDecoder decodeIntegerForKey:kNoteobookIdEntryNoteType]];
        [self setUUID:[aDecoder decodeObjectForKey:kNoteobookIdEntryNoteUUID]];
    }
    
    return self;
}




- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:_noteType forKey:kNoteobookIdEntryNoteType];
    [aCoder encodeObject:_UUID forKey:kNoteobookIdEntryNoteUUID];
}


@end
