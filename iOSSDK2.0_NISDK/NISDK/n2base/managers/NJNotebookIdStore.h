//
//  NJNotebookNameStore.h
//  NISDK
//
//  Created by NamSSan on 17/09/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NJNotebookIdStore : NSObject
{
    
    NSMutableArray *_notebook_uuid_table;
}


+ (NJNotebookIdStore *)sharedStore;
+ (NSString *)createUUID;
+ (BOOL)isDigitalNote:(NSString *)notebookId;


- (NSString *)notebookIdName:(NSUInteger)notebookId;
@end
