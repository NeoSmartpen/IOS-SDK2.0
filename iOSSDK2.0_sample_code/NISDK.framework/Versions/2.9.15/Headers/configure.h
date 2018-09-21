//
//  configure.h
//  NISDK
//
//  Created by NamSSan on 12/05/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#ifndef NeoJournal_configure_h
#define NeoJournal_configure_h


static inline BOOL isEmpty(id thing) {
    return (thing == nil  || [thing isKindOfClass:[NSNull class]] || ([thing respondsToSelector:@selector(length)] && [(NSData *)thing length] == 0) || ([thing respondsToSelector:@selector(count)] && [(NSArray *)thing count] == 0));
}



#define NSLocalizedFormatString(fmt, ...) [NSString stringWithFormat:NSLocalizedString(fmt, nil), __VA_ARGS__]

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]



#define kNOTEBOOK_ID_DIGITAL        0
#define kNOTEBOOK_ID_START_DIGITAL  900
#define kNOTEBOOK_ID_START_REAL     000
#define IS_OS_9_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 9.0)

#define STROKE_NUMBER_MAGNITUDE 4

// event log types
typedef enum {
    
    LOGTYPE_LASTSTROKE,
    LOGTYPE_WEATHER,
    LOGTYPE_SYNC,
    LOGTYPE_SHARE,
    LOGTYPE_CREATE,
    LOGTYPE_COPY,
    LOGTYPE_DELETE
    
} kEVENT_LOGTYPE;


// event action modes
typedef enum {
    
    ACTIONMODE_REALTIME,
    ACTIONMODE_OFFLINE,
    ACTIONMODE_OPERATION
    
} kEVENT_ACTIONMODE;



// event action modes
typedef enum {
    
    SHARE_FACEBOOK,
    SHARE_TWITTER,
    SHARE_KAKAO,
    SHARE_FLICKR,
    SHARE_EMAIL,
    SHARE_MESSAGE
    
} kEVENT_SHARE;




static unsigned kCalUnits = NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit | NSWeekdayCalendarUnit;


static NSString * const kBaseURLString =    @"http://peopleinhoju.com/app_pointsplus";


static unsigned int const kWEATHER_CODE_SKYCLEAR =          0;
static unsigned int const kWEATHER_CODE_FEWCLOUDS =         1;
static unsigned int const kWEATHER_CODE_SCATTEREDCLOUDS =   2;
static unsigned int const kWEATHER_CODE_BROKENCLOUDS =      3;
static unsigned int const kWEATHER_CODE_SHOWERRAIN =        4;
static unsigned int const kWEATHER_CODE_RAIN =              5;
static unsigned int const kWEATHER_CODE_THUNDERSTORM =      6;
static unsigned int const kWEATHER_CODE_SNOW =              7;
static unsigned int const kWEATHER_CODE_MIST =              8;







//Notifications

static NSString * const NJPageListTapGestureNotification = @"NJPageListTapGestureNotification";
static NSString * const NJOfflineSyncCompleteNotification = @"NJOfflineSyncCompleteNotification";
static NSString * const NJSlidingOfflineSyncNotebookCompleteNotification = @"NJSlidingOfflineSyncNotebookCompleteNotification";


#endif
