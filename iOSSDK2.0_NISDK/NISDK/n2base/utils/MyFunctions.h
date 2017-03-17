//
//  MyFunctions.h
//  NISDK
//
//  Created by NamSSan on 14/05/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MyFunctions : NSObject

+ (NSString *)generatePageStr:(NSArray *)array;
+(NSDate*)normalizedDateWithDate:(NSDate*)date;

+ (NSDate *)convertDateFromString:(NSString *)strDate;
+ (NSString *)convertDateFromDateOjbect:(NSDate *)date;
+ (NSString *)convertDateFromDateOjbectWithShortStyle:(NSDate *)date;
+ (NSInteger)daysBetween:(NSDate *)dt1 and:(NSDate *)dt2;
+ (NSString *)stringDescForDateDifferenceFrom:(NSDate *)from to:(NSDate *)to forShortStyle:(BOOL)shortStyle;




// Image Related
+ (UIImage*) blur:(UIImage*)theImage withInputRadius:(float)input;
+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;


// create PDF
+(NSData *)createPDF:(NSString*)fileName notebookId:(NSUInteger)noteId imgArray:(NSArray *)imgArray;
+(NSString*)getPDFFileName;


// color
+ (UInt32)convertUIColorToAlpahRGB:(UIColor *)color;



+ (NSString *) appVersion;
+ (NSString *) versionBuild;

+ (NSString *)loadPasswd;
+ (void)saveIntoKeyChainWithPasswd:(NSString *)passwd;
+ (void)deleteKeyChain;

@end
