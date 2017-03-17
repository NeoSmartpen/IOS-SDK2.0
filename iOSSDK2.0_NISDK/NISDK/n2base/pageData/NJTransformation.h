//
//  NJNode.h
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NJTransformation : NSObject

@property float offset_x;
@property float offset_y;
@property float scale;

- (id) initWithOffsetX:(float)x offsetY:(float)y scale:(float)scale;
- (float) applyX:(float) x;
- (float) applyY:(float) y;
- (float) inverseX:(float) x;
- (float) inverseY:(float) y;
- (void)setValueWithTransformation:(NJTransformation *)t;
@end
