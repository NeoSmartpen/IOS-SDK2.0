//
//  NJVoiceMemo.h
//  NISDK
//
//  Created by Heogun You on 16/06/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJMedia.h"

typedef enum {
    VOICEMEMO_START = 0,
    VOICEMEMO_PAGE_CHANGING,
    VOICEMEMO_PAGE_CHANGED,
    VOICEMEMO_END
}NeoVoiceMemoStatus;

@interface NJVoiceMemo : NJMedia
@property (strong, nonatomic) NSString *fileName;
@property (nonatomic) UInt64 startTime;
@property (nonatomic) NeoVoiceMemoStatus status;
@property (nonatomic) UInt32 noteId;
@property (nonatomic) UInt32 pageNumber;

+ (NJVoiceMemo *) voiceMemoWithFileName:(NSString *)name andTime:(UInt64)time;
+ (NJVoiceMemo *) voiceMemoFromData:(NSData *)data at:(int *)position;
@end
