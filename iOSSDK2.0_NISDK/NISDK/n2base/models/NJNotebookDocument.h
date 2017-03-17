//
//  NJNotebookDocument.h
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NJNotebook;
@interface NJNotebookDocument : UIDocument

@property (strong, nonatomic) NJNotebook *notebook;

- (id) initWithFileURL:(NSURL *)url;
@end
