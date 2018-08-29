//
//  NJPenCommParser.h
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "NeoPenService.h"

#define SEAL_SECTION_ID 4

typedef void(^BATTERYMEMORY_BLOCK)(unsigned char remainedBattery, unsigned char usedMemory);

@class NJPage;
@protocol NJPenCommParserStrokeHandler <NSObject>
- (void) processStroke:(NSDictionary *)stroke;
- (void) activeNoteId:(int)noteId pageNum:(int)pageNumber sectionId:(int)section ownderId:(int)owner;
- (void) notifyPageChanging;
@optional
- (void) notifyDataUpdating:(BOOL)updating;
- (UInt32)setPenColor;
@end

@protocol NJPenCommParserCommandHandler <NSObject>
@optional
- (void) sendEmailWithPdf;
- (void) penConnectedByOtherApp:(BOOL)penConnected;
- (void) findApplicableSymbols:(NSString *)param action:(NSString *)action andName:(NSString *)name;
@end

@protocol NJPenCommParserPasswordDelegate <NSObject>
- (void) performComparePassword:(PenPasswordRequestStruct *)request;
@end

@class NJPage;
@protocol NJPenCommParserStartDelegate <NSObject>
- (void) activeNoteIdForFirstStroke:(int)noteId pageNum:(int)pageNumber sectionId:(int)section ownderId:(int)owner;
- (void) setPenCommNoteIdList;
@end

@class NJPenCommManager;
@class NJPageDocument;
@protocol NJOfflineDataDelegate;
@protocol NJPenCalibrationDelegate;
@protocol NJFWUpdateDelegate;
@protocol NJPenStatusDelegate;
@protocol NJPenPasswordDelegate;
@protocol NJPenStartDelegate;

@interface NJPenCommParser : NSObject
@property (weak, nonatomic) id <NJPenCommParserStrokeHandler> strokeHandler;
@property (weak, nonatomic) id <NJPenCommParserCommandHandler> commandHandler;
@property (nonatomic) BOOL shouldSendPageChangeNotification;
@property (weak, nonatomic) id <NJPenCommParserPasswordDelegate> passwordDelegate;
@property (weak, nonatomic) id <NJPenCommParserStartDelegate> canvasStartDelegate;

@property (strong, nonatomic) NSMutableDictionary *offlineFileList;
@property (nonatomic) unsigned char batteryLevel;
@property (nonatomic) unsigned char memoryUsed;
@property (nonatomic) NSUInteger penThickness;
@property (nonatomic, strong) NSString *fwVersion;
// Pen data related BTLE characteristics.
@property (nonatomic) BOOL penCommIdDataReady;
@property (nonatomic) BOOL penCommUpDownDataReady;
@property (nonatomic) BOOL penCommStrokeDataReady;
@property (nonatomic) BOOL penExchangeDataReady;
@property (nonatomic) BOOL penPasswordResponse;
@property (nonatomic) BOOL cancelFWUpdate;
@property (nonatomic) BOOL cancelOfflineSync;
@property (nonatomic) NSUInteger passwdCounter;
@property (strong, nonatomic) NJPageDocument *activePageDocument;
@property (nonatomic, strong)BATTERYMEMORY_BLOCK battMemoryBlock;
@property (nonatomic) float startX;
@property (nonatomic) float startY;
@property (strong, nonatomic) NSString *subNameStr;
@property (strong, nonatomic) NSString *protocolVerStr;
@property (nonatomic) BOOL requestNewPageNotification;

