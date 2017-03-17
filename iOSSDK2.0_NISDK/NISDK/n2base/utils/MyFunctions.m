//
//  MyFunctions.m
//  NISDK
//
//  Created by NamSSan on 14/05/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "MyFunctions.h"
#import "configure.h"
#import "KeychainItemWrapper.h"

@implementation MyFunctions



+ (NSString *)generatePageStr:(NSArray *)array
{
    if(isEmpty(array)) return @"";
    
    int index = 0;
    NSString *formatStr;
    NSMutableString *pageStr = [[NSMutableString alloc] init];
    
    for(NSString *pageName in array) {
        
        if(index++ == 0)
            formatStr = @"%d";
        else
            formatStr = @",%d";
        
        [pageStr appendString:[NSString stringWithFormat:formatStr,[pageName intValue]]];
    }
    
    return pageStr;
}

+ (NSDate*)normalizedDateWithDate:(NSDate*)date
{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    
    NSDateComponents* components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate: date];
    
    return [calendar dateFromComponents:components];
}



+ (NSDate *)convertDateFromString:(NSString *)strDate
{
    //Create a formatter
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    //Set the format & TimeZone - essential as otherwise the time component wont be used
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    //Create your NSDate
    NSDate *date = [formatter dateFromString:strDate];
    //NSLog(@"sd %@", date);
    
    return date;
}



+ (NSString *)convertDateFromDateOjbect:(NSDate *)date
{
    if(isEmpty(date)) return nil;
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    /*
     [formatter setDateStyle:NSDateFormatterShortStyle];
     [formatter setTimeStyle:NSDateFormatterShortStyle];
     [formatter setDoesRelativeDateFormatting:YES];
     */
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *strDate = [formatter stringFromDate:date];
    
    return strDate;
}


+ (NSString *)convertDateFromDateOjbectWithShortStyle:(NSDate *)date
{
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    /*
     [formatter setDateStyle:NSDateFormatterShortStyle];
     [formatter setTimeStyle:NSDateFormatterShortStyle];
     [formatter setDoesRelativeDateFormatting:YES];
     */
    [formatter setDateFormat:@"dd-MMM-YY HH:mm"];
    NSString *strDate = [formatter stringFromDate:date];
    
    return strDate;
}


+ (NSInteger)daysBetween:(NSDate *)dt1 and:(NSDate *)dt2
{
    
    
    NSUInteger unitFlags = NSDayCalendarUnit;
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [calendar components:unitFlags fromDate:dt1 toDate:dt2 options:0];
    NSInteger daysBetween = abs((int)[components day]);
    
    return daysBetween+1;
}


+ (NSString *)stringDescForDateDifferenceFrom:(NSDate *)from to:(NSDate *)to forShortStyle:(BOOL)shortStyle
{
    
    // set date/time label -- we have now most recently updated page info
    NSUInteger unitFlags =  NSSecondCalendarUnit | NSMinuteCalendarUnit | NSHourCalendarUnit| NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit;
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *comp = [calendar components:unitFlags fromDate:from toDate:to options:0];
    
    NSString *unitStr;
    NSInteger diff = 0;
    
    if(shortStyle) {
      
        if(comp.year > 0 || comp.month > 0 || comp.day > 0) {
        
            return [NSDateFormatter localizedStringFromDate:from
                                           dateStyle:NSDateFormatterMediumStyle
                                           timeStyle:NSDateFormatterNoStyle];
            
        }
    }
    
    if(comp.year > 0) {
        
        diff = comp.year;
        unitStr = @"year";
        
    } else {
        
        
        if(comp.month > 0) {
            
            diff = comp.month;
            unitStr = @"month";
            
        } else {
            
            if(comp.day > 0) {
                
                diff = comp.day;
                unitStr = @"day";
                
            } else {
                
                if(comp.hour > 0) {
                    
                    diff = comp.hour;
                    //unitStr = @"hour";
                    unitStr = NSLocalizedString(@"MSC_TIME_FRMT_HOURS", nil);
                    
                } else {
                    
                    if(comp.minute > 0) {
                        
                        diff = comp.minute;
                        //unitStr = @"minute";
                        unitStr = NSLocalizedString(@"MSC_TIME_FRMT_MINUTES", nil);
                        
                    } else {
                        diff = comp.second;
                        //unitStr = @"second";
                        unitStr = NSLocalizedString(@"MSC_TIME_FRMT_SECONDS", nil);
                    }
                }
                
            }
        }
    }
    
    
    return NSLocalizedFormatString(unitStr,diff);
    //return [NSString stringWithFormat:@"%ld %@%@ ago",diff,unitStr,(diff > 1)? @"s":@""];
}



+ (UIImage*) blur:(UIImage*)theImage withInputRadius:(float)input
{
    @autoreleasepool {
    // create our blurred image
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [CIImage imageWithCGImage:theImage.CGImage];
    
    // setting up Gaussian Blur (we could use one of many filters offered by Core Image)
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:[NSNumber numberWithFloat:input] forKey:@"inputRadius"];
    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    
    
    // CIGaussianBlur has a tendency to shrink the image a little,
    // this ensures it matches up exactly to the bounds of our original image
    CGImageRef cgImage = [context createCGImage:result fromRect:[inputImage extent]];
    
    UIImage *returnImage = [UIImage imageWithCGImage:cgImage];//create a UIImage for this function to "return" so that ARC can manage the memory of the blur... ARC can't manage CGImageRefs so we need to release it before this function "returns" and ends.
    CGImageRelease(cgImage);//release CGImageRef because ARC doesn't manage this on its own.
    
    return returnImage;
    }
}



