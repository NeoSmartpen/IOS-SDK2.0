//
//  NJNotebook.h
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NJNotebook : NSObject

@property (strong, nonatomic) NSString *title;
@property (strong, nonatomic) NSString *imageName;
@property (strong, nonatomic) NSString *guid;
@property (strong, nonatomic) NSDate *cTime;
@property (strong, nonatomic) NSDate *mTime;
@property (strong, nonatomic) NSDate *aTime;
@property (strong, nonatomic) NSMutableArray *pageArray;
- (id) initWithNoteId:(NSUInteger)nId;
@end
