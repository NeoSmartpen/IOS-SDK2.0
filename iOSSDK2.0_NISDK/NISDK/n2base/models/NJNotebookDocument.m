//
//  NJNotebookDocument.m
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJNotebookDocument.h"
#import "NJNotebook.h"

@implementation NJNotebookDocument

- (id) initWithFileURL:(NSURL *)url{
    self = [super initWithFileURL:url];
    if(!self) {
        return nil;
    }
    
    return self;
}

- (void) setNotebook:(NJNotebook *)notebook
{
    _notebook = notebook;
}

- (BOOL) readFromURL:(NSURL *)url error:(NSError *__autoreleasing *)outError
{
    int dataLocation=0;
    
    self.notebook = [[NJNotebook alloc] init];
    NSString *path = [[url path] stringByAppendingPathComponent:@"notebook.data"];
    NSData *contents = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:path]];
    
    int dataLength = (int)[contents length];
    
    if (dataLength < sizeof(Float32)*2) {

        return YES;
    }
    //notebook title
    NSRange range = {0, sizeof(UInt32)};
    UInt32 sizeData;
    [contents getBytes:&sizeData range:range];
    
    dataLocation += sizeof(UInt32);
    range.location=dataLocation;
    range.length=sizeData;
    unsigned char titleDataBytes[sizeData];
    [contents getBytes:&titleDataBytes range:range];
    NSData *titleData = [NSData dataWithBytes:(const void*)titleDataBytes length:sizeData];
    self.notebook.title = [[NSString alloc] initWithData:titleData encoding:NSUTF8StringEncoding];
    dataLocation += sizeData;

    //notebook image name
    range.location = dataLocation;
    range.length = sizeof(UInt32);
    [contents getBytes:&sizeData range:range];
    
    dataLocation += sizeof(UInt32);
    range.location=dataLocation;
    range.length=sizeData;
    unsigned char imageNameDataBytes[sizeData];
    [contents getBytes:&imageNameDataBytes range:range];
    NSData *imageNameData = [NSData dataWithBytes:(const void*)imageNameDataBytes length:sizeData];
    self.notebook.imageName = [[NSString alloc] initWithData:imageNameData encoding:NSUTF8StringEncoding];
    dataLocation += sizeData;

    //notebook guid name
    range.location = dataLocation;
    range.length = sizeof(UInt32);
    [contents getBytes:&sizeData range:range];
    
    dataLocation += sizeof(UInt32);
    range.location=dataLocation;
    range.length=sizeData;
    unsigned char guidDataBytes[sizeData];
    [contents getBytes:&guidDataBytes range:range];
    NSData *guidData = [NSData dataWithBytes:(const void*)guidDataBytes length:sizeData];
    self.notebook.guid = [[NSString alloc] initWithData:guidData encoding:NSUTF8StringEncoding];
    dataLocation += sizeData;
    
    UInt64 ctimeInterval;
    range.location =dataLocation;
    range.length = sizeof(UInt64);
    [contents getBytes:&ctimeInterval range:range];
    dataLocation += sizeof(UInt64);
    self.notebook.cTime = [self convertIntervalToNSDate:ctimeInterval];
    
    UInt64 mtimeInterval;
    range.location =dataLocation;
    range.length = sizeof(UInt64);
    [contents getBytes:&mtimeInterval range:range];
    dataLocation += sizeof(UInt64);
    self.notebook.mTime = [self convertIntervalToNSDate:mtimeInterval];
    
    UInt64 atimeInterval;
    range.location =dataLocation;
    range.length = sizeof(UInt64);
    [contents getBytes:&atimeInterval range:range];
    dataLocation += sizeof(UInt64);
    self.notebook.aTime = [self convertIntervalToNSDate:atimeInterval];
    
    range.location=dataLocation;
    range.length=sizeof(UInt32);
    [contents getBytes:&sizeData range:range];
    dataLocation += sizeof(UInt32);
    
    range.location=dataLocation;
    range.length=sizeData;
    unsigned char pageArrayBytes[sizeData];
    [contents getBytes:&pageArrayBytes range:range];
    dataLocation += sizeData;
    self.notebook.pageArray = [[NSMutableArray alloc] init];
    for (int i = 0 ; i < sizeData ; i++) {
        [self.notebook.pageArray addObject:[NSNumber numberWithInt:pageArrayBytes[i]]];
    }

    return YES;
}

- (void) saveToURL:(NSURL *)url forSaveOperation:(UIDocumentSaveOperation)saveOperation completionHandler:(void (^)(BOOL))completionHandler
{
    __block NSError *error = nil;

    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:[url path]] ||
        [fm createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error])
    {
        NSString *path = [[url path] stringByAppendingPathComponent:@"notebook.data"];
        NSMutableData *notebookData = [[NSMutableData alloc] init];
        
        NSData* titleData = [self.notebook.title dataUsingEncoding:NSUTF8StringEncoding];
        //title data size
        UInt32 sizeData = (UInt32)[titleData length];
        [notebookData appendBytes:&sizeData length:sizeof(UInt32)];
        //title data
        unsigned char *titleDataBytes = (unsigned char *)[titleData bytes];
        [notebookData appendBytes:titleDataBytes length:[titleData length]];
        
        NSData* imageNameData = [self.notebook.imageName dataUsingEncoding:NSUTF8StringEncoding];
        //imageName data size
        sizeData = (UInt32)[imageNameData length];
        [notebookData appendBytes:&sizeData length:sizeof(UInt32)];
        //imageName data
        unsigned char *imageNameDataBytes = (unsigned char *)[imageNameData bytes];
        [notebookData appendBytes:imageNameDataBytes length:[imageNameData length]];
        
        NSData* guidData = [self.notebook.guid dataUsingEncoding:NSUTF8StringEncoding];
        //guid data size
        sizeData = (UInt32)[guidData length];
        [notebookData appendBytes:&sizeData length:sizeof(UInt32)];
        //guid data
        unsigned char *guidDataBytes = (unsigned char *)[guidData bytes];
        [notebookData appendBytes:guidDataBytes length:[guidData length]];
        
        UInt64 ctimeInterval = [self.notebook.cTime timeIntervalSince1970];
        [notebookData appendBytes:&ctimeInterval length:sizeof(UInt64)];
        UInt64 mtimeInterval = [self.notebook.mTime timeIntervalSince1970];
        [notebookData appendBytes:&mtimeInterval length:sizeof(UInt64)];
        UInt64 atimeInterval = [self.notebook.aTime timeIntervalSince1970];
        [notebookData appendBytes:&atimeInterval length:sizeof(UInt64)];
        
        UInt32 count = (int)[self.notebook.pageArray count];
        [notebookData appendBytes:&count length:sizeof(UInt32)];
        
        unsigned char pageArrayByte[count];
        for (int i = 0 ; i < count ; i++) {
            pageArrayByte[i] = [[self.notebook.pageArray objectAtIndex:i] intValue];
        }
        [notebookData appendBytes:pageArrayByte length:count];
        
        [fm createFileAtPath:path contents:notebookData attributes:nil];
        [self updateChangeCount:UIDocumentChangeCleared];
        
        NSLog(@"notebook saveToURL saved");
    }
}

- (NSDate *)convertIntervalToNSDate:(UInt64)interval
{
    NSTimeInterval timeInterval = (double)interval;
    
    NSDate *time = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    
    return  time;
}
@end
