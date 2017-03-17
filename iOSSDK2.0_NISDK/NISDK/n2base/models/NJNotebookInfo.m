//
//  NJNotebookInfo.m
//  NISDK
//
//  Created by NamSSan on 10/08/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJNotebookInfo.h"
//#import "NJCoverManager.h"
#import "configure.h"


#define kNotebookInfoNoteId             @"notoobkinfo_note_id"
#define kNotebookInfoTotNoPages         @"notoobkinfo_tot_num_pages"
#define kNotebookInfoNoteTitle          @"notoobkinfo_note_title"
#define kNotebookInfoCreatedDate        @"notoobkinfo_created_date"
#define kNotebookInfoLastModifiedDate   @"notoobkinfo_modified_date"
#define kNotebookInfoArchivedDate   @"notoobkinfo_archived_date"
#define kNotebookInfoCoverImage         @"notoobkinfo_cover_image"


@implementation NJNotebookInfo


- (id)init
{
    self = [super init];
    
    if(self) {
        
        
    }
    
    return self;
}



- (id)initWithCoder:(NSCoder *)aDecoder
{
    
    self = [super init];
    
    if(self) {
        
        [self setNotebookId:[aDecoder decodeIntegerForKey:kNotebookInfoNoteId]];
        [self setTotNoPages:[aDecoder decodeIntegerForKey:kNotebookInfoTotNoPages]];
        [self setNotebookTitle:[aDecoder decodeObjectForKey:kNotebookInfoNoteTitle]];
        [self setCreatedDate:[aDecoder decodeObjectForKey:kNotebookInfoCreatedDate]];
        [self setLastModifiedDate:[aDecoder decodeObjectForKey:kNotebookInfoLastModifiedDate]];
        [self setArchivedDate:[aDecoder decodeObjectForKey:kNotebookInfoArchivedDate]];
        [self setCoverImage:[aDecoder decodeObjectForKey:kNotebookInfoCoverImage]];

    }
    
    return self;
}




- (void)encodeWithCoder:(NSCoder *)aCoder
{
    
    [aCoder encodeInteger:_notebookId forKey:kNotebookInfoNoteId];
    [aCoder encodeInteger:_totNoPages forKey:kNotebookInfoTotNoPages];
    [aCoder encodeObject:_notebookTitle forKey:kNotebookInfoNoteTitle];
    [aCoder encodeObject:_createdDate forKey:kNotebookInfoCreatedDate];
    [aCoder encodeObject:_lastModifiedDate forKey:kNotebookInfoLastModifiedDate];
    [aCoder encodeObject:_archivedDate forKey:kNotebookInfoArchivedDate];
    [aCoder encodeObject:_coverImage forKey:kNotebookInfoCoverImage];
    
}



- (UIImage *)coverImage
{
    UIImage *image = _coverImage;
    
    if(isEmpty(image)) {
        
//        image = [NJCoverManager getCoverResourceImage:_notebookId];
        
    } else {
        
        NSLog(@"i have own image");
    }
    
    return image;
}



@end
