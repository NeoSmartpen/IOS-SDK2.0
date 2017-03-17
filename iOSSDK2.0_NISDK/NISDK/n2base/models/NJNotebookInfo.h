//
//  NJNotebookInfo.h
//  NISDK
//
//  Created by NamSSan on 10/08/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NJNotebookInfo : NSObject <NSCoding>


@property (nonatomic) NSUInteger notebookId;
@property (nonatomic) NSUInteger totNoPages;
@property (nonatomic, copy) NSString *notebookTitle;
@property (nonatomic, strong) NSDate *lastModifiedDate;
@property (nonatomic, strong) NSDate *createdDate;
@property (nonatomic, strong) NSDate *archivedDate;
@property (nonatomic, strong) UIImage *coverImage;



@end
