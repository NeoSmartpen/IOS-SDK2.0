//
//  NJNode.h
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NJNode : NSObject

@property float x;
@property float y;
@property float pressure;
@property unsigned char timeDiff;

- (id) initWithPointX:(float)x poinY:(float)y pressure:(float)pressure;

@end