- (id) initWithPenCommManager:(NJPenCommManager *)manager;
- (void) parsePen2Data:(unsigned char *)data withLength:(int) length;
- (void) parsePenStrokeData:(unsigned char *)data withLength:(int) length;
- (void) parsePenUpDowneData:(unsigned char *)data withLength:(int) length;
- (void) parsePenNewIdData:(unsigned char *)data withLength:(int) length;
- (void) parsePenStatusData:(unsigned char *)data withLength:(int) length;
- (void) parseOfflineFileList:(unsigned char *)data withLength:(int) length;
- (void) parseOfflineFileListInfo:(unsigned char *)data withLength:(int) length;
- (void) parseOfflineFileInfoData:(unsigned char *)data withLength:(int) length;
- (void) parseOfflineFileData:(unsigned char *)data withLength:(int) length;
- (void) parseOfflineFileStatus:(unsigned char *)data withLength:(int) length;
- (void) parseRequestUpdateFile:(unsigned char *)data withLength:(int) length;
- (void) parseUpdateFileStatus:(unsigned char *)data withLength:(int) length;
- (void) parseFWVersion:(unsigned char *)data withLength:(int) length;
- (void) parseReadyExchangeDataRequest:(unsigned char *)data withLength:(int) length;
- (void) parsePenPasswordRequest:(unsigned char *)data withLength:(int) length;
- (void) parsePenPasswordChangeResponse:(unsigned char *)data withLength:(int) length;
- (BOOL) requestOfflineFileList;
- (void) setPenState;
- (void)setPenStateWithPenPressure:(UInt16)penPressure;
- (void)setPenStateWithAutoPwrOffTime:(UInt16)autoPwrOff;
- (void)setPenStateAutoPower:(unsigned char)autoPower Sound:(unsigned char)sound;
- (void)setPenStateWithRGB:(UInt32)color;
- (void)setPenStateWithTimeTick;
- (void)setNoteIdListFromPList;
- (void)setAllNoteIdList;
- (void)setNoteIdList;
- (void)setNoteIdListSectionOwnerFromPList;
- (void) setPassword:(NSString *)pinNumber;
- (void) changePasswordFrom:(NSString *)curNumber To:(NSString *)pinNumber;
- (void) setBTComparePassword:(NSString *)pinNumber;
- (void) writeReadyExchangeData:(BOOL)ready;
- (BOOL) requestOfflineDataWithOwnerId:(UInt32)onwerId noteId:(UInt32)noteId;
- (void) offlineFileAckForType:(unsigned char)type index:(unsigned char)index;
- (void)setPenStateWithHover:(UInt16)useHover;

- (void) calcDotScaleScreenW:(float)screenW screenH:(float)screenH;
- (BOOL) requestNextOfflineNote;
- (void) setOfflineDataDelegate:(id<NJOfflineDataDelegate>)offlineDataDelegate;
- (void) setPenCalibrationDelegate:(id<NJPenCalibrationDelegate>)penCalibrationDelegate;
- (void) setFWUpdateDelegate:(id<NJFWUpdateDelegate>)fwUpdateDelegate;
- (void) setPenStatusDelegate:(id<NJPenStatusDelegate>)penStatusDelegate;
- (void) setPenPasswordDelegate:(id<NJPenPasswordDelegate>)penPasswordDelegate;
- (void) sendUpdateFileInfoAtUrlToPen:(NSURL *)fileUrl;
- (float) processPressure:(float)pressure;
- (void) resetDataReady;

//SDK2.0
- (void)setDummyBytes;
- (void)setVersionInfo;
- (void)setComparePasswordSDK2:(NSString *)pinNumber;
- (void)setPasswordSDK2:(NSString *)pinNumber;
- (void)setChangePasswordSDK2From:(NSString *)curNumber To:(NSString *)pinNumber;
- (void)setRequestPenState;
- (void)setPenState2WithTypeAndRGB:(UInt32)color tType:(UInt8)tType;
- (void)setPenState2WithTypeAndAutoPwrOffTime:(UInt16)autoPwrOffTime;
- (void)setPenState2WithTypeAndTimeStamp;
- (void)setPenState2WithType:(UInt8)type andValue:(UInt8)value;
- (void)setPenState2WithTypeAndHover:(unsigned char)useHover;
- (void)setAllNoteIdList2;
- (void)setNoteIdListSectionOwnerFromPList2;
- (void)setNoteIdListFromPList2;
- (BOOL)requestOfflineFileList2;
- (BOOL)requestOfflinePageListSectionOwnerId:(UInt32) sectionOwnerId AndNoteId:(UInt32) noteId;
- (BOOL) requestOfflineData2WithOwnerId:(UInt32)ownerId noteId:(UInt32)noteId pageId:(NSMutableArray *)pagesArray;
- (BOOL) sendUpdateFileInfo2AtUrl:(NSURL *)fileUrl;

@end
