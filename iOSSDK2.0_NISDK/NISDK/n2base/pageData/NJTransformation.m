//
//  NJNode.m
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJTransformation.h"

@implementation NJTransformation

- (instancetype) init
{
    self = [super init];
    if (!self) {
        return nil;
    }
    self.offset_x = 0.0f;
    self.offset_y = 0.0f;
    self.scale = 1.0f;
    return self;
}
- (id) initWithOffsetX:(float)x offsetY:(float)y scale:(float)scale;
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.offset_x = x;
    self.offset_y = y;
    self.scale = scale;
    
    return self;
}
- (float) applyX:(float) x
{
    return x * _scale + _offset_x;
}
- (float) applyY:(float) y
{
    return y * _scale + _offset_y;
}
- (float) inverseX:(float) x
{
    return (x - _offset_x) / _scale;
}
- (float) inverseY:(float) y
{
    return (y - _offset_y) / _scale;
}
- (void)setValueWithTransformation:(NJTransformation *)t
{
    _offset_x = t.offset_x;
    _offset_y = t.offset_y;
    _scale = t.scale;
}
- (BOOL) isEqual:(id)object
{
    if ([object isKindOfClass:[NJTransformation class]]) {
        NJTransformation *t = (NJTransformation *)object;
        return (_offset_x == t.offset_x) && (_offset_y == t.offset_y) && (_scale == t.scale);
    }
    return NO;
}
@end
