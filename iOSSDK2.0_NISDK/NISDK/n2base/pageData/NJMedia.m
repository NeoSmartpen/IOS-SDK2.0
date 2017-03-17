//
//  NJMedia.m
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJMedia.h"

@interface NJMedia(){
}
@end
@implementation NJMedia
- (instancetype) init
{
    self = [super init];
    if (self == nil) return nil;
    
    self.type = MEIDA_NONE;
    return self;
}

- (BOOL) readValueFromData:(NSData *)data to:(void *)buffer at:(int *)position length:(int)length
{
    if (data.length < (*position + length)) {
        return NO;
    }
    NSRange range = {*position, length};
    [data getBytes:buffer range:range];
    *position += length;
    return YES;
}
- (BOOL) writeMediaToData:(NSMutableData *)data
{
    return YES;
}
- (void)setTransformation:(NJTransformation *)transformation
{
    
}
@end
