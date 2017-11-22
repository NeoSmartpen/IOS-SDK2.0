//
//  NJMedia.h
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NJTransformation;

typedef enum {
    MEIDA_NONE = -1,
    MEDIA_STROKE = 0,
    MEDIA_VOICE
} NeoMediaType;

typedef enum {
    MEDIA_RENDER_STROKE = 0,
    MEDIA_RENDER_REPLAY_VOICE,        // voice replay
    MEDIA_RENDER_REPLAY_PREVIEW_VOICE,      // replay preview for voice
    MEDIA_RENDER_REPLAY_READY_VOICE,  // initial screen of replay voice memo started == all stroke with green
    MEDIA_RENDER_REPLAY_READY_STROKE  // replay stroke only started == blank
} NeoMediaRenderingMode;

@interface NJMedia : NSObject {
}
@property NeoMediaType type;

- (BOOL) readValueFromData:(NSData *)data to:(void *)buffer at:(int *)position length:(int)length;
- (BOOL) writeMediaToData:(NSMutableData *)data;
- (void)setTransformation:(NJTransformation *)transformation;
@end
