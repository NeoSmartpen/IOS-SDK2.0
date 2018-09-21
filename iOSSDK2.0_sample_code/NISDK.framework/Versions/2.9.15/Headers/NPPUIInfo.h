//
//  NeoPUIInfo.h
//  NISDK
//
//  Created by NamSang on 12/01/2016.
//  Copyright © 2017 Neolabconvergence. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM (NSInteger, PUICmdType) {
    PUICmdTypeNone,
    PUICmdTypeEmail,
    PUICmdTypeActivity,
    PUICmdTypeAlarm,
    PUICmdTypeCustom
};

typedef NS_ENUM (NSInteger, PUIShape) {
    PUIShapeRectangle,
    PUIShapeCircle,
    PUIShapeStar
};


@interface NPPUIInfo : NSObject

@property (nonatomic) PUICmdType cmdType;
@property (nonatomic) PUIShape shape;
@property (nonatomic) CGFloat startX;
@property (nonatomic) CGFloat startY;
@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat height;
@property (strong, nonatomic) NSString *extraInfo;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *action;
@property (strong, nonatomic) NSString *param;


@end
