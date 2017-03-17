//
//  NJNode.m
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJNode.h"

@implementation NJNode
@synthesize x = _x;
@synthesize y = _y;
@synthesize pressure = _pressure;

- (id) initWithPointX:(float)x poinY:(float)y pressure:(float)pressure
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.x = x;
    self.y = y;
    self.pressure = pressure;
    
    return self;
}
@end