+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}










typedef struct {
    int note_id;
    int width;
    int heght;
} NotebookPDFSizeType;

NotebookPDFSizeType notebookPDFSizeTypeArray[] = {
    {1, 420, 595},   // Season Notebook Default Note
    {101, 499, 709}, // Neo1 Large
    {102, 420, 595},  // Neo1 Medium
    {103, 249, 354}, // Neo1 Small
    {201, 510, 680}, // SnowCat Large
    {202, 420, 595},  // SnowCat Medium
    {203, 340, 476},   // SnowCat Small
    {301, 499, 709}, // Neo Basic 01"
    {302, 499, 709}, // Neo Basic 02"
    {303, 499, 709}, // Neo Basic 03"
};


+(NSData *)createPDF:(NSString*)fileName notebookId:(NSUInteger)noteId imgArray:(NSArray *)imgArray
{
    
    if(isEmpty(imgArray)) return nil;
    
    CGFloat width=0, height=0;
    
    int infoSize = sizeof(notebookPDFSizeTypeArray)/sizeof(NotebookPDFSizeType);
    
    for (int i = 0; i < infoSize; i++) {
        
        NotebookPDFSizeType info = notebookPDFSizeTypeArray[i];
        
        if (info.note_id == (int)noteId) {
            width = info.width;
            height = info.heght;
            break;
        }
        
    }
    // Create the PDF context using the default page size of 612 x 792.
    UIGraphicsBeginPDFContextToFile(fileName, CGRectZero, nil);
    
    
    for(UIImage *img in imgArray) {
        
        UIGraphicsBeginPDFPageWithInfo(CGRectMake(0, 0, width, height), nil);
        [img drawInRect:CGRectMake(0, 0, width, height)];
        
    }
    
    UIGraphicsEndPDFContext();
    
    
    NSData *pdfData = [NSData dataWithContentsOfFile:fileName];
    
    return pdfData;
}



+(NSString*)getPDFFileName
{
    NSString* fileName = @"image.PDF";
    
    NSArray *arrayPaths =
    NSSearchPathForDirectoriesInDomains(
                                        NSDocumentDirectory,
                                        NSUserDomainMask,
                                        YES);
    NSString *path = [arrayPaths objectAtIndex:0];
    NSString* pdfFileName = [path stringByAppendingPathComponent:fileName];
    
    return pdfFileName;
    
}











+ (UInt32)convertUIColorToAlpahRGB:(UIColor *)color
{
    const CGFloat* components = CGColorGetComponents(color.CGColor);
    NSLog(@"Red: %f", components[0]);
    NSLog(@"Green: %f", components[1]);
    NSLog(@"Blue: %f", components[2]);
    NSLog(@"Alpha: %f", CGColorGetAlpha(color.CGColor));
    
    CGFloat colorRed = components[0];
    CGFloat colorGreen = components[1];
    CGFloat colorBlue = components[2];
    CGFloat colorAlpah = 1.0f;
    UInt32 alpah = (UInt32)(colorAlpah * 255) & 0x000000FF;
    UInt32 red = (UInt32)(colorRed * 255) & 0x000000FF;
    UInt32 green = (UInt32)(colorGreen * 255) & 0x000000FF;
    UInt32 blue = (UInt32)(colorBlue * 255) & 0x000000FF;
    UInt32 penColor = (alpah << 24) | (red << 16) | (green << 8) | blue;
    
    return penColor;
}











+ (NSString *) appVersion
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
}


+ (NSString *) build
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
}



+ (NSString *) versionBuild
{
    NSString * version = [self appVersion];
    //NSString * build = [self build];
    
    NSString * versionBuild = [NSString stringWithFormat: @"v%@", version];
    
    /*
     if (![version isEqualToString: build]) {
     //versionBuild = [NSString stringWithFormat: @"%@(%@)", versionBuild, build];
     versionBuild = [NSString stringWithFormat:@"%@.%@",version,build];
     }
     */
    
    
    return versionBuild;
}

+ (KeychainItemWrapper *)getKeyChainItemWrapper
{
    
    KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:@"Pen_Password" accessGroup:nil];
    
    return keychain;
}

+ (NSString *)loadPasswd
{
    KeychainItemWrapper *keychain = [self getKeyChainItemWrapper];
    
    NSString *passwd = [keychain objectForKey:(__bridge id)(kSecValueData)];
    
    return passwd;
}

+ (void)saveIntoKeyChainWithPasswd:(NSString *)passwd
{
    
    KeychainItemWrapper *keychain = [self getKeyChainItemWrapper];
    
    // store user email & password for next automatic login
    [keychain setObject:@"neo lab convergence" forKey:(__bridge id)kSecAttrService];
    [keychain setObject:@"neo note pen" forKey:(__bridge id)kSecAttrAccount];
    [keychain setObject:passwd forKey:(__bridge id)kSecValueData];
    
    NSLog(@"Key chain Saved");
    
}

+ (void)deleteKeyChain
{
    
    // remove keychainItem to prevent automatic logain from next time
    KeychainItemWrapper *keychain = [self getKeyChainItemWrapper];
    [keychain resetKeychainItem];
}

@end
