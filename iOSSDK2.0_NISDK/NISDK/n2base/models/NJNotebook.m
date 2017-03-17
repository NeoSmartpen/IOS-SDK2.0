//
//  NJNotebook.m
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJNotebook.h"

@implementation NJNotebook

- (id) initWithNoteId:(NSUInteger)nId
{
    self = [super init];
    if(!self) {
        return nil;
    }

    [self notebookInformationInit:nId];
    
    return self;
}

- (void) notebookInformationInit:(NSUInteger)nId
{
    NSString *notebookTitle;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    BOOL notebookInfoInit = [defaults boolForKey:@"notebookInfoInit"];
        
            NSUInteger type = nId;
            switch (type) {
                    
                case 1:
                    notebookTitle = @"Season Note";
                    break;
                case 101:
                    notebookTitle = @"Neo Premium Black";
                    break;
                case 102:
                    notebookTitle = @"Neo Premium White";
                    break;
                case 103:
                    notebookTitle = @"Neo Premium Red";
                    break;
                case 201:
                    notebookTitle = @"Snow Cat L";
                    break;
                case 202:
                    notebookTitle = @"Snow Cat M";
                    break;
                case 203:
                    notebookTitle = @"Snow Cat S";
                    break;
                case 301:
                    notebookTitle = @"Neo Basic 01";
                    break;
                case 302:
                    notebookTitle = @"Neo Basic 02";
                    break;
                case 303:
                    notebookTitle = @"Neo Basic 03";
                    break;
                case 898:
                    notebookTitle = @"Smart Pen 101";
                    break;
                case 899:
                    notebookTitle = @"Smart Pen 102";
                    break;
                case 900:
                    notebookTitle = @"Smart Pen 103";
                    break;
                default:
                    notebookTitle = [NSString stringWithFormat:@"Digital Notebook%02d", (int)type - 900];                    
                    break;
            }
            self.title = notebookTitle;
            self.guid = @"";
            self.cTime  = [NSDate date];
            self.mTime = self.cTime;
            self.aTime = self.mTime;
            self.pageArray = [[NSMutableArray alloc] init];
    
        notebookInfoInit = YES;
        [defaults setBool:notebookInfoInit forKey:@"notebookInfoInit"];
        [defaults synchronize];
}

@end
