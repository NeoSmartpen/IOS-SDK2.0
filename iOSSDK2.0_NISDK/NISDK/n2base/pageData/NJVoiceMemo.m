//
//  NJVoiceMemo.m
//  NISDK
//
//  Created by Heogun You on 16/06/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJVoiceMemo.h"

#define FILENAME_BUFFER_LENGTH 45 // UUID string length = 32(alpha value) + 4(dash) + 1(.) + 3(m4a) + 5(null)
#define FILENAME_LENGTH 40

@implementation NJVoiceMemo
- (instancetype) init
{
    self = [super init];
    if (self == nil) return nil;
    self.type = MEDIA_VOICE;
    self.fileName = @"";
    self.startTime = 0;
    return self;
}
+ (NJVoiceMemo *) voiceMemoWithFileName:(NSString *)name andTime:(UInt64)time
{
    NJVoiceMemo *vm = [[NJVoiceMemo alloc] init];
    if (vm == nil) return nil;
    
    vm.fileName = name;
    vm.startTime = time;
    return vm;
}
+ (NJVoiceMemo *) voiceMemoFromData:(NSData *)data at:(int *)position
{
    NJVoiceMemo *voice = [[NJVoiceMemo alloc] init];
    if (voice == nil) return nil;
    [voice initFromData:data at:position];
    return voice;
}
- (BOOL) initFromData:(NSData *)data at:(int *)position
{
    char fileName[FILENAME_BUFFER_LENGTH] = {0,};
    unsigned char status;
    *position += 1; //skip type
    [self readValueFromData:data to:&_startTime at:position length:sizeof(UInt64)];
    [self readValueFromData:data to:fileName at:position length:FILENAME_LENGTH];
    self.fileName = [NSString stringWithCString:fileName encoding:NSASCIIStringEncoding];
    [self readValueFromData:data to:&status at:position length:sizeof(unsigned char)];
    self.status = (NeoVoiceMemoStatus)status;
    [self readValueFromData:data to:&_noteId at:position length:sizeof(UInt32)];
    [self readValueFromData:data to:&_pageNumber at:position length:sizeof(UInt32)];
    return YES;
}
- (BOOL) writeMediaToData:(NSMutableData *)data
{
    char fileName[FILENAME_BUFFER_LENGTH] = {0,};
    unsigned char kind = (unsigned char)MEDIA_VOICE;
    unsigned char status = (unsigned char)self.status;
    UInt64 time_stamp = self.startTime;
    [data appendBytes:&kind length:sizeof(unsigned char)];
    [data appendBytes:&time_stamp length:sizeof(UInt64)];
    const char *name = [self.fileName cStringUsingEncoding:NSASCIIStringEncoding];
    memcpy(fileName, name, FILENAME_LENGTH);
    [data appendBytes:fileName length:FILENAME_LENGTH];
    [data appendBytes:&status length:sizeof(unsigned char)];
    [data appendBytes:&_noteId length:sizeof(UInt32)];
    [data appendBytes:&_pageNumber length:sizeof(UInt32)];
    return YES;
}
@end
