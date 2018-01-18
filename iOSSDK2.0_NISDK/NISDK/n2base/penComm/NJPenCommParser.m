//
//  NJPenCommParser.m
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJPenCommParser.h"
#import "NJNode.h"
#import "NeoPenService.h"
#import "NJNotebookPaperInfo.h"
#import "NJVoiceManager.h"
#import <zipzap/zipzap.h>
#import "NJNotebookPaperInfo.h"
#import "NPPaperManager.h"
#import "NJPenCommManager.h"
#import "NJCommon.h"
#import "MyFunctions.h"
#import <zlib.h>

#define POINT_COUNT_MAX 1024*STROKE_NUMBER_MAGNITUDE
#define MAX_NODE_NUMBER 1024 

extern NSString *NJPageChangedNotification;
extern NSString *NJPenBatteryLowWarningNotification;
extern NSString *NJPenCommManagerPageChangedNotification;

typedef enum {
    PACKET_CMD_REQ_VERSION_INFO = 0x01,
    PACKET_CMD_REQ_COMPARE_PWD = 0x02,
    PACKET_CMD_REQ_CHANGE_PWD = 0x03,
    PACKET_CMD_REQ_PEN_STATE = 0x04,
    PACKET_CMD_SET_PEN_STATE = 0x05,
    PACKET_CMD_SET_NOTE_LIST = 0x11,
    PACKET_CMD_REQ1_OFFLINE_NOTE_LIST = 0x21,
    PACKET_CMD_REQ2_OFFLINE_PAGE_LIST = 0x22,
    PACKET_CMD_REQ1_OFFLINE_DATA = 0x23,
    PACKET_CMD_REQ_DEL_OFFLINE_DATA = 0x25,
    PACKET_CMD_REQ1_FW_FILE = 0x31,
    PACKET_CMD_RES2_FW_FILE = 0xB2,
    PACKET_CMD_RES2_OFFLINE_DATA = 0xA4,
} PacketRequestCommand;

typedef enum {
    PACKET_CMD_REQ2_OFFLINE_DATA = 0x24,
    PACKET_CMD_EVENT_BATT_ALARM = 0x61,
    PACKET_CMD_EVENT_PWR_OFF = 0x62,
    PACKET_CMD_EVENT_PEN_UPDOWN = 0x63,
    PACKET_CMD_EVENT_PEN_NEWID = 0x64,
    PACKET_CMD_EVENT_PEN_DOTCODE = 0x65,
    PACKET_CMD_EVENT_PEN_DOTCODE2 = 0x66,
    PACKET_CMD_EVENT_PEN_DOTCODE3 = 0x67,
    PACKET_CMD_RES_VERSION_INFO = 0x81,
    PACKET_CMD_RES_COMPARE_PWD = 0x82,
    PACKET_CMD_RES_CHANGE_PWD = 0x83,
    PACKET_CMD_RES_PEN_STATE = 0x84,
    PACKET_CMD_RES_SET_PEN_STATE = 0x85,
    PACKET_CMD_RES_SET_NOTE_LIST = 0x91,
    PACKET_CMD_RES1_OFFLINE_NOTE_LIST = 0xA1,
    PACKET_CMD_RES2_OFFLINE_PAGE_LIST = 0xA2,
    PACKET_CMD_RES1_OFFLINE_DATA_INFO = 0xA3,
    PACKET_CMD_RES_DEL_OFFLINE_DATA = 0xA5,
    PACKET_CMD_RES1_FW_FILE = 0xB1,
    PACKET_CMD_REQ2_FW_FILE = 0x32,
} PacketResponseCommand;
typedef struct {
    float x, y, pressure;
    unsigned char diff_time;
}dotDataStruct;

typedef enum {
    DOT_CHECK_NONE,
    DOT_CHECK_FIRST,
    DOT_CHECK_SECOND,
    DOT_CHECK_THIRD,
    DOT_CHECK_NORMAL
}DOT_CHECK_STATE;

typedef enum {
    OFFLINE_DOT_CHECK_NONE,
    OFFLINE_DOT_CHECK_FIRST,
    OFFLINE_DOT_CHECK_SECOND,
    OFFLINE_DOT_CHECK_THIRD,
    OFFLINE_DOT_CHECK_NORMAL
}OFFLINE_DOT_CHECK_STATE;

//13bits:data(4bits year,4bits month, 5bits date, ex:14 08 28)
//3bits: cmd, 1bit:dirty bit
typedef enum {
    None = 0x00,
    Email = 0x01,
    Alarm = 0x02,
    Activity = 0x04
} PageArrayCommandState;


typedef struct{
    int page_id;
    float activeStartX;
    float activeStartY;
    float activeWidth;
    float activeHeight;
    float spanX;
    float spanY;
    int arrayX; //email:action array, alarm: month start array
    int arrayY; //email:action array, alarm: month start array
    int startDate;
    int endDate;
    int remainedDate;
    int month;
    int year;
    PageArrayCommandState cmd;
} PageInfoType;

#define PRESSURE_MAX    255
#define PRESSURE_MAX2    1023
#define PRESSURE_MIN    0
#define PRESSURE_V_MIN    40
#define IDLE_TIMER_INTERVAL 5.0f
#define IDLE_COUNT  (10.0f/IDLE_TIMER_INTERVAL) // 10 seconds

NSString * NJPenCommManagerWriteIdleNotification = @"NJPenCommManagerWriteIdleNotification";

@interface NJPenCommParser() {
    int node_count;
    int node_count_pen;
    dotDataStruct dotData0, dotData1, dotData2;
    DOT_CHECK_STATE dotCheckState;
    OffLineDataDotStruct offlineDotData0, offlineDotData1, offlineDotData2;
    OffLineData2DotStruct offline2DotData0, offline2DotData1, offline2DotData2;
    OFFLINE_DOT_CHECK_STATE offlineDotCheckState;
}
@property (weak, nonatomic) id<NJOfflineDataDelegate> offlineDataDelegate;
@property (weak, nonatomic) id<NJPenCalibrationDelegate> penCalibrationDelegate;
@property (weak, nonatomic) id<NJFWUpdateDelegate> fwUpdateDelegate;
@property (weak, nonatomic) id<NJPenStatusDelegate> penStatusDelegate;
@property (weak, nonatomic) id<NJPenPasswordDelegate> penPasswordDelegate;
@property (nonatomic) BOOL penDown;
@property (strong, nonatomic) NSMutableArray *nodes;
@property (nonatomic) float mDotToScreenScale;
@property (strong, nonatomic) NSMutableArray *strokeArray;
@property (strong, nonatomic) NJPenCommManager *commManager;
@property (strong, nonatomic) NJVoiceManager *voiceManager;
@property (strong, nonatomic) NSMutableData *offlineData;
@property (strong, nonatomic) NSMutableData *offlinePacketData;
@property (nonatomic) int offlineDataOffset;
@property (nonatomic) int offlineTotalDataSize;
@property (nonatomic) int offlineTotalDataReceived;
@property (nonatomic) int offlineDataSize;
@property (nonatomic) int offlinePacketCount;
@property (nonatomic) int offlinePacketSize;
@property (nonatomic) int offlinePacketOffset;
@property (nonatomic) int offlineLastPacketIndex;
@property (nonatomic) int offlinePacketIndex;
@property (nonatomic) int offlineSliceCount;
@property (nonatomic) int offlineSliceSize;
@property (nonatomic) int offlineLastSliceSize;
@property (nonatomic) int offlineLastSliceIndex;
@property (nonatomic) int offlineSliceIndex;
@property (nonatomic) int offlineOwnerIdRequested;
@property (nonatomic) int offlineNoteIdRequested;
@property (nonatomic) BOOL offlineFileProcessing;
@property (nonatomic) UInt64 offlineLastStrokeStartTime;
@property (strong, nonatomic) NSMutableDictionary *offlineFileParsedList;
@property (nonatomic) BOOL sealReceived;
@property (nonatomic) NSInteger lastSealId;

@property (nonatomic) UInt8 lbuffer0;
@property (nonatomic) UInt8 lbuffer1;
@property (nonatomic) int packetHdrLen;
@property (nonatomic) int packetLenPos1;
@property (nonatomic) int packetLenPos2;
@property (nonatomic) int packetLenDLENextPos;

// FW Update
@property (strong, nonatomic) NSData *updateFileData;
@property (nonatomic) NSInteger updateFilePosition;

@property (nonatomic) int idleCounter;
@property (strong, nonatomic)NSTimer *idleTimer;

@property (nonatomic) PenStateStruct *penStatus;
@property (nonatomic) PenStateStruct *penState;
@property (nonatomic) PenState2Struct *penStatus2;
@property (nonatomic) UInt32 colorFromPen;

@property (nonatomic) PageInfoType *currentPageInfo;
@property (strong, nonatomic) NSMutableArray *dataRowArray;
@property (nonatomic) BOOL sendOneTime;
@property (nonatomic) BOOL alarmOneTime;

@property (nonatomic) UInt32 penTipColor;

@property (nonatomic) UInt16 packetCount;

@property (strong, nonatomic) NJPage *cPage;
@property (nonatomic) BOOL isReadyExchangeSent;
@property (strong, nonatomic) NPPaperInfo *paperInfo;
- (void)updateIdleCounter:(NSTimer *)timer;

@property (nonatomic) BOOL isStart;
@property (nonatomic) int count;
@property (nonatomic) int packetDataLength;
@property (nonatomic) int prevPacketDataLength;
@property (strong, nonatomic) NSMutableData *packetData;
@property (nonatomic) BOOL isDLEData;
@property (nonatomic) BOOL noErrCmd;
@property (nonatomic) BOOL oneTime;

@property (nonatomic) NSInteger activeNotebookId;
@property (nonatomic) NSInteger activePaperNum;
@property (nonatomic) NSInteger activeOwnerId;
@property (nonatomic) NSInteger activeSectionId;

@property (nonatomic) NSUInteger fwBtMtu;


@end

@implementation NJPenCommParser {
    float point_x[POINT_COUNT_MAX];
    float point_y[POINT_COUNT_MAX];
    float point_p[POINT_COUNT_MAX];
    int time_diff[POINT_COUNT_MAX];
    int point_count;
    UInt64 startTime;
    unsigned char pressureMax;
    UInt16 pressureMax2;
    UInt32 penColor;
    UInt32 offlinePenColor;
    
    int point_index;
}
@synthesize startX=_startX;
@synthesize startY=_startY;
@synthesize batteryLevel;
@synthesize memoryUsed;
@synthesize fwVersion;

- (id) initWithPenCommManager:(NJPenCommManager *)manager
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _commManager = manager;
    self.strokeArray = [[NSMutableArray alloc] initWithCapacity:3];
    point_count = 0;
    node_count = 0;
    node_count_pen = -1;
    self.idleCounter = 0;
    self.idleTimer = nil;
    self.voiceManager = [NJVoiceManager sharedInstance];
    self.updateFileData = nil;
    self.updateFilePosition = 0;
    pressureMax = PRESSURE_MAX;
    _offlineFileProcessing = NO;
    _shouldSendPageChangeNotification = NO;
    _isReadyExchangeSent = NO;
    self.penThickness = 960.0f;
    self.lastSealId = -1;
    self.cancelFWUpdate = NO;
    self.passwdCounter = 0;
    self.protocolVerStr = @"1";
    self.subNameStr = @"";
    _isStart = YES;
    //commad 1, err 1 len 2
    _packetHdrLen = 4;
    _packetLenPos1 = 2;
    _packetLenPos2 = 3;
    _isDLEData = NO;
    _noErrCmd = NO;
    _oneTime = NO;
    _packetDataLength = 0;
    point_index = 0;
    
    return self;
}
- (void) setPenCommUpDownDataReady:(BOOL)penCommUpDownDataReady
{
    _penCommUpDownDataReady = penCommUpDownDataReady;
    if (penCommUpDownDataReady) {
        [self sendReadyExchangeDataIfReady];
    }
}
- (void) setPenCommIdDataReady:(BOOL)penCommIdDataReady
{
    _penCommIdDataReady = penCommIdDataReady;
    if (penCommIdDataReady) {
        [self sendReadyExchangeDataIfReady];
    }
}
- (void) setPenCommStrokeDataReady:(BOOL)penCommStrokeDataReady
{
    _penCommStrokeDataReady = penCommStrokeDataReady;
    if (penCommStrokeDataReady) {
        [self sendReadyExchangeDataIfReady];
    }
}
- (void) setPenExchangeDataReady:(BOOL)penExchangeDataReady
{
    _penExchangeDataReady = penExchangeDataReady;
    if (penExchangeDataReady) {
        [self sendReadyExchangeDataIfReady];
    }
}
- (void) sendReadyExchangeDataIfReady
{
    if (_penCommIdDataReady && _penCommStrokeDataReady && _penCommUpDownDataReady && _penExchangeDataReady) {
        [self writeReadyExchangeData:YES];
    }
}

- (void) setPenPasswordResponse:(BOOL)penPasswordResponse
{
    _penPasswordResponse = penPasswordResponse;
    if (penPasswordResponse) {
        
        [self sendPenPasswordReponseData];
    }
}
- (void) sendPenPasswordReponseData
{
    if (_penCommIdDataReady && _penCommStrokeDataReady && _penCommUpDownDataReady && _penExchangeDataReady) {
        
        NSString *password = [MyFunctions loadPasswd];

        [self setBTComparePassword:password];
        
    }
}

- (void) sendPenPasswordReponseDataWithPasswd:(NSString *)passwd
{
    if (_penCommIdDataReady && _penCommStrokeDataReady && _penCommUpDownDataReady && _penExchangeDataReady) {

        if (_commManager.isPenSDK2) {
            [self setComparePasswordSDK2:passwd];
        } else {
            [self setBTComparePassword:passwd];
        }
        
    }
}
- (void) setPenDown:(BOOL)penDown
{
    if (point_count > 0) { // both penDown YES and NO
        if (self.strokeHandler){
            penColor = [self.strokeHandler setPenColor];
        }
        
        self.nodes = nil;
        point_count = 0;
    }
    
    if (penDown == YES) {
        NSLog(@"penDown YES");
        if (self.nodes == nil) {
            self.nodes = [[NSMutableArray alloc] init];
        }
        // Just ignore timestamp from Pen. We use Audio timestamp from iPhone.
        /* ken 2015.04.19*/
        UInt64 timeInMiliseconds = (UInt64)([[NSDate date] timeIntervalSince1970]*1000);
        NSLog(@"Stroke start time %llu", timeInMiliseconds);
        startTime = timeInMiliseconds;
         
        dotCheckState = DOT_CHECK_FIRST;
    }
    else {
        NSLog(@"penDown NO");
        dotCheckState = DOT_CHECK_NONE;
        
        _sendOneTime = YES;
    }
    _penDown = penDown;
}

- (void) parsePen2Data:(unsigned char *)data withLength:(int) length
{
    int dataLength = length;
    //NSLog(@"Received:length = %d", dataLength);
   
   for ( int i =0 ; i < dataLength; i++){
        [self createPen2DataPacket:data];
        data = data + 1;
    }
    
}

#define PACKET_START 0xC0
#define PACKET_END 0xC1
#define PACKET_DLE 0x7D
#define PACKET_MAX_LEN 32000
#define STROKE_SDK2_PACKET_LEN   13
#define STROKE2_SDK2_PACKET_LEN   7
#define STROKE3_SDK2_PACKET_LEN   5

- (void) createPen2DataPacket:(unsigned char *)data
{
    NSRange range;
    int int_data = (int) (data[0] & 0xFF);
    
    //Error handling for C0 ~ C0 without C1(End byte)
    if ((int_data == PACKET_START) && !_isStart && !(_count == _packetLenDLENextPos)){
        //NSLog(@"START PACKET, _count:%d, _isStart: %d",_count, _isStart);
        [self parsePen2DataPacket:_packetData length:(int)_packetData.length];
        
        _count = 0;
        _packetData = nil;
        
        _noErrCmd = NO;
        _isStart = NO;
        _oneTime = NO;
        _packetDataLength = 0;
        _packetData = [[NSMutableData alloc] init];
    }
    if ( int_data == PACKET_START && _isStart )
    {
         //NSLog(@"Packet Start");
        
        _count = 0;
        _noErrCmd = NO;
        _isStart = NO;
        _oneTime = NO;
        _packetDataLength = 0;
        _packetData = [[NSMutableData alloc] init];
    }
    else if ( int_data == PACKET_END && (_count == (_packetDataLength + _packetHdrLen)) )
    {
         //NSLog(@"Packet End");
        
        [self parsePen2DataPacket:_packetData length:(int)_packetData.length];
    
        _packetDataLength = 0;
        _count = 0;
        _packetData = nil;
        
        _isStart = YES;
        _oneTime = NO;
    }
    else if ( _count > PACKET_MAX_LEN )
    {
        _count = 0;
        _packetDataLength = 0;
        
        _isStart = NO;
        _oneTime = NO;
    }
    else
    {
        if (_count == 0) {
            if ((int_data == PACKET_CMD_EVENT_BATT_ALARM) || (int_data == PACKET_CMD_EVENT_PWR_OFF) || (int_data == PACKET_CMD_EVENT_PEN_UPDOWN)
                || (int_data == PACKET_CMD_EVENT_PEN_NEWID) || (int_data == PACKET_CMD_EVENT_PEN_DOTCODE) || (int_data == PACKET_CMD_REQ2_OFFLINE_DATA)
                || (int_data == PACKET_CMD_REQ2_FW_FILE)|| (int_data == PACKET_CMD_EVENT_PEN_DOTCODE2)|| (int_data == PACKET_CMD_EVENT_PEN_DOTCODE3)) {
                //commad 1, len 2, no err code
                _packetHdrLen = 3;
                _packetLenPos1 = 1;
                _packetLenPos2 = 2;
                _noErrCmd = YES;
            } else {
                //commad 1, err 1 len 2
                _packetHdrLen = 4;
                _packetLenPos1 = 2;
                _packetLenPos2 = 3;
                _noErrCmd = NO;
            }
        }

        if ( !_oneTime && (_packetData.length == (_packetLenPos2 + 1 )))
        {
            if (_noErrCmd) {
                if (_packetData.length == 3) {
                    range.location = 1;
                    range.length = 2;
                    [_packetData getBytes:&_packetDataLength range:range];
                }
            }else{
                if (_packetData.length == 4) {
                    range.location = 2;
                    range.length = 2;
                    [_packetData getBytes:&_packetDataLength range:range];
                }
            }
            _oneTime = YES;
        }
        if ((_count != 0) && (_count == _packetLenDLENextPos)) {
            
            data[0] = data[0] ^ 0x20;
            _packetLenDLENextPos = 0;
            if (data[0] == PACKET_DLE) {
                _isDLEData = YES;
            }
        
        }
        
        if ((int_data != PACKET_DLE) || (_isDLEData == YES)) {
            [_packetData appendBytes:data length:sizeof(data[0])];
            _isDLEData = NO;
            
        } else if ((int_data == PACKET_DLE) && (_isDLEData == NO)) {
            _packetLenDLENextPos = _count + 1;
            if (_packetData.length >= (_packetLenPos2 + 1 )) {
                _packetDataLength = _packetDataLength + 1;
            } else {
                _packetHdrLen = _packetHdrLen + 1;
            }
            
        }
        _count++;
    }


}

- (void) parsePen2DataPacket:(NSMutableData*)packetData length:(int) length
{
    
    COMM2_WRITE_DATA *strokeData;
    COMM_CHANGEDID2_DATA *newIdData;
    COMM_PENUP_DATA *updownData;
    ReadyExchangeDataRequestStruct *exchange;
    PenPasswordRequestStruct *request;
    PenPasswordChangeResponseStruct *response;
    
    int dataPosition = 0;
    NSRange range;
    unsigned char char0, char1, char2, char3;
    
    if (packetData.length < 1) return;
    
    range.location = dataPosition;
    range.length = 1;
    [packetData getBytes:&char0 range:range];
    PacketResponseCommand cmd = (PacketResponseCommand)char0;
    //NSLog(@"cmd received:%x",char0);
    dataPosition++;

    switch ( cmd )
    {
            
        case PACKET_CMD_EVENT_PEN_DOTCODE:
        {
            if (packetData.length < 3) return;
                
            strokeData = malloc(sizeof(COMM2_WRITE_DATA));
            
            unsigned char time, f_x, f_y; UInt16 force, x, y;
            
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
             dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            _packetDataLength = (((int)char2 << 8) & 0xFF00) | ((int)char1 & 0xFF);
            int packet_count = _packetDataLength / STROKE_SDK2_PACKET_LEN;
            
            if ((packetData.length < (_packetDataLength + 3))){
                NSLog(@"0x65 packetData len %lu, length in packet %d",packetData.length - 3, _packetDataLength);
                return;
            }
            
            BOOL shouldCheck = NO;
            int mid = packet_count / 2;

            for ( int i =0 ; i < packet_count; i++){
                if ((STROKE_SDK2_PACKET_LEN * (i+1)) > _packetDataLength) {
                    break;
                }
                
                shouldCheck = NO;
                if(i == mid) shouldCheck = YES;
                
                range.location = dataPosition;
                [packetData getBytes:&time range:range];
                strokeData->diff_time = time;
                dataPosition++;
                
                range.location = dataPosition;
                range.length = 2;
                [packetData getBytes:&force range:range];
                strokeData->force = force;
                dataPosition += 2;
                
                range.location = dataPosition;
                range.length = 2;
                [packetData getBytes:&x range:range];
                strokeData->x = x;
                dataPosition += 2;
                
                range.location = dataPosition;
                range.length = 2;
                [packetData getBytes:&y range:range];
                strokeData->y = y;
                dataPosition += 2;
                
                range.location = dataPosition;
                range.length = 1;
                [packetData getBytes:&f_x range:range];
                strokeData->f_x = f_x;
                dataPosition++;
                
                range.location = dataPosition;
                range.length = 1;
                [packetData getBytes:&f_y range:range];
                strokeData->f_y = f_y;
                dataPosition ++;
                
                [self parsePenStrokePacket:(unsigned char *)strokeData withLength:sizeof(COMM2_WRITE_DATA) withCoordCheck:shouldCheck];
                dataPosition += 4; //x tilt 1, y tilt 1, twist 2
                
            }
            if(strokeData != nil) free(strokeData);
        }
            break;
            
        case PACKET_CMD_EVENT_PEN_DOTCODE2:
        {
            if (packetData.length < 3) return;
            strokeData = malloc(sizeof(COMM2_WRITE_DATA));
            
            unsigned char time, f_x, f_y; UInt16 force, x, y;
            
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            _packetDataLength = (((int)char2 << 8) & 0xFF00) | ((int)char1 & 0xFF);
            int packet_count = _packetDataLength / STROKE2_SDK2_PACKET_LEN;
            
            if ((packetData.length < (_packetDataLength + 3))){
                NSLog(@"0x66 packetData len %lu, length in packet %d",packetData.length - 3, _packetDataLength);
                return;
            }
            
            BOOL shouldCheck = NO;
            int mid = packet_count / 2;
            
            for ( int i =0 ; i < packet_count; i++){
                if ((STROKE2_SDK2_PACKET_LEN * (i+1)) > _packetDataLength) {
                    break;
                }
                
                shouldCheck = NO;
                if(i == mid) shouldCheck = YES;
                
                range.location = dataPosition;
                [packetData getBytes:&time range:range];
                strokeData->diff_time = time;
                dataPosition++;
                
                range.location = dataPosition;
                range.length = 2;
                [packetData getBytes:&x range:range];
                strokeData->x = x;
                dataPosition += 2;
                
                range.location = dataPosition;
                range.length = 2;
                [packetData getBytes:&y range:range];
                strokeData->y = y;
                dataPosition += 2;
                
                range.location = dataPosition;
                range.length = 1;
                [packetData getBytes:&f_x range:range];
                strokeData->f_x = f_x;
                dataPosition++;
                
                range.location = dataPosition;
                range.length = 1;
                [packetData getBytes:&f_y range:range];
                strokeData->f_y = f_y;
        
                force = 500;
                strokeData->force = force;
                
                [self parsePenStrokePacket:(unsigned char *)strokeData withLength:sizeof(COMM2_WRITE_DATA) withCoordCheck:shouldCheck];
                
            }
            if(strokeData != nil) free(strokeData);
        }
            break;
            
        case PACKET_CMD_EVENT_PEN_DOTCODE3:
        {
            if (packetData.length < 3) return;
            strokeData = malloc(sizeof(COMM2_WRITE_DATA));
            
            unsigned char time, f_x, f_y, x, y; UInt16 force;
            
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            _packetDataLength = (((int)char2 << 8) & 0xFF00) | ((int)char1 & 0xFF);
            int packet_count = _packetDataLength / STROKE3_SDK2_PACKET_LEN;
            
            if ((packetData.length < (_packetDataLength + 3))){
                NSLog(@"0x67 packetData len %lu, length in packet %d",packetData.length - 3, _packetDataLength);
                return;
            }
            
            BOOL shouldCheck = NO;
            int mid = packet_count / 2;
            
            for ( int i =0 ; i < packet_count; i++){
                if ((STROKE3_SDK2_PACKET_LEN * (i+1)) > _packetDataLength) {
                    break;
                }
                
                shouldCheck = NO;
                if(i == mid) shouldCheck = YES;
                
                range.location = dataPosition;
                [packetData getBytes:&time range:range];
                strokeData->diff_time = time;
                dataPosition++;
                
                range.location = dataPosition;
                range.length = 1;
                [packetData getBytes:&x range:range];
                
                strokeData->x = (unsigned short)x;
                dataPosition++;
                
                range.location = dataPosition;
                range.length = 1;
                [packetData getBytes:&y range:range];
                strokeData->y = (unsigned short)y;
                dataPosition++;
                
                range.location = dataPosition;
                range.length = 1;
                [packetData getBytes:&f_x range:range];
                strokeData->f_x = f_x;
                dataPosition++;
                
                range.location = dataPosition;
                range.length = 1;
                [packetData getBytes:&f_y range:range];
                strokeData->f_y = f_y;
                
                force = 500;
                strokeData->force = force;
                
                [self parsePenStrokePacket:(unsigned char *)strokeData withLength:sizeof(COMM2_WRITE_DATA) withCoordCheck:shouldCheck];
                
            }
            if(strokeData != nil) free(strokeData);
        }
            break;

        case PACKET_CMD_EVENT_PEN_UPDOWN:
        {
	    if (packetData.length < 3) return;
            updownData = malloc(sizeof(COMM_PENUP_DATA));
            
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            _packetDataLength = (((int)char2 << 8) & 0xFF00) | ((int)char1 & 0xFF);
            
	    if ((packetData.length < (_packetDataLength + 3))){
                NSLog(@"0x63 packetData len %lu, length in packet %d",packetData.length - 3, _packetDataLength);
                return;
            }
            UInt8 updown; UInt64 time_stamp; UInt8 penTipType; UInt32 penTipColor;
            
            range.location = dataPosition;
            [packetData getBytes:&updown range:range];
            updownData->upDown = updown;
            dataPosition++;
            
            range.location = dataPosition;
            range.length = 8;
            [packetData getBytes:&time_stamp range:range];
            updownData->time = time_stamp;
            dataPosition += 8;
            
            range.location = dataPosition;
            range.length = 1;
            [packetData getBytes:&penTipType range:range];
            dataPosition++;
            
            range.location = dataPosition;
            range.length = 4;
            [packetData getBytes:&penTipColor range:range];
            updownData->penColor = penTipColor;
            
            _commManager.writeActiveState = YES;
            
            [self parsePenUpDowneData:(unsigned char*)updownData withLength:sizeof(COMM_PENUP_DATA)];
            
            if(updownData != nil) free(updownData);
        }
            break;

        case PACKET_CMD_EVENT_PEN_NEWID:
        {
            if (packetData.length < 3) return;
            
            newIdData = malloc(sizeof(COMM_CHANGEDID2_DATA));
            
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            _packetDataLength = (((int)char2 << 8) & 0xFF00) | ((int)char1 & 0xFF);
            
            if ((packetData.length < (_packetDataLength + 3))){
                NSLog(@"0x64 packetData len %lu, length in packet %d",packetData.length - 3, _packetDataLength);
                return;
            }
            UInt32 section_owner, noteID, pageID;
            
            range.location = dataPosition;
            range.length = 4;
            [packetData getBytes:&section_owner range:range];
            newIdData->owner_id = section_owner;
            dataPosition += 4;
            
            range.location = dataPosition;
            [packetData getBytes:&noteID range:range];
            newIdData->note_id = noteID;
            dataPosition += 4;
            
            range.location = dataPosition;
            [packetData getBytes:&pageID range:range];
            newIdData->page_id = pageID;
            
            [self parsePenNewIdData:(unsigned char*)newIdData withLength:sizeof(COMM_CHANGEDID2_DATA)];
            
            if(newIdData != nil) free(newIdData);
        }
            break;
            
        case PACKET_CMD_EVENT_PWR_OFF:
        {
            if (packetData.length < 3) return;
            
            exchange = malloc(sizeof(ReadyExchangeDataRequestStruct));
            
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            _packetDataLength = (((int)char2 << 8) & 0xFF00) | ((int)char1 & 0xFF);
            
            if ((packetData.length < (_packetDataLength + 3))){
                NSLog(@"0x62 packetData len %lu, length in packet %d",packetData.length - 3, _packetDataLength);
                return;
            }
            
            UInt8 reason;
            
            range.location = dataPosition;
            [packetData getBytes:&reason range:range];
            dataPosition++;
            
            //0: auto pwr off, 1:low batt, 2: update, 3: pwr key, 4: pen can pwr off, 5: system alert, 6: usb disk in, 7: wrong pw
            exchange->ready = 0;
            [self parseReadyExchangeDataRequest:(unsigned char*)exchange withLength:sizeof(ReadyExchangeDataRequestStruct)];
            
            if (reason == 2){
                [self notifyFWUpdateStatus:FW_UPDATE_DATA_RECEIVE_END percent:100];
            }
            if(exchange != nil) free(exchange);
        }
            break;
            
        case PACKET_CMD_EVENT_BATT_ALARM:
        {
	    if (packetData.length < 3) return;
            self.penState = malloc(sizeof(PenStateStruct));
            
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            _packetDataLength = (((int)char2 << 8) & 0xFF00) | ((int)char1 & 0xFF);
            
            if ((packetData.length < (_packetDataLength + 3))){
                NSLog(@"0x61 packetData len %lu, length in packet %d",packetData.length - 3, _packetDataLength);
                return;
            }
            UInt8 battery;
            
            range.location = dataPosition;
            [packetData getBytes:&battery range:range];
            dataPosition++;
            self.penState->battLevel = battery;
            
            if(self.penStatus2 == nil) return;
            
            self.penState->timeTick = self.penStatus2->timeTick;
            self.penState->autoPwrOffTime = self.penStatus2->autoPwrOffTime;
            self.penState->memoryUsed = self.penStatus2->memoryUsed;
            self.penState->usePenTipOnOff = self.penStatus2->usePenTipOnOff;
            self.penState->beepOnOff = self.penStatus2->beepOnOff;
            self.penState->useHover = self.penStatus2->useHover;
            self.penState->penPressure = self.penStatus2->penPressure;
            
            [self parsePenStatusData:(unsigned char *)self.penState withLength:sizeof(PenStateStruct)];
            
            
        }
            break;
           
        case PACKET_CMD_RES1_OFFLINE_DATA_INFO:
        {
            if (packetData.length < 4) return;
            
            //error code
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char3 range:range];
            dataPosition++;
            _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res1 offline data info error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if ((char1 != 0) || (packetData.length < (_packetDataLength + 4))){
                NSLog(@"OfflineFileStatus fail");
                NSLog(@"0xA3 error code %c, packetData len %lu, length in packet %d",char1, packetData.length - 4, _packetDataLength);
                [self notifyOfflineDataStatus:OFFLINE_DATA_RECEIVE_FAIL percent:0.0f];
                return;
            }
            
            UInt32 strokeNum; UInt32 offlineDataSize; UInt8 isZipped;
            
            range.location = dataPosition;
            range.length = 4;
            [packetData getBytes:&strokeNum range:range];
            dataPosition += 4;
            
            range.location = dataPosition;
            [packetData getBytes:&offlineDataSize range:range];
            dataPosition += 4;
            
            range.location = dataPosition;
            range.length = 1;
            [packetData getBytes:&isZipped range:range];
            
            _offlineTotalDataReceived = 0;
            _offlineTotalDataSize = offlineDataSize;
            
            [self notifyOfflineDataStatus:OFFLINE_DATA_RECEIVE_START percent:0.0f];
            
            NSLog(@"Res1 offline data info strokeNum:%d, offlineDataSize: %d isZipped :%d", strokeNum, offlineDataSize, isZipped);
        }
            break;

        case PACKET_CMD_REQ2_OFFLINE_DATA:
        {
            if (packetData.length < 3) return;
            
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            _packetDataLength = (((int)char2 << 8) & 0xFF00) | ((int)char1 & 0xFF);
            
            if ((packetData.length < (_packetDataLength + 3))){
                NSLog(@"0x24 packetData len %lu, length in packet %d",packetData.length - 3, _packetDataLength);
                return;
            }
            
            UInt8 isZip, trasPosition; UInt16 packetId, sizeBeforeZip, sizeAfterZip, strokeCnt;
            UInt32 sectionOwnerId, noteId;
            OffLineData2HeaderStruct offlineDataHeader;
            
            range.location = dataPosition;
            range.length = 2;
            [packetData getBytes:&packetId range:range];
            dataPosition += 2;
            
            range.location = dataPosition;
            range.length = 1;
            [packetData getBytes:&isZip range:range];
            dataPosition ++;
            
            range.location = dataPosition;
            range.length = 2;
            [packetData getBytes:&sizeBeforeZip range:range];
            dataPosition +=2;
            
            range.location = dataPosition;
            [packetData getBytes:&sizeAfterZip range:range];
            dataPosition +=2;
            
            range.location = dataPosition;
            range.length = 1;
            [packetData getBytes:&trasPosition range:range];
            dataPosition ++;
            
            range.location = dataPosition;
            range.length = 4;
            [packetData getBytes:&sectionOwnerId range:range];
            dataPosition +=4;
            
            range.location = dataPosition;
            range.length = 4;
            [packetData getBytes:&noteId range:range];
            dataPosition +=4;
            
            range.location = dataPosition;
            range.length = 2;
            [packetData getBytes:&strokeCnt range:range];
            dataPosition +=2;
            
            NSLog(@"isZip:%d, sizeBeforeZip:%d, sizeAfterZip:%d, transPos:%d, sectionOwnerId:%d, noteId:%d, storkCnt:%d",isZip,sizeBeforeZip,sizeAfterZip,trasPosition,sectionOwnerId,noteId,strokeCnt);
            NSLog(@"packetDataSize:%lu, zipped Data size:%lu", packetData.length, packetData.length - dataPosition);
            
            offlineDataHeader.nSectionOwnerId = sectionOwnerId;
            offlineDataHeader.nNoteId = noteId;
            offlineDataHeader.nNumOfStrokes = strokeCnt;
            
            if (isZip) {
                
                NSData* zippedData = [NSData dataWithBytesNoCopy:(char *)[packetData bytes] + dataPosition
                                                     length:sizeAfterZip
                                               freeWhenDone:NO];
                
                NSMutableData* penData = [NSMutableData dataWithLength:sizeBeforeZip];
                
                uLongf destLen = penData.length;

                int result = uncompress OF(((Bytef*)penData.mutableBytes, &destLen,
                                                   (Bytef*)zippedData.bytes, sizeAfterZip));
                
                if (result == Z_OK) {
                    // GOOD
                    NSLog(@"Offline zip file received successfully");
                    if (penData != nil) {
                        [self.offlineDataDelegate parseSDK2OfflinePenData:penData AndOfflineDataHeader:&offlineDataHeader];
                    }
                    _offlineTotalDataReceived += sizeBeforeZip;
                    
                    if (!_cancelOfflineSync)
                        [self response2AckToOfflineDataWithPacketID:packetId errCode:0 AndTransOption:1];
                    else
                        [self response2AckToOfflineDataWithPacketID:packetId errCode:0 AndTransOption:0];
                }
                else {
                    // BAD
                    NSLog(@"Offline zip file received badly, OfflineFileStatus fail");
                    [self notifyOfflineDataStatus:OFFLINE_DATA_RECEIVE_FAIL percent:0.0f];
                    
                    if(!_cancelOfflineSync)
                        [self response2AckToOfflineDataWithPacketID:packetId errCode:1 AndTransOption:1];
                    else
                        [self response2AckToOfflineDataWithPacketID:packetId errCode:1 AndTransOption:0];

                }
            } else {
                if(!_cancelOfflineSync)
                    [self response2AckToOfflineDataWithPacketID:packetId errCode:0 AndTransOption:1];
                else
                    [self response2AckToOfflineDataWithPacketID:packetId errCode:0 AndTransOption:0];
            }
            
            if (trasPosition == 2) {
                [self notifyOfflineDataStatus:OFFLINE_DATA_RECEIVE_END percent:100.0f];
            }else{
                float percent = (float)(_offlineTotalDataReceived * 100.0)/(float)_offlineTotalDataSize;
                NSLog(@"_offlineTotalDataReceived:%d sizeBeforeZip:%d, _offlineTotalDataSize:%d",_offlineTotalDataReceived,sizeBeforeZip,_offlineTotalDataSize);
                
                [self notifyOfflineDataStatus:OFFLINE_DATA_RECEIVE_PROGRESSING percent:percent];
            }
        }
            
            break;

        case PACKET_CMD_RES1_FW_FILE:
        {
            if (packetData.length < 4) return;
            
            //error code
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char3 range:range];
            dataPosition++;
            _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res1 FW File error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if ((char1 != 0) || (packetData.length < (_packetDataLength + 4))) {
                NSLog(@"0xB1 error code %c, packetData len %lu, length in packet %d",char1, packetData.length - 4, _packetDataLength);
                return;
            }
            
            UInt8 transPermission;
            
            range.location = dataPosition;
            range.length = 1;
            [packetData getBytes:&transPermission range:range];
            
            NSLog(@"transPermission: %d", transPermission);
            
        }
            
            break;
            
        case PACKET_CMD_REQ2_FW_FILE:
            
        {
            if (packetData.length < 3) return;
            
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            _packetDataLength = (((int)char2 << 8) & 0xFF00) | ((int)char1 & 0xFF);
            
            if ((packetData.length < (_packetDataLength + 3))){
                NSLog(@"0x32 packetData len %lu, length in packet %d",packetData.length - 3, _packetDataLength);
                return;
            }
            UInt8 status; UInt32 fileOffset;
            
            range.location = dataPosition;
            range.length = 1;
            [packetData getBytes:&status range:range];
            dataPosition++;
            
            NSLog(@"status:%d, %@", status, (status!= 3)? @"Success":@"Fail");
            
            range.location = dataPosition;
            range.length = 4;
            [packetData getBytes:&fileOffset range:range];
            
            [self sendUpdateFileData2At:fileOffset AndStatus:status];
            
        }

            
            break;
            
        case PACKET_CMD_RES1_OFFLINE_NOTE_LIST:
        {
            if (packetData.length < 4) return;
            
            //error code
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char3 range:range];
            dataPosition++;
            _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res1 offline note list error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if ((char1 != 0) || (packetData.length < (_packetDataLength + 4))) {
                NSLog(@"0xA1 error code %c, packetData len %lu, length in packet %d",char1, packetData.length - 4, _packetDataLength);
                return;
            }
            
            UInt32 note_ID, section_ownerID; UInt16 setCount;
            
            range.location = dataPosition;
            range.length = 2;
            [packetData getBytes:&setCount range:range];
            
            UInt32 *sectionOwnerId = malloc(sizeof(UInt32)* setCount);
            UInt32 *noteId = malloc(sizeof(UInt32)* setCount);
            
            if(setCount == 0){
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(!isEmpty(self.offlineDataDelegate) && [self.offlineDataDelegate respondsToSelector:@selector(offlineDataDidReceiveNoteListCount:ForSectionOwnerId:)])
                        [self.offlineDataDelegate offlineDataDidReceiveNoteListCount:0 ForSectionOwnerId:0];
                });
                return;
            }
            dataPosition += 2;
            
            range.length = 4;
            for(int i = 0 ; i < setCount ; i++) {
                range.location = dataPosition;
                [packetData getBytes:&section_ownerID range:range];
                sectionOwnerId[i] = section_ownerID;
                dataPosition += 4;
                
                range.location = dataPosition;
                [packetData getBytes:&note_ID range:range];
                noteId[i] = note_ID;
                dataPosition += 4;
            }
            
            for(int i = 0 ; i < setCount ; i++) {
                
                unsigned char section = (sectionOwnerId[i] >> 24) & 0xFF;
                UInt32 ownerId = sectionOwnerId[i] & 0x00FFFFFF;
                
                if ([[NJNotebookPaperInfo sharedInstance] hasInfoForSectionId:(int)section OwnerId:(int)ownerId]){
                    NSNumber *sectionOwnerID = [NSNumber numberWithUnsignedInteger:sectionOwnerId[i]];
                    NSMutableArray *noteArray = [_offlineFileList objectForKey:sectionOwnerID];
                    
                    if (noteArray == nil) {
                        noteArray = [NSMutableArray array];
                        [_offlineFileList setObject:noteArray forKey:sectionOwnerID];
                    }
                    NSNumber *noteID = [NSNumber numberWithUnsignedInteger:noteId[i]];
                    [noteArray addObject:noteID];
                }
            }
            
             if ([[_offlineFileList allKeys] count] > 0) {
                 NSLog(@"Getting offline File List finished");
                 dispatch_async(dispatch_get_main_queue(), ^{
                     if(!isEmpty(self.offlineDataDelegate) && [self.offlineDataDelegate respondsToSelector:@selector(offlineDataDidReceiveNoteList:)])
                         [self.offlineDataDelegate offlineDataDidReceiveNoteList:_offlineFileList];
                 });
             }
            
        }
            break;
            
        case PACKET_CMD_RES2_OFFLINE_PAGE_LIST:
        {
            if (packetData.length < 4) return;
            
             //error code
             range.location = dataPosition;
             [packetData getBytes:&char1 range:range];
             dataPosition++;
            
             range.location = dataPosition;
             [packetData getBytes:&char2 range:range];
             dataPosition++;
            
             range.location = dataPosition;
             [packetData getBytes:&char3 range:range];
             dataPosition++;
             _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res2 offline page list error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if ((char1 != 0) || (packetData.length < (_packetDataLength + 4))) {
                NSLog(@"0xA2 error code %c, packetData len %lu, length in packet %d",char1, packetData.length - 4, _packetDataLength);
                return;
            }
             
             UInt32 pageId[10], page_ID; UInt16 pageCount;
             UInt32 sectionOwnerId, noteId;
            
             range.location = dataPosition;
             range.length = 4;
             [packetData getBytes:&sectionOwnerId range:range];
             dataPosition +=4;
            
             range.location = dataPosition;
             range.length = 4;
             [packetData getBytes:&noteId range:range];
             dataPosition +=4;
            
             range.location = dataPosition;
             range.length = 2;
             [packetData getBytes:&pageCount range:range];
             dataPosition += 2;
            
             range.length = 4;
             for(int i = 0 ; i < pageCount ; i++) {
                 range.location = dataPosition;
                 [packetData getBytes:&page_ID range:range];
                 pageId[i] = page_ID;
                 dataPosition += 4;
             }
            
        }
            break;
            
        case PACKET_CMD_RES_SET_NOTE_LIST:
        {
            if (packetData.length < 4) return;
            
            //error code
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char3 range:range];
            dataPosition++;
            _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res set note list error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if (char1 != 0){
                return;
            }else if (char1 == 0){
                    
                _commManager.penConnectionStatusMsg = NSLocalizedString(@"BT_PEN_CONNECTED", nil);
                _commManager.penConnectionStatus = NJPenCommManPenConnectionStatusConnected;
            }
        }
            break;
            
        case PACKET_CMD_RES_DEL_OFFLINE_DATA:
        {
            if (packetData.length < 4) return;
            
            //error code
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char3 range:range];
            dataPosition++;
            _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res delete offline data error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if ((char1 != 0) || (packetData.length < (_packetDataLength + 4))) {
                NSLog(@"0xA5 error code %c, packetData len %lu, length in packet %d",char1, packetData.length - 4, _packetDataLength);
                return;
            }
            
            UInt8 noteCount; UInt32 note_ID_;
            
            range.location = dataPosition;
            [packetData getBytes:&noteCount range:range]; //deleted note count
            dataPosition++;
            
            range.length = 4;
            
            if (noteCount > 0) {
                for (int i = 0; i < noteCount; i ++) {
                    range.location = dataPosition;
                    [packetData getBytes:&note_ID_ range:range];
                    NSLog(@"note Id deleted %d", note_ID_);
                    dataPosition += 4;
                }
            }

        }
            break;
            
        case PACKET_CMD_RES_SET_PEN_STATE:
        {
            if (packetData.length < 4) return;
            
            //error code
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char3 range:range];
            dataPosition++;
            _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res set penState error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if (char1 != 0 || (packetData.length < (_packetDataLength + 4))) {
                NSLog(@"0x81 error code %c, packetData len %lu, length in packet %d",char1, packetData.length - 4, _packetDataLength);
                return;
            }
            
            UInt8 type;
            
            range.location = dataPosition;
            range.length = 1;
            [packetData getBytes:&type range:range];
            
        }
            
            break;

        case PACKET_CMD_RES_VERSION_INFO:
        {
            if (packetData.length < 4) return;
            
            //error code
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char3 range:range];
            dataPosition++;
            _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res version info error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if ((char1 != 0) || (packetData.length < (_packetDataLength + 4))) {
                NSLog(@"0x81 error code %c, packetData len %lu, length in packet %d",char1, packetData.length - 4, _packetDataLength);
                return;
            }
            
            unsigned char deviceName[16]; unsigned char fwVer[16]; unsigned char protocolVer[8];
            unsigned char subName[16]; unsigned char mac[6]; UInt16 penType; UInt8 pressureType;
            
            range.location = dataPosition;
            range.length = 16;
            [packetData getBytes:&deviceName range:range];
            dataPosition += 16;
            
            range.location = dataPosition;
            range.length = 16;
            [packetData getBytes:&fwVer range:range];
            dataPosition += 16;
            
            range.location = dataPosition;
            range.length = 8;
            [packetData getBytes:&protocolVer range:range];
            self.protocolVerStr = [NSString stringWithCString:protocolVer encoding:NSASCIIStringEncoding];
            dataPosition += 8;
            
            range.location = dataPosition;
            range.length = 16;
            [packetData getBytes:&subName range:range];
            dataPosition += 16;
            
            range.location = dataPosition;
            range.length = 2;
            [packetData getBytes:&penType range:range];
            dataPosition += 2;
            
            range.location = dataPosition;
            range.length = 6;
            [packetData getBytes:&mac range:range];
            dataPosition += 6;
            
            if ([packetData length] > dataPosition) {
                range.location = dataPosition;
                range.length = 1;
                [packetData getBytes:&pressureType range:range];
                NSLog(@"pressure sensor type:%d",pressureType);
                if (pressureType == 0x01)
                    _commManager.isPressureFSC = YES;
                else
                    _commManager.isPressureFSC = NO;
            } else {
                _commManager.isPressureFSC = NO;
            }
            NSLog(@"Version info data length:%d",[packetData length]);
            
            NSString *dName = [[NSString alloc] initWithBytes:deviceName length:sizeof(deviceName) encoding:NSUTF8StringEncoding];
            _commManager.deviceName = [NSString stringWithCString:[dName UTF8String] encoding:NSUTF8StringEncoding];
            
            NSString *sName = [[NSString alloc] initWithBytes:subName length:sizeof(subName) encoding:NSUTF8StringEncoding];
            _commManager.subName = [NSString stringWithCString:[sName UTF8String] encoding:NSUTF8StringEncoding];
            
            [self setRequestPenState];
            
        }
            break;
            
        case PACKET_CMD_RES_COMPARE_PWD:
        {
            if (packetData.length < 4) return;
            
            request = malloc(sizeof(PenPasswordRequestStruct));
            
            //error code
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char3 range:range];
            dataPosition++;
            _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res compare password error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if ((char1 != 0) || (packetData.length < (_packetDataLength + 4))){
                NSLog(@"0x82 error code %c, packetData len %lu, length in packet %d",char1, packetData.length - 4, _packetDataLength);
                if(request != nil) free(request);
                return;
            }
            
            UInt8 status,retryCount, maxCount;
            
            range.location = dataPosition;
            [packetData getBytes:&status range:range];
            //request->status = status;
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&retryCount range:range];
            request->retryCount = retryCount;
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&maxCount range:range];
            request->resetCount = maxCount;
            
            if(status == 1) {

                [self setNoteIdList];
                
                if (request != nil) free(request);
        
            } else {
                _penExchangeDataReady = YES;
                _penCommUpDownDataReady = YES;
                _penCommIdDataReady = YES;
                _penCommStrokeDataReady = YES;
                
                [self parsePenPasswordRequest:(unsigned char*)request withLength:sizeof(PenPasswordRequestStruct)];
            }
            
            
        }
            break;
            
            
        case PACKET_CMD_RES_CHANGE_PWD:
        {
            if (packetData.length < 4) return;
            
            response = malloc(sizeof(PenPasswordChangeResponseStruct));
            
            //error code
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char3 range:range];
            dataPosition++;
            _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res change password error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if ((char1 != 0) || (packetData.length < (_packetDataLength + 4))){
                NSLog(@"0x82 error code %c, packetData len %lu, length in packet %d",char1, packetData.length - 4, _packetDataLength);
                if(response != nil) free(response);
                return;
            }
            
            UInt8 retryCount, maxCount;
            
            range.location = dataPosition;
            [packetData getBytes:&retryCount range:range];
             dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&maxCount range:range];
            
            response -> passwordState = char1;
            
            [self parsePenPasswordChangeResponse:(unsigned char*)response withLength:sizeof(PenPasswordChangeResponseStruct)];
            
            if(response != nil) free(response);
        }
            break;
            
        case PACKET_CMD_RES_PEN_STATE:
        {
    
            if (packetData.length < 4) return;
            
            if(self.penStatus2 != nil) free(self.penStatus2);
            self.penState = malloc(sizeof(PenStateStruct));
            self.penStatus2 = malloc(sizeof(PenState2Struct));
            
            //error code
            range.location = dataPosition;
            [packetData getBytes:&char1 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char2 range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&char3 range:range];
            dataPosition++;
            _packetDataLength = (((int)char3 << 8) & 0xFF00) | ((int)char2 & 0xFF);
            
            NSLog(@"Res pen state error code : %d, %@", char1, (char1 == 0)? @"Success":@"Fail");
            
            if ((char1 != 0) || (packetData.length < (_packetDataLength + 4))){
                NSLog(@"0x84 error code %c, packetData len %lu, length in packet %d",char1, packetData.length - 4, _packetDataLength);
                //if(penState != nil) free(penState);
                //free(self.penStatus2);
                return;
            }
            
            UInt64 timeTick; UInt16 autoPwrOffTime, pressure_Max;
            UInt8 lock, maxRetryCnt, retryCnt, memory_Used, usePenCapOnOff, usePenTipOnOff, beepOnOff, useHover, battLevel, offlineOnOff, fsrStep, usbMode, downSampling;
            unsigned char btLocalName[16]; NSString *localName;
            
            range.location = dataPosition;
            [packetData getBytes:&lock range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&maxRetryCnt range:range];
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&retryCnt range:range];
            dataPosition++;
            
            range.location = dataPosition;
            range.length = sizeof(timeTick);
            [packetData getBytes:&timeTick range:range];
            self.penState->timeTick = timeTick;
            self.penStatus2->timeTick = timeTick;
            dataPosition += 8;
            
            range.location = dataPosition;
            range.length = 2;
            [packetData getBytes:&autoPwrOffTime range:range];
            self.penState->autoPwrOffTime = autoPwrOffTime;
            self.penStatus2->autoPwrOffTime = autoPwrOffTime;
            dataPosition += 2;
            
            range.location = dataPosition;
            range.length = 2;
            [packetData getBytes:&pressure_Max range:range];
            self.penState->pressureMax = pressure_Max;
            pressureMax2 = pressure_Max;
            dataPosition += 2;
            
            range.location = dataPosition;
            range.length = 1;
            [packetData getBytes:&memory_Used range:range];
            self.penState->memoryUsed = memory_Used;
            dataPosition++;
            
            range.location = dataPosition;
            [packetData getBytes:&usePenCapOnOff range:range];
            self.penStatus2->usePenCapOnOff = usePenCapOnOff;
            dataPosition ++;
            
            //auto power on
            range.location = dataPosition;
            [packetData getBytes:&usePenTipOnOff range:range];
            self.penState->usePenTipOnOff = usePenTipOnOff;
            self.penStatus2->usePenTipOnOff = usePenTipOnOff;
            dataPosition ++;
            
            range.location = dataPosition;
            [packetData getBytes:&beepOnOff range:range];
            self.penState->beepOnOff = beepOnOff;
            self.penStatus2->beepOnOff = beepOnOff;
            dataPosition ++;
            
            range.location = dataPosition;
            [packetData getBytes:&useHover range:range];
            self.penState->useHover = useHover;
            self.penStatus2->useHover = useHover;
            dataPosition ++;
            
            range.location = dataPosition;
            [packetData getBytes:&battLevel range:range];
            self.penState->battLevel = battLevel;
            dataPosition ++;
            
            range.location = dataPosition;
            [packetData getBytes:&offlineOnOff range:range];
            self.penStatus2->offlineOnOff = offlineOnOff;
            dataPosition ++;
            
            range.location = dataPosition;
            [packetData getBytes:&fsrStep range:range];
            self.penState->penPressure = (UInt16)fsrStep;
            self.penStatus2->penPressure = fsrStep;
            dataPosition ++;
            
            if ([packetData length] >= (dataPosition + 2)) {
                range.location = dataPosition;
                [packetData getBytes:&usbMode range:range];
                self.penStatus2->usbMode = usbMode;
                dataPosition ++;
                
                range.location = dataPosition;
                [packetData getBytes:&downSampling range:range];
                self.penStatus2->downSampling = downSampling;
                dataPosition ++;
            }
            if ([packetData length] >= (dataPosition + sizeof(btLocalName))) {
                range.location = dataPosition;
                range.length = 16;
                [packetData getBytes:&btLocalName range:range];
                NSString *lName = [[NSString alloc] initWithBytes:btLocalName length:sizeof(btLocalName) encoding:NSUTF8StringEncoding];
                if(!isEmpty(lName))
                    localName = [NSString stringWithCString:[lName UTF8String] encoding:NSUTF8StringEncoding];
            }
            
            
            if (char1 != 0){
                
                return;
            } else if (char1 == 0){
                [self parsePenStatusData:(unsigned char *)self.penState withLength:sizeof(PenStateStruct)];
                
                if(!_commManager.initialConnect) {
                    if (lock == 1) {
                        if (self.passwdCounter == 0) {
                            // try "0000" first in case when app does not recognize that pen has been reset
                            NSLog(@"[PenCommParser] 1. try \"0000\" first");
                            [self setComparePasswordSDK2:@"0000"];
                            _commManager.hasPenPassword = NO;
                         
                            self.passwdCounter++;
                        } else {
                            NSString *password = [MyFunctions loadPasswd];
                            [self setComparePasswordSDK2:password];
                            _commManager.hasPenPassword = YES;
                            
                        }
                    } else if (lock == 0){
                    	_commManager.hasPenPassword = NO;
                        
                        NSLog(@"set note id list command");
                        [self setNoteIdList];
                        
                    }
                    _commManager.initialConnect = YES;
                }
            }
            
        }
            break;

        default:
            NSLog(@"parsePen2DataPacket cmd error");
            break;
    }
}

- (void) setOfflineDataDelegate:(id)offlineDataDelegate
{
    _offlineDataDelegate = (id<NJOfflineDataDelegate>)offlineDataDelegate;
}
- (void) setPenCalibrationDelegate:(id<NJPenCalibrationDelegate>)penCalibrationDelegate
{
    _penCalibrationDelegate = penCalibrationDelegate;
}
- (void) setFWUpdateDelegate:(id<NJFWUpdateDelegate>)fwUpdateDelegate
{
    _fwUpdateDelegate = fwUpdateDelegate;
}
- (void) setPenStatusDelegate:(id<NJPenStatusDelegate>)penStatusDelegate;
{
    _penStatusDelegate = penStatusDelegate;
}
- (void) setPenPasswordDelegate:(id<NJPenPasswordDelegate>)penPasswordDelegate;
{
    _penPasswordDelegate = penPasswordDelegate;
}

- (void) setCancelFWUpdate:(BOOL)cancelFWUpdate
{
    _cancelFWUpdate = cancelFWUpdate;
}

- (void) setCancelOfflineSync:(BOOL)cancelOfflineSync
{
    _cancelOfflineSync = cancelOfflineSync;
}
#pragma mark - Received data


- (float) processPressure:(float)pressure
{
    if (pressure < PRESSURE_V_MIN) pressure = PRESSURE_V_MIN;
    
    if (_commManager.isPenSDK2) {
        pressure = (pressure)/(pressureMax2 - PRESSURE_MIN);
    }else{
        pressure = (pressure)/(pressureMax - PRESSURE_MIN);
    }

    return pressure;
}
- (void) parsePenStrokeData:(unsigned char *)data withLength:(int) length
{
#define STROKE_PACKET_LEN   8
    if (self.penDown == NO || _sealReceived == YES) return;
    unsigned char packet_count = data[0];
    int strokeDataLength = length - 1;
    //        NSLog(@"Received: stroke count = %d, length = %d", packet_count, dataLength);
    data++;
    // 06-Oct-2014 by namSsan
    // checkXcoord X,Y only called once for middle point of the stroke
    //int mid = (pa)
    BOOL shouldCheck = NO;
    int mid = packet_count / 2;
    
    for ( int i =0 ; i < packet_count; i++){
        if ((STROKE_PACKET_LEN * (i+1)) > strokeDataLength) {
            break;
        }
        shouldCheck = NO;
        if(i == mid) shouldCheck = YES;
        [self parsePenStrokePacket:data withLength:STROKE_PACKET_LEN withCoordCheck:shouldCheck];
        data = data + STROKE_PACKET_LEN;
    }

}
- (void) parsePenStrokePacket:(unsigned char *)data withLength:(int)length withCoordCheck:(BOOL)checkCoord
{
    //set for NISDK
    checkCoord = NO;
    
    if (_commManager.isPenSDK2) {
        COMM2_WRITE_DATA *strokeData = (COMM2_WRITE_DATA *)data;
        
        dotDataStruct aDot;
        float int_x = (float)strokeData->x;
        float int_y = (float)strokeData->y;
        float float_x = (float)strokeData->f_x  * 0.01f;
        float float_y = (float)strokeData->f_y  * 0.01f;
        aDot.diff_time = strokeData->diff_time;
        aDot.pressure = (float)strokeData->force;
        
        aDot.x = int_x + float_x  - self.startX;
    	aDot.y = int_y + float_y  - self.startY;

        NSLog(@"Raw X %f, Y %f, P %f", int_x + float_x, int_y + float_y,aDot.pressure);
        
        [self dotChecker:&aDot];
        
        if(checkCoord) {
            float x = int_x + float_x;
            float y = int_y + float_y;
            [self checkPUICoordX:x coordY:y];
        }
        
    }else{
        COMM_WRITE_DATA *strokeData = (COMM_WRITE_DATA *)data;
    
        dotDataStruct aDot;
        float int_x = (float)strokeData->x;
        float int_y = (float)strokeData->y;
        float float_x = (float)strokeData->f_x  * 0.01f;
        float float_y = (float)strokeData->f_y  * 0.01f;
        aDot.diff_time = strokeData->diff_time;
        aDot.pressure = (float)strokeData->force;
        aDot.x = int_x + float_x  - self.startX;
        aDot.y = int_y + float_y  - self.startY;
        //NSLog(@"Raw X %f, Y %f, P %f", int_x + float_x, int_y + float_y,aDot.pressure);
    
        [self dotChecker:&aDot];
        
        if(checkCoord) {
            float x = int_x + float_x;
            float y = int_y + float_y;
            [self checkPUICoordX:x coordY:y];
        }
    }
}

- (void) checkPUICoordX:(float)x coordY:(float)y
{
    if(isEmpty(self.paperInfo)) return;
    
    BOOL found = NO;
    PUICmdType cmdType = PUICmdTypeNone;
    NPPUIInfo *pui = nil;
    for(pui in self.paperInfo.puiArray) {
        CGFloat padding = 0.0f;
        if((pui.width > 5.0f) && (pui.height > 5.0f))
            padding = MIN(pui.width,pui.height) * 0.1;
        
        if(x < (pui.startX + padding)) continue;
        if(y < (pui.startY + padding)) continue;
        if(x > (pui.startX + pui.width - padding)) continue;
        if(y > (pui.startY + pui.height - padding)) continue;
        
        found = YES;
        cmdType = pui.cmdType;
        break;
    }
    if(cmdType == PUICmdTypeNone) return;
    //    NSLog(@"PUI Command Type ---> %tu",cmdType);
    
    if (self.commandHandler != nil) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(cmdType == PUICmdTypeEmail) {
                [self.commandHandler sendEmailWithPdf];
            }
            
            [self.commandHandler findApplicableSymbols:pui.param action:pui.action andName:pui.name];
        });
    }
    
}

#define DAILY_PLAN_START_PAGE_606 62
#define DAILY_PLAN_END_PAGE_606 826
#define DAILY_PLAN_START_PAGE_608 42
#define DAILY_PLAN_END_PAGE_608 424

- (void)pageInfoArrayInitNoteId:(UInt32)noteId AndPageNumber:(UInt32)pageNumber
{
    int startPageNumber = 1;
    int index = 0;
    NJNotebookPaperInfo *notebookInfo = [NJNotebookPaperInfo sharedInstance];
    
    NSDictionary *tempInfo = [notebookInfo.notebookPuiInfo objectForKey:[NSNumber numberWithInteger:noteId]];
    PageInfoType *tempPageInfo = [[tempInfo objectForKey:@"page_info"] pointerValue];
    startPageNumber = [notebookInfo getPaperStartPageNumberForNotebook:noteId];
    
    NSArray *keysArray = [notebookInfo.notebookPuiInfo allKeys];
    int count = (int)[keysArray count];
    for (NSNumber *noteIdInfo in keysArray) {
        //NSLog(@"NoteIdInfo : %@", noteIdInfo);
        if (noteId == (UInt32)[noteIdInfo unsignedIntegerValue]) {
            break;
        }
        index++;
    }
    
    if (index == count) {
        NSLog(@"noteId isn't included to pui info");
        _currentPageInfo = NULL;
        return;
    }
    if((tempPageInfo == NULL)||(noteId == 605)) {
        NSLog(@"tempPageInfo == NULL or active Note Id == 605");
        _currentPageInfo = NULL;
        return;
    }
    
    if((noteId == 601) || (noteId == 602) || (noteId == 2)|| (noteId == 604) || (noteId == 609)
            || (noteId == 610)|| (noteId == 611) || (noteId == 612) || (noteId == 613) || (noteId == 614)
            || (noteId == 617) || (noteId == 618) || (noteId == 619)|| (noteId == 620)|| (noteId == 114)
            || (noteId == 700)|| (noteId == 701)|| (noteId == 702)){
        if (pageNumber >= startPageNumber) {
            _currentPageInfo = &tempPageInfo[0];
        }
    }else if((noteId == 615) || (noteId == 616)){
        if (pageNumber >= startPageNumber) {
            _currentPageInfo = &tempPageInfo[0];
        }
    }else if(noteId == 603){
        if (pageNumber >= startPageNumber) {
            if ((pageNumber%2) == 1) {
                _currentPageInfo = &tempPageInfo[0];
            } else if ((pageNumber%2) == 0){
                _currentPageInfo = &tempPageInfo[1];
            }
        }
    }else {
        if (pageNumber >= startPageNumber) {
            _currentPageInfo = &tempPageInfo[0];
        }
    }
    
    if(_currentPageInfo == NULL) {
        NSLog(@"2. _currentPageInfo == NULL");
        return;
    }
    
    //NSLog(@"pageArrayInit _currentPageInfo:%@", self.currentPageInfo);
    
    int rowSize = (_currentPageInfo->activeHeight)/(_currentPageInfo->spanY);
    int colSize = (_currentPageInfo->activeWidth)/(_currentPageInfo->spanX);
    
    _dataRowArray = [[NSMutableArray alloc] initWithCapacity:rowSize];
    
    
    for (int i = 0; i < rowSize; i++) {
        NSMutableArray *dataColArray = [[NSMutableArray alloc] initWithCapacity:colSize];
        for (int j = 0; j < colSize; j++) {
            if (_currentPageInfo->cmd == Email) {
                dataColArray[j] = [NSNumber numberWithInt:0];
                if ((i == _currentPageInfo->arrayY) && (j == _currentPageInfo->arrayX)) {
                    dataColArray[j] = [NSNumber numberWithInt:Email];
                }
            }
        }
        [_dataRowArray insertObject:dataColArray atIndex:i];
    }
    
    _sendOneTime = YES;
    _alarmOneTime = YES;
}

- (void) checkXcoord:(float)x Ycoord:(float)y
{
    if (_currentPageInfo == NULL){
        //NSLog(@"3. _currentPageInfo == NULL");
        return;
    }
    
    if (((x < _currentPageInfo->activeStartX) || (x > (_currentPageInfo->activeStartX + _currentPageInfo->activeWidth)))
        || ((y < _currentPageInfo->activeStartY) || (y > (_currentPageInfo->activeStartY + _currentPageInfo->activeHeight)))) {
        //NSLog(@"out of active paper area");
        return;
    }
    int arrayY = (y - _currentPageInfo->activeStartY) / (_currentPageInfo->spanY);
    int arrayX = (x - _currentPageInfo->activeStartX) /(_currentPageInfo->spanX);
    //NSLog(@"arrayX: %d, arrayY: %d",arrayX, arrayY);
    
    if (arrayY >= [_dataRowArray count]) {
        //NSLog(@"arrayY is beyond array count");
        return;
    }
    
    NSMutableArray *subArray = [_dataRowArray objectAtIndex:arrayY];
    
    if (arrayX >= [subArray count]) {
        //NSLog(@"arrayX is beyond array count");
        return;
    }
    
    if (_currentPageInfo->cmd == Email) {
        //NSLog(@"Email command, before sendOneTime");
        if([subArray[arrayX] intValue] == Email){
            if (_sendOneTime) {
                NSLog(@"Email command, sendOneTime YES");
                //delegate
                if (self.commandHandler != nil) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.commandHandler sendEmailWithPdf];
                    });
                }
                _sendOneTime = NO;
            }
        }
    }
}

- (void)updateIdleCounter:(NSTimer *)timer
{
    if (self.penDown) return;
    if ([self.voiceManager isRecording]) {
        self.idleCounter = IDLE_COUNT;
        return;
    }
    self.idleCounter--;
    if (self.idleCounter <= 0) {
        _commManager.writeActiveState = NO;
    
        [self stopIdleCounter];
    }
}
- (void)stopIdleCounter
{
    [self.idleTimer invalidate];
    self.idleTimer = nil;
}
- (void) parsePenUpDowneData:(unsigned char *)data withLength:(int) length
{
    // see the setter for _penDown. It is doing something important.
    COMM_PENUP_DATA *updownData = (COMM_PENUP_DATA *)data;
    if (updownData->upDown == 0) {
        
        self.penDown = YES;
        node_count_pen = -1;
        node_count = 0;
        self.idleCounter = IDLE_COUNT;
        UInt32 color = updownData->penColor;
        if ((color & 0xFF000000) == 0x01000000 && (color & 0x00FFFFFF) != 0x00FFFFFF && (color & 0x00FFFFFF) != 0x00000000) {
            penColor = color | 0xFF000000; // set Alpha to 255
        }

        NSLog(@"Pen color 0x%x", (unsigned int)penColor);
        
    }
    else {
        [self dotCheckerLast];
        self.penDown = NO;
        
        self.idleCounter = IDLE_COUNT;
        if (self.idleTimer == nil) {
            _commManager.writeActiveState = YES;
#ifdef USE_STROKE_IDLE_TIMER   //this function removed from doc.
            self.idleTimer = [NSTimer timerWithTimeInterval:IDLE_TIMER_INTERVAL target:self
                                                   selector:@selector(updateIdleCounter:) userInfo:nil repeats:YES];
            [[NSRunLoop mainRunLoop] addTimer:self.idleTimer forMode:NSDefaultRunLoopMode];
#endif
        }
    }
    
    UInt64 time = updownData->time;
    NSNumber *timeNumber = [NSNumber numberWithLongLong:time];
    NSNumber *color = [NSNumber numberWithUnsignedInteger:penColor];
    NSString *status = (self.penDown) ? @"down":@"up";
    NSDictionary *stroke = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"updown", @"type",
                            timeNumber, @"time",
                            status, @"status",
                            color, @"color",
                            nil];
    if (self.strokeHandler != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.strokeHandler processStroke:stroke];
        });
    }
}
- (void) parsePenNewIdData:(unsigned char *)data withLength:(int) length
{
    COMM_CHANGEDID2_DATA *newIdData = (COMM_CHANGEDID2_DATA *)data;
    unsigned char section = (newIdData->owner_id >> 24) & 0xFF;
    UInt32 owner = newIdData->owner_id & 0x00FFFFFF;
    UInt32 noteId = newIdData->note_id;
    UInt32 pageNumber = newIdData->page_id;
    NSLog(@"section : %d, owner : %d, note : %d, page : %d", section, (unsigned int)owner, (unsigned int)noteId, (unsigned int)pageNumber);
    
    // Handle seal if section is 4.
    if (section == SEAL_SECTION_ID) {
        // Note ID is delivered as owner ID.
        _sealReceived = YES;         //To ignore stroke.

        return;
    }
    _sealReceived = NO;
    
    if (!_requestNewPageNotification && (_activeNotebookId == noteId) && (_activePaperNum == pageNumber) && (_activeOwnerId == owner) && (_activeSectionId == section))  return;
    _requestNewPageNotification = NO;
    _activeNotebookId = noteId;
    _activePaperNum = pageNumber;
    _activeOwnerId = owner;
    _activeSectionId = section;
    
    NSLog(@"New Id Data noteId %u, pageNumber %u", (unsigned int)noteId, (unsigned int)pageNumber);
    self.paperInfo = [[NJNotebookPaperInfo sharedInstance] getNotePaperInfoForNotebook:(int)noteId pageNum:(int)pageNumber section:(int)section owner:(int)owner];
    _startX = self.paperInfo.startX;
    _startY = self.paperInfo.startY;
    
    if (self.canvasStartDelegate) {
        dispatch_async(dispatch_get_main_queue(), ^{

            [self.canvasStartDelegate activeNoteIdForFirstStroke:(int)noteId pageNum:(int)pageNumber sectionId:(int)section ownderId:(int)owner];
            
        });
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.strokeHandler != nil){
            [self.strokeHandler notifyPageChanging];
            [self.strokeHandler activeNoteId:(int)noteId pageNum:(int)pageNumber sectionId:(int)section ownderId:(int)owner];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:NJPenCommParserPageChangedNotification object:nil userInfo:nil];
    });
}

- (void) parsePenStatusData:(unsigned char *)data withLength:(int) length
{
    self.penStatus = (PenStateStruct *)data;
    NSLog(@"penStatus %d, timezoneOffset %d, timeTick %llu", self.penStatus->penStatus, self.penStatus->timezoneOffset, self.penStatus->timeTick);
    NSLog(@"pressureMax %d, battery %d, memory %d", self.penStatus->pressureMax, self.penStatus->battLevel, self.penStatus->memoryUsed);
    NSLog(@"autoPwrOffTime %d, penPressure %d", self.penStatus->autoPwrOffTime, self.penStatus->penPressure);

    NSLog(@"Getting penstatus finished");
    
    //SDK2.0 later
    if (!_commManager.isPenSDK2) {
        pressureMax = self.penStatus->pressureMax;
    }
    
    //SDK2.0
    if (_commManager.isPenSDK2) {
        if (self.penStatus2->offlineOnOff == 0) {
            unsigned char pOfflineOnOff = 1;
            [self setPenState2WithType:PENSTATETYPE_OFFLINESAVE andValue:pOfflineOnOff];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.penStatusDelegate penStatusData:self.penStatus];
    });

    if (self.battMemoryBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.battMemoryBlock(self.penStatus -> battLevel, self.penStatus -> memoryUsed);
            self.battMemoryBlock = nil;
        });
        NSLog(@"battMemoryBlock != nil");
        return;
    }
}

//#define FW_UPDATE_TEST
- (void) parseOfflineFileList:(unsigned char *)data withLength:(int) length
{
    OfflineFileListStruct *fileList = (OfflineFileListStruct *)data;
    int noteCount = MIN(fileList->noteCount, 10);
    
    unsigned char section = (fileList->sectionOwnerId >> 24) & 0xFF;
    UInt32 ownerId = fileList->sectionOwnerId & 0x00FFFFFF;
    
    NJNotebookPaperInfo *notebookInfo = [NJNotebookPaperInfo sharedInstance];
    //exclude owner 28
    NSString *sectionOwnerStr = [NSString stringWithFormat:@"%05tu_%05tu",(NSUInteger)section,(NSUInteger)ownerId];
    
    if ([notebookInfo hasInfoForSectionId:(int)section OwnerId:(int)ownerId]){
        dispatch_async(dispatch_get_main_queue(), ^{
            if(!isEmpty(self.offlineDataDelegate) && [self.offlineDataDelegate respondsToSelector:@selector(offlineDataDidReceiveNoteListCount:ForSectionOwnerId:)])
                [self.offlineDataDelegate offlineDataDidReceiveNoteListCount:noteCount ForSectionOwnerId:fileList->sectionOwnerId];
        });
    }
    
#ifdef FW_UPDATE_TEST
    {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = paths[0];
    NSString *updateFilePath = [documentDirectory stringByAppendingPathComponent:@"Update.zip"];
    NSURL *url = [NSURL fileURLWithPath:updateFilePath];
    [self sendUpdateFileInfoAtUrl:url];
    }
#endif
    
    if (noteCount == 0) return;
    //exclude owner 28
    if ([notebookInfo hasInfoForSectionId:(int)section OwnerId:(int)ownerId]){
        if (section == SEAL_SECTION_ID) {
            //Just ignore for offline data
            [self requestDelOfflineFile:fileList->sectionOwnerId];
        }
        else {
            NSNumber *sectionOwnerId = [NSNumber numberWithUnsignedInteger:fileList->sectionOwnerId];
            
            NSMutableArray *noteArray = [_offlineFileList objectForKey:sectionOwnerId];
            if (noteArray == nil) {
                noteArray = [[NSMutableArray alloc] initWithCapacity:noteCount];
                [_offlineFileList setObject:noteArray forKey:sectionOwnerId];
            }
            NSLog(@"OfflineFileList owner : %@", sectionOwnerId);
            for (int i=0; i < noteCount; i++) {
                NSNumber *noteId = [NSNumber numberWithUnsignedInteger:fileList->noteId[i]];
                NSLog(@"OfflineFileList note : %@", noteId);
                [noteArray addObject:noteId];
            }
        }
    }
    
    if (fileList->status == 0) {
        NSLog(@"More offline File List remained");
    }
    else {
        if ([[_offlineFileList allKeys] count] > 0) {
            NSLog(@"Getting offline File List finished");
            dispatch_async(dispatch_get_main_queue(), ^{
                if(!isEmpty(self.offlineDataDelegate) && [self.offlineDataDelegate respondsToSelector:@selector(offlineDataDidReceiveNoteList:)])
                    [self.offlineDataDelegate offlineDataDidReceiveNoteList:_offlineFileList];
            });
        }
    }
}

-(BOOL) requestNextOfflineNote
{
    _offlineFileProcessing = YES;
    BOOL needNext = YES;
    NSEnumerator *enumerator = [_offlineFileList keyEnumerator];
    while (needNext) {
        NSNumber *ownerId = [enumerator nextObject];
        if (ownerId == nil) {
            _offlineFileProcessing = NO;
            NSLog(@"Offline data : no more file left");
            return NO;
        }
        NSArray *noteList = [_offlineFileList objectForKey:ownerId];
        if ([noteList count] == 0) {
            [_offlineFileList removeObjectForKey:ownerId];
            continue;
        }
        NSNumber *noteId = [noteList objectAtIndex:0];
        _offlineOwnerIdRequested = (UInt32)[ownerId unsignedIntegerValue];
        _offlineNoteIdRequested = (UInt32)[noteId unsignedIntegerValue];
        [self requestOfflineDataWithOwnerId:_offlineOwnerIdRequested noteId:_offlineNoteIdRequested];
        needNext = NO;
    }
    return YES;
}
-(void) didReceiveOfflineFileForOwnerId:(UInt32)ownerId noteId:(UInt32)noteId
{
    NSNumber *ownerNumber = [NSNumber numberWithUnsignedInteger:_offlineOwnerIdRequested];
    NSNumber *noteNumber = [NSNumber numberWithUnsignedInteger:_offlineNoteIdRequested];
    NSMutableArray *noteList = [_offlineFileList objectForKey:ownerNumber];
    if (noteList == nil) {
        return;
    }
    NSUInteger index = [noteList indexOfObject:noteNumber];
    if (index == NSNotFound) {
        return;
    }
    [noteList removeObjectAtIndex:index];
}
- (void) parseOfflineFileListInfo:(unsigned char *)data withLength:(int) length
{
    OfflineFileListInfoStruct *fileInfo = (OfflineFileListInfoStruct *)data;
    NSLog(@"OfflineFileListInfo file Count %d, size %d", (unsigned int)fileInfo->fileCount, (unsigned int)fileInfo->fileSize);
    _offlineTotalDataSize = fileInfo->fileSize;
    _offlineTotalDataReceived = 0;
    [self notifyOfflineDataStatus:OFFLINE_DATA_RECEIVE_START percent:0.0f];
}
- (void) parseOfflineFileInfoData:(unsigned char *)data withLength:(int) length
{
    OFFLINE_FILE_INFO_DATA *fileInfo = (OFFLINE_FILE_INFO_DATA *)data;
    if (fileInfo->type == 1) {
        NSLog(@"Offline File Info : Zip file");
    }
    else {
        NSLog(@"Offline File Info : Normal file");
    }
    UInt32 fileSize = fileInfo->file_size;
    self.offlinePacketCount = fileInfo->packet_count;
    _offlinePacketSize = fileInfo->packet_size;
    _offlineSliceCount = fileInfo->slice_count;
    _offlineSliceSize = fileInfo->slice_size;
    self.offlineSliceIndex = 0;
    NSLog(@"File size : %d, packet count : %d, packet size : %d", (unsigned int)fileSize, self.offlinePacketCount, _offlinePacketSize);
    NSLog(@"Slice count : %d, slice size : %d", (unsigned int)self.offlineSliceCount, _offlineSliceSize);
    _offlineLastPacketIndex = fileSize/_offlinePacketSize;
    int lastPacketSize = fileSize % _offlinePacketSize;
    if (lastPacketSize == 0) {
        _offlineLastPacketIndex -= 1;
        _offlineLastSliceIndex = _offlineSliceCount - 1;
        _offlineLastSliceSize = _offlineSliceSize;
    }
    else {
        _offlineLastSliceIndex = lastPacketSize / _offlineSliceSize;
        _offlineLastSliceSize = lastPacketSize % _offlineSliceSize;
        if (_offlineLastSliceSize == 0) {
            _offlineLastSliceIndex -= 1;
            _offlineLastSliceSize = _offlineSliceSize;
        }
    }
    self.offlineData = [[NSMutableData alloc] initWithLength:fileSize];
    self.offlinePacketData = nil;
    self.offlineDataOffset = 0;
    self.offlineDataSize = fileSize;
    [self offlineFileAckForType:1 index:0];  // 1 : header, index 0
}
//#define SPEED_TEST
#ifdef SPEED_TEST
static NSTimeInterval startTime4Speed, endTime4Speed;
static int length4Speed;
#endif
- (void) parseOfflineFileData:(unsigned char *)data withLength:(int) length
{
    static int expected_slice = -1;
    static BOOL slice_valid = YES;

    OFFLINE_FILE_DATA *fileData = (OFFLINE_FILE_DATA *)data;
    int index = fileData->index;
    int slice_index = fileData->slice_index;
    unsigned char *dataReceived = &(fileData->data);
    if (slice_index == 0) {
        expected_slice = -1;
        slice_valid = YES;
        self.offlinePacketOffset = 0;
        self.offlinePacketData = [[NSMutableData alloc] initWithCapacity:_offlinePacketSize];
    }
    int lengthToCopy = length - sizeof(fileData->index) - sizeof(fileData->slice_index);
    lengthToCopy = MIN(lengthToCopy, self.offlineSliceSize);
    if (index == _offlineLastPacketIndex && slice_index == _offlineLastSliceIndex) {
        lengthToCopy = _offlineLastSliceSize;
    }
    else if ((self.offlinePacketOffset + lengthToCopy) > self.offlinePacketSize) {
        lengthToCopy = self.offlinePacketSize - self.offlinePacketOffset;
    }
    NSLog(@"Data index : %d, slice index : %d, data size received: %d copied : %d", index, slice_index, length, lengthToCopy);
#ifdef SPEED_TEST
    if (index == 0 && slice_index == 0) {
        startTime4Speed = [[NSDate date] timeIntervalSince1970];
        length4Speed = 0;
    }
    length4Speed += length;
#endif
    if (slice_valid == NO) {
        return;
    }
    expected_slice++;
    if (expected_slice != slice_index ) {
        NSLog(@"Bad slice index : expected %d, received %d", expected_slice, slice_index);
        slice_valid = NO;
        return; // Wait for next start
    }
    [self.offlinePacketData appendBytes:dataReceived length:lengthToCopy];
    _offlinePacketOffset += lengthToCopy;
    if (slice_index == (_offlineSliceCount - 1) || (index == _offlineLastPacketIndex && slice_index == _offlineLastSliceIndex) ) {
        [self offlineFileAckForType:2 index:(unsigned char)index]; // 2 : data
        NSRange range = {index*_offlinePacketSize, _offlinePacketOffset};
        [_offlineData replaceBytesInRange:range withBytes:[_offlinePacketData bytes]];
        _offlineDataOffset += _offlinePacketOffset;
        _offlinePacketOffset = 0;
        float percent = (float)((_offlineTotalDataReceived + _offlineDataOffset) * 100.0)/(float)_offlineTotalDataSize;
        [self notifyOfflineDataStatus:OFFLINE_DATA_RECEIVE_PROGRESSING percent:percent];
        NSLog(@"offlineDataOffset=%d, offlineDataSize=%d", _offlineDataOffset, _offlineDataSize);
    }
    if (self.offlineDataOffset >= self.offlineDataSize) {
#ifdef SPEED_TEST
        endTime4Speed = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval timeLapse = endTime4Speed - startTime4Speed;
        NSLog(@"Offline receiving speed %f bytes/sec", length4Speed/timeLapse);
#endif
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = paths[0];
        NSString *offlineFilePath = [documentDirectory stringByAppendingPathComponent:@"OfflineFile"];
        NSURL *url = [NSURL fileURLWithPath:offlineFilePath];
        NSFileManager *fm = [NSFileManager defaultManager];
        __block NSError *error = nil;
        [fm createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error];
        NSString *path = [offlineFilePath stringByAppendingPathComponent:@"offlineFile.zip"];
        [fm createFileAtPath:path contents:self.offlineData attributes:nil];
        //NISDK
        dispatch_async(dispatch_get_main_queue(), ^{
            if(!isEmpty(self.offlineDataDelegate) && [self.offlineDataDelegate respondsToSelector:@selector(offlineDataPathBeforeParsed:)])
                [self.offlineDataDelegate offlineDataPathBeforeParsed:path];
        });
        ZZArchive* offlineZip = [ZZArchive archiveWithURL:[NSURL fileURLWithPath:path] error:nil];
        ZZArchiveEntry* penDataEntry = offlineZip.entries[0];
        if ([penDataEntry check:&error]) {
            // GOOD
            NSLog(@"Offline zip file received successfully");
            NSData *penData = [penDataEntry newDataWithError:&error];
            if (penData != nil) {
                [self.offlineDataDelegate parseOfflinePenData:penData];
            }
            _offlineTotalDataReceived += _offlineDataSize;
        }
        else {
            // BAD
            NSLog(@"Offline zip file received badly");
        }
        _offlinePacketOffset = 0;
        _offlinePacketData = nil;
    }
}
- (void) parseOfflineFileStatus:(unsigned char *)data withLength:(int) length
{
    OfflineFileStatusStruct *fileStatus = (OfflineFileStatusStruct *)data;
    if (fileStatus->status == 1) {
        NSLog(@"OfflineFileStatus success");
        [self didReceiveOfflineFileForOwnerId:_offlineOwnerIdRequested noteId:_offlineNoteIdRequested];
        [self notifyOfflineDataStatus:OFFLINE_DATA_RECEIVE_END percent:100.0f];
    }
    else {
        NSLog(@"OfflineFileStatus fail");
        [self notifyOfflineDataStatus:OFFLINE_DATA_RECEIVE_FAIL percent:0.0f];
    }
}

- (void) dotCheckerForOfflineSync:(OffLineDataDotStruct *)aDot pointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    if (offlineDotCheckState == OFFLINE_DOT_CHECK_NORMAL) {
        if ([self offlineDotCheckerForMiddle:aDot]) {
            [self offlineDotAppend:&offlineDotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
            offlineDotData0 = offlineDotData1;
            offlineDotData1 = offlineDotData2;
        }
        else {
            NSLog(@"offlineDotChecker error : middle");
        }
        offlineDotData2 = *aDot;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_FIRST) {
        offlineDotData0 = *aDot;
        offlineDotData1 = *aDot;
        offlineDotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_SECOND;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_SECOND) {
        offlineDotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_THIRD;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_THIRD) {
        if ([self offlineDotCheckerForStart:aDot]) {
            [self offlineDotAppend:&offlineDotData1 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
            if ([self offlineDotCheckerForMiddle:aDot]) {
                [self offlineDotAppend:&offlineDotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
                offlineDotData0 = offlineDotData1;
                offlineDotData1 = offlineDotData2;
            }
            else {
                NSLog(@"offlineDotChecker error : middle2");
            }
        }
        else {
            offlineDotData1 = offlineDotData2;
            NSLog(@"offlineDotChecker error : start");
        }
        offlineDotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_NORMAL;
    }
}

- (void) offlineDotAppend:(OffLineDataDotStruct *)dot pointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    float pressure, x, y;
    
    x = (float)dot->x + (float)dot->fx * 0.01f;
    y = (float)dot->y + (float)dot->fy * 0.01f;
    pressure = [self processPressure:(float)dot->force];
    point_x_buff[point_index] = x - _startX;
    point_y_buff[point_index] = y - _startY;
    point_p_buff[point_index] = pressure;
    time_diff_buff[point_index] = dot->nTimeDelta;
    point_index++;
}

- (BOOL) offlineDotCheckerForStart:(OffLineDataDotStruct *)aDot
{
    static const float delta = 10.0f;
    if (offlineDotData1.x > 150 || offlineDotData1.x < 1) return NO;
    if (offlineDotData1.y > 150 || offlineDotData1.y < 1) return NO;
    if ((aDot->x - offlineDotData1.x) * (offlineDotData2.x - offlineDotData1.x) > 0
        && ABS(aDot->x - offlineDotData1.x) > delta && ABS(offlineDotData1.x - offlineDotData2.x) > delta)
    {
        return NO;
    }
    if ((aDot->y - offlineDotData1.y) * (offlineDotData2.y - offlineDotData1.y) > 0
        && ABS(aDot->y - offlineDotData1.y) > delta && ABS(offlineDotData1.y - offlineDotData2.y) > delta)
    {
        return NO;
    }
    return YES;
}
- (BOOL) offlineDotCheckerForMiddle:(OffLineDataDotStruct *)aDot
{
    static const float delta = 10.0f;
    if (offlineDotData2.x > 150 || offlineDotData2.x < 1) return NO;
    if (offlineDotData2.y > 150 || offlineDotData2.y < 1) return NO;
    if ((offlineDotData1.x - offlineDotData2.x) * (aDot->x - offlineDotData2.x) > 0
        && ABS(offlineDotData1.x - offlineDotData2.x) > delta && ABS(aDot->x - offlineDotData2.x) > delta)
    {
        return NO;
    }
    if ((offlineDotData1.y - offlineDotData2.y) * (aDot->y - offlineDotData2.y) > 0
        && ABS(offlineDotData1.y - offlineDotData2.y) > delta && ABS(aDot->y - offlineDotData2.y) > delta)
    {
        return NO;
    }
    
    return YES;
}
- (BOOL) offlineDotCheckerForEnd
{
    static const float delta = 10.0f;
    if (offlineDotData2.x > 150 || offlineDotData2.x < 1) return NO;
    if (offlineDotData2.y > 150 || offlineDotData2.y < 1) return NO;
    if ((offlineDotData2.x - offlineDotData0.x) * (offlineDotData2.x - offlineDotData1.x) > 0
        && ABS(offlineDotData2.x - offlineDotData0.x) > delta && ABS(offlineDotData2.x - offlineDotData1.x) > delta)
    {
        return NO;
    }
    if ((offlineDotData2.y - offlineDotData0.y) * (offlineDotData2.y - offlineDotData1.y) > 0
        && ABS(offlineDotData2.y - offlineDotData0.y) > delta && ABS(offlineDotData2.y - offlineDotData1.y) > delta)
    {
        return NO;
    }
    return YES;
}

- (void) offlineDotCheckerLastPointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    if ([self offlineDotCheckerForEnd]) {
        [self offlineDotAppend:&offlineDotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
        offlineDotData2.x = 0.0f;
        offlineDotData2.y = 0.0f;
    }
    else {
        NSLog(@"offlineDotChecker error : end");
    }
    offlineDotCheckState = OFFLINE_DOT_CHECK_NONE;
}

#if 0  //Offline sync : thread sync test code for future reference
- (BOOL) parseOfflinePenData_new:(NSData *)penData
{
    int dataPosition=0;
    unsigned long dataLength = [penData length];
    int headerSize = sizeof(OffLineDataFileHeaderStruct);
    dataLength -= headerSize;
    NSRange range = {dataLength, headerSize};
    OffLineDataFileHeaderStruct header;
    [penData getBytes:&header range:range];
    NSMutableArray *strokes = [[NSMutableArray alloc] init];
    NSDictionary __block *offlineStrokes = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:header.nNoteId], @"note_id",
                                            [NSNumber numberWithUnsignedInteger:header.nPageId], @"page_number",
                                            strokes, @"strokes", nil];
    unsigned char char1, char2;
    OffLineDataStrokeHeaderStruct strokeHeader;
    while (dataPosition < dataLength) {
        if ((dataLength - dataPosition) < (sizeof(OffLineDataStrokeHeaderStruct) + 2)) break;
        range.location = dataPosition++;
        range.length = 1;
        [penData getBytes:&char1 range:range];
        range.location = dataPosition++;
        [penData getBytes:&char2 range:range];
        if (char1 == 'L' && char2 == 'N') {
            range.location = dataPosition;
            range.length = sizeof(OffLineDataStrokeHeaderStruct);
            [penData getBytes:&strokeHeader range:range];
            dataPosition += sizeof(OffLineDataStrokeHeaderStruct);
            if ((dataLength - dataPosition) < (strokeHeader.nDotCount * sizeof(OffLineDataDotStruct))) {
                break;
            }
            [self parseOfflineDots:penData startAt:dataPosition withFileHeader:&header andStrokeHeader:&strokeHeader toArray:strokes];
            dataPosition += (strokeHeader.nDotCount * sizeof(OffLineDataDotStruct));
        }
    }
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"dispatch_async start");
        
        UInt32 noteIdBackup = 0;
        UInt32 pageIdBackup = 0;
        BOOL   hasPageBackup = NO;
        if (self.strokeHandler) {
            [self.strokeHandler notifyDataUpdating:YES];
        }
        NSNumber *value = (NSNumber *)[offlineStrokes objectForKey:@"note_id"] ;
        UInt32 noteId = (UInt32)[value unsignedIntegerValue];
        value = (NSNumber *)[offlineStrokes objectForKey:@"page_number"] ;
        UInt32 pageId = (UInt32)[value unsignedIntegerValue];
        if (self.writerManager.activeNoteBookId != noteId || self.writerManager.activePageNumber != pageId) {
            noteIdBackup = (UInt32)self.writerManager.activeNoteBookId;
            pageIdBackup = (UInt32)self.writerManager.activePageNumber;
            hasPageBackup = YES;
            NSLog(@"Offline New Id Data noteId %u, pageNumber %u", (unsigned int)noteId, (unsigned int)pageId);
            //Chage X, Y start cordinates.
            [self.paperInfo getPaperDotcodeStartForNotebook:(int)noteId startX:&_startX startY:&_startY];
            [self.writerManager activeNotebookIdDidChange:noteId withPageNumber:pageId];
        }
        NSArray *strokeSaved = (NSArray *)[offlineStrokes objectForKey:@"strokes"] ;
        for (int i = 0; i < [strokeSaved count]; i++) {
            NJStroke *a_stroke = strokeSaved[i];
            [self.activePageDocument.page insertStrokeByTimestamp:a_stroke];
        }
        [self.writerManager saveCurrentPageWithEventlog:YES andEvernote:YES andLastStrokeTime:[NSDate dateWithTimeIntervalSince1970:(self.offlineLastStrokeStartTime / 1000.0)]];
        if (hasPageBackup && noteIdBackup > 0) {
            [self.paperInfo getPaperDotcodeStartForNotebook:(int)noteIdBackup startX:&_startX startY:&_startY];
            [self.writerManager activeNotebookIdDidChange:noteIdBackup withPageNumber:pageIdBackup];
        }
        if (self.strokeHandler) {
            [self.strokeHandler notifyDataUpdating:NO];
        }
        NSLog(@"dispatch_semaphore_signal");
        dispatch_semaphore_signal(semaphore);
    });
    NSLog(@"dispatch_semaphore_wait start");
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"dispatch_semaphore_wait end");
    return YES;
}
- (void) parseOfflineDots:(NSData *)penData startAt:(int)position withFileHeader:(OffLineDataFileHeaderStruct *)pFileHeader
          andStrokeHeader:(OffLineDataStrokeHeaderStruct *)pStrokeHeader toArray:(NSMutableArray *)strokes
{
    OffLineDataDotStruct dot;
    float pressure, x, y;
    NSRange range = {position, sizeof(OffLineDataDotStruct)};
    int dotCount = MIN(MAX_NODE_NUMBER, pStrokeHeader->nDotCount);
    float *point_x_buff = malloc(sizeof(float)* dotCount);
    float *point_y_buff = malloc(sizeof(float)* dotCount);
    float *point_p_buff = malloc(sizeof(float)* dotCount);
    int *time_diff_buff = malloc(sizeof(int)* dotCount);
    int point_index = 0;
    
    startTime = pStrokeHeader->nStrokeStartTime;
    //    NSLog(@"offline time %llu", startTime);
#ifdef HAS_LINE_COLOR
    UInt32 color = pStrokeHeader->nLineColor;
    if ((color & 0x00FFFFFF) != 0x00FFFFFF && (color & 0x00FFFFFF) != 0x00000000) {
        offlinePenColor = color | 0xFF000000; // set Alpha to 255
    }
    else
        offlinePenColor = 0;
#else
    offlinePenColor = 0;
#endif
    offlinePenColor = penColor; // 2015-01-28 add for maintaining color feature
    NSLog(@"offlinePenColor 0x%x", (unsigned int)offlinePenColor);
    float paperStartX, paperStartY;
    float paperSizeX, paperSizeY;
    [self.paperInfo getPaperDotcodeStartForNotebook:(int)pFileHeader->nNoteId startX:&paperStartX startY:&paperStartY];
    [self.paperInfo getPaperDotcodeRangeForNotebook:(int)pFileHeader->nNoteId Xmax:&paperSizeX Ymax:&paperSizeY];
    float normalizeScale = MAX(paperSizeX, paperSizeY);
    for (int i =0; i < pStrokeHeader->nDotCount; i++) {
        [penData getBytes:&dot range:range];
        x = (float)dot.x + (float)dot.fx * 0.01f;
        y = (float)dot.y + (float)dot.fy * 0.01f;
        pressure = [self processPressure:(float)dot.force];
        point_x_buff[point_index] = x - paperStartX;
        point_y_buff[point_index] = y - paperStartY;
        point_p_buff[point_index] = pressure;
        time_diff_buff[point_index] = dot.nTimeDelta;
        point_index++;
        //        NSLog(@"x %f, y %f, pressure %f, o_p %f", x, y, pressure, (float)dot.force);
        if(point_index >= MAX_NODE_NUMBER){
            NJStroke *stroke = [[NJStroke alloc] initWithRawDataX:point_x_buff Y:point_y_buff pressure:point_p_buff time_diff:time_diff_buff
                                                         penColor:offlinePenColor penThickness:_penThickness startTime:startTime size:point_index normalizer:normalizeScale];
            [strokes addObject:stroke];
            point_index = 0;
        }
        position += sizeof(OffLineDataDotStruct);
        range.location = position;
    }
    NJStroke *stroke = [[NJStroke alloc] initWithRawDataX:point_x_buff Y:point_y_buff pressure:point_p_buff time_diff:time_diff_buff
                                                 penColor:offlinePenColor penThickness:_penThickness startTime:startTime size:point_index normalizer:normalizeScale];
    [strokes addObject:stroke];
    free(point_x_buff);
    free(point_y_buff);
    free(point_p_buff);
    free(time_diff_buff);
}
#endif
- (void) notifyOfflineDataStatus:(OFFLINE_DATA_STATUS)status percent:(float)percent
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.offlineDataDelegate offlineDataReceiveStatus:status percent:percent];
    });
}
- (void) notifyOfflineDataFileListDidReceive
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.offlineDataDelegate offlineDataDidReceiveNoteList:_offlineFileList];
    });
}
- (void) parseRequestUpdateFile:(unsigned char *)data withLength:(int) length
{
    RequestUpdateFileStruct *request = (RequestUpdateFileStruct *)data;
    if (!_cancelFWUpdate) {
        [self sendUpdateFileDataAt:request->index];
    }
}
- (void) parseUpdateFileStatus:(unsigned char *)data withLength:(int) length
{
    UpdateFileStatusStruct *status = (UpdateFileStatusStruct *)data;
    
    if (status->status == 1) {
        [self notifyFWUpdateStatus:FW_UPDATE_DATA_RECEIVE_END percent:100];
    }else if(status->status == 0){
        [self notifyFWUpdateStatus:FW_UPDATE_DATA_RECEIVE_FAIL percent:0.0f];
    }else if(status->status == 3){
        NSLog(@"out of pen memory space");
    }
    
    NSLog(@"parseUpdateFileStatus status %d", status->status);
}

- (void) notifyFWUpdateStatus:(FW_UPDATE_DATA_STATUS)status percent:(float)percent
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.fwUpdateDelegate fwUpdateDataReceiveStatus:status percent:percent];
    });
}

- (void) parseReadyExchangeDataRequest:(unsigned char *)data withLength:(int) length
{
    ReadyExchangeDataRequestStruct *request = (ReadyExchangeDataRequestStruct *)data;
    if (request->ready == 0) {
        _isReadyExchangeSent = NO;
        NSLog(@"2AB5 was sent to App because a pen was turned off by itself.");
    }
    if (_isReadyExchangeSent) {
        NSLog(@"2AB4 was already sent to Pen. So, 2AB5 request is not proceeded again");
        return;
    }
    if(!_commManager.isPenSDK2)
        self.penExchangeDataReady = (request->ready == 1);
    
}


- (void) parseFWVersion:(unsigned char *)data withLength:(int) length
{
    self.fwVersion = [[NSString alloc] initWithBytes:data length:length encoding:NSUTF8StringEncoding];
    
}

#pragma mark - Send data
//SDK2.0

- (void)setVersionInfo
{
    SetVersionInfoStruct setVersionInfo;
    
    UInt8  sof, cmd, eof; UInt16 length, appType;
    unsigned char connectionCode[16]; unsigned char appVer[16];
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x01;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];

    length = sizeof(setVersionInfo) - sizeof(cmd) - sizeof(length);// - 2;
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    memset(connectionCode, 0, sizeof(connectionCode));
    [tempPacketData appendBytes:&connectionCode length:sizeof(connectionCode)];
    
    appType = 0x1001;
    [tempPacketData appendBytes:&appType length:sizeof(UInt16)];
    
    memset(appVer, 0, sizeof(appVer));
    NSString *inputStr = [MyFunctions appVersion];;
    NSData *stringData = [inputStr dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(appVer, [stringData bytes], sizeof(stringData));
    [tempPacketData appendBytes:&appVer length:sizeof(appVer)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"version info 0x01 data %@", data);
    [_commManager writePen2SetData:data];
}

- (void) setComparePasswordSDK2:(NSString *)pinNumber
{
    SetPenPasswordStruct penPassword;
    
    UInt8  sof, cmd, eof; UInt16 length;
    unsigned char password[16];
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x02;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    length = sizeof(penPassword) - sizeof(cmd) - sizeof(length);// - 2;
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    memset(password, 0, sizeof(password));
    NSData *stringData = [pinNumber dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(password, [stringData bytes], sizeof(stringData));
    for(int i = 0 ; i < 12 ; i++)
    {
        password[i+4] = (unsigned char)NULL;
    }
    [tempPacketData appendBytes:&password length:sizeof(password)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"compare password 0x02 data %@", data);
    [_commManager writePen2SetData:data];
}

- (void) setPasswordSDK2:(NSString *)pinNumber
{
    SetChangePenPasswordStruct changePenPassword;
    UInt8  sof, eof;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    changePenPassword.cmd = 0x03;
    changePenPassword.length = sizeof(changePenPassword) - sizeof(changePenPassword.cmd) - sizeof(changePenPassword.length);// - 2;
    
    changePenPassword.usePwd = 1;
    
    memset(changePenPassword.oldPassword, 0, sizeof(changePenPassword.oldPassword));
    NSString *currentPassword = @"0000";
    NSData *stringData = [currentPassword dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(changePenPassword.oldPassword, [stringData bytes], sizeof(stringData));
    
    memset(changePenPassword.newPassword, 0, sizeof(changePenPassword.newPassword));
    NSData *newData = [pinNumber dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(changePenPassword.newPassword, [newData bytes], sizeof(newData));
    
    for(int i = 0 ; i < 12 ; i++)
    {
        changePenPassword.oldPassword[i+4] = (unsigned char)NULL;
        changePenPassword.newPassword[i+4] = (unsigned char)NULL;
    }
    
    NSMutableData *tempPacketData = [NSMutableData dataWithBytes:&changePenPassword length:sizeof(SetChangePenPasswordStruct)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"setPasswordSDK2 0x03 data %@", data);
    
    [_commManager writePen2SetData:data];
    
}

- (void) setChangePasswordSDK2From:(NSString *)curNumber To:(NSString *)pinNumber
{
    SetChangePenPasswordStruct changePenPassword;
    UInt8  sof, eof;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    changePenPassword.cmd = 0x03;
    changePenPassword.length = sizeof(changePenPassword) - sizeof(changePenPassword.cmd) - sizeof(changePenPassword.length);// - 2;
    
    changePenPassword.usePwd = 1;
    
    memset(changePenPassword.oldPassword, 0, sizeof(changePenPassword.oldPassword));
    NSData *stringData = [curNumber dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(changePenPassword.oldPassword, [stringData bytes], sizeof(stringData));
    
    memset(changePenPassword.newPassword, 0, sizeof(changePenPassword.newPassword));
    NSData *newData = [pinNumber dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(changePenPassword.newPassword, [newData bytes], sizeof(newData));
    
    for(int i = 0 ; i < 12 ; i++)
    {
        changePenPassword.oldPassword[i+4] = (unsigned char)NULL;
        changePenPassword.newPassword[i+4] = (unsigned char)NULL;
    }
    NSMutableData *tempPacketData = [NSMutableData dataWithBytes:&changePenPassword length:sizeof(SetChangePenPasswordStruct)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"setChangePasswordSDK2 0x03 data %@", data);
    
    [_commManager writePen2SetData:data];
    
}

- (void) setRequestPenState
{
    SetRequestPenStateStruct requestPenState;
    
    UInt8  sof, cmd, eof; UInt16 length;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x04;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    length = sizeof(requestPenState) - sizeof(cmd) - sizeof(length);// - 2;
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"setRequest penState 0x04 data %@", data);
    [_commManager writePen2SetData:data];
}

- (void)setPenState2WithType:(UInt8)type andValue:(UInt8)value
{
    UInt8  sof, cmd, eof; UInt16 length;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x05;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    length = sizeof(type) + sizeof(value);
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    [tempPacketData appendBytes:&type length:sizeof(UInt8)];
    
    [tempPacketData appendBytes:&value length:sizeof(UInt8)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"setPenState2WithType 0x5 data %@", data);
    [_commManager writePen2SetData:data];
    
}

- (void)setPenState2WithTypeAndTimeStamp
{
    UInt8  sof, cmd, eof, type; UInt16 length; UInt64 timeStamp;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x05;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    length = sizeof(type) + sizeof(timeStamp);
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    type = 1;
    [tempPacketData appendBytes:&type length:sizeof(UInt8)];
    
    NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970]*1000;
    timeStamp = (UInt64)timeInMiliseconds;
    [tempPacketData appendBytes:&timeStamp length:sizeof(UInt64)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"setPenState2WithTypeAndTimeStamp 0x5 data %@", data);
    [_commManager writePen2SetData:data];
    
}

- (void)setPenState2WithTypeAndAutoPwrOffTime:(UInt16)autoPwrOffTime
{
    UInt8  sof, cmd, eof, type; UInt16 length;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x05;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    length = sizeof(type) + sizeof(autoPwrOffTime);
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    type = 2;
    [tempPacketData appendBytes:&type length:sizeof(UInt8)];
    
    [tempPacketData appendBytes:&autoPwrOffTime length:sizeof(UInt16)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"setPenState2WithTypeAndAutoPwrOffTime 0x5 data %@", data);
    [_commManager writePen2SetData:data];
    
}

- (void)setPenState2WithTypeAndRGB:(UInt32)color tType:(UInt8)tType
{
    UInt8  sof, cmd, eof, type; UInt16 length;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x05;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    length = sizeof(type) + sizeof(tType) + sizeof(color);
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    type = 8;
    [tempPacketData appendBytes:&type length:sizeof(UInt8)];

    [tempPacketData appendBytes:&tType length:sizeof(UInt8)];
    
    [tempPacketData appendBytes:&color length:sizeof(UInt32)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"setPenState2WithTypeAndRGB 0x5 data %@", data);
    [_commManager writePen2SetData:data];
    
}

- (void)setPenState2WithTypeAndHover:(unsigned char)useHover
{
    UInt8  sof, cmd, eof, type; UInt16 length;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x05;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    length = sizeof(type) + sizeof(useHover);
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    type = 6;
    [tempPacketData appendBytes:&type length:sizeof(UInt8)];
    
    [tempPacketData appendBytes:&useHover length:sizeof(UInt8)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"setPenState2WithTypeAndHover 0x5 data %@", data);
    [_commManager writePen2SetData:data];
    
}

- (void)setAllNoteIdList2
{
    SetNoteIdList2Struct noteIdList2;
    
    UInt8  sof, cmd, eof; UInt16 length, count;
    UInt32 sectionOwnerId, note_Id;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x11;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    length = sizeof(noteIdList2) - sizeof(cmd) - sizeof(length);
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    count = 0xFFFF;
    [tempPacketData appendBytes:&count length:sizeof(UInt16)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"setAllNoteIdList2 0x11 data %@", data);
    [_commManager writePen2SetData:data];
    
}

- (void)setNoteIdListSectionOwnerFromPList2
{
    SetNoteIdList2Struct noteIdList2;
    
    UInt8  sof, cmd, eof; UInt16 length, count;
    UInt32 sectionOwnerId, note_Id;
    unsigned char dleData[1]; unsigned char packetData[1];
    unsigned char section_id;
    UInt32 owner_id;
    NPPaperManager *noteInfo = [NPPaperManager sharedInstance];
    NSArray *notesSupported = [noteInfo notesSupported];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x11;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    count = [notesSupported count];
    
    length = sizeof(noteIdList2) - sizeof(cmd) - sizeof(length) + count*2*sizeof(UInt32);
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    [tempPacketData appendBytes:&count length:sizeof(UInt16)];
    
    for (NSDictionary *note in notesSupported) {
        section_id = [(NSNumber *)[note objectForKey:@"section"] unsignedCharValue];
        owner_id = (UInt32)[(NSNumber *)[note objectForKey:@"owner"] unsignedIntegerValue];
        sectionOwnerId = (section_id << 24) | owner_id;
        [tempPacketData appendBytes:&sectionOwnerId length:sizeof(UInt32)];
        note_Id = 0xFFFFFFFF;
        [tempPacketData appendBytes:&note_Id length:sizeof(UInt32)];
        
    }

    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSUInteger btMtu;
    NSUInteger returnedMTU = _commManager.mtu;
    
    if (IS_OS_9_OR_LATER && (returnedMTU > 100))
        btMtu = BT_MTU;
    else
        btMtu = DEFAULT_BT_MTU;
    
    if (wholePacketData.length > btMtu) {
        NSData *data = [NSData dataWithData:wholePacketData];
        //NSLog(@"setNoteIdListSectionOwnerFromPList2 0x11 data %@", data);
        
        NSUInteger dataLocation =  0;
        NSUInteger dataLength = 0;
        
        while (dataLocation < data.length) {
            if ((dataLocation + btMtu) > data.length ){
                dataLength = data.length - dataLocation;
            }
            else {
                dataLength = btMtu;
            }
            
            NSData *splitData = [NSData dataWithBytesNoCopy:(char *)[data bytes] + dataLocation
                                                     length:dataLength
                                               freeWhenDone:NO];
            
            NSLog(@"setNoteIdListSectionOwnerFromPList2 0x11 data %@", splitData);
            [_commManager writePen2SetData:splitData];
            [NSThread sleepForTimeInterval:0.2];
            dataLocation += btMtu;
        }
        
    } else {
        NSData *data = [NSData dataWithData:wholePacketData];
        NSLog(@"setNoteIdListSectionOwnerFromPList2 0x11 data %@", data);
        [_commManager writePen2SetData:data];
    }
}
- (void)setNoteIdListFromPList2
{
    SetNoteIdList2Struct noteIdList2;
    
    UInt8  sof, cmd, eof; UInt16 length, count;
    UInt32 sectionOwnerId, note_Id;
    unsigned char dleData[1]; unsigned char packetData[1];
    unsigned char section_id;
    UInt32 owner_id; NSArray *noteIds;
    NPPaperManager *noteInfo = [NPPaperManager sharedInstance];
    NSArray *notesSupported = [noteInfo notesSupported];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x11;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    count = 0;
    for (NSDictionary *note in notesSupported) {
        noteIds = (NSArray *)[note objectForKey:@"noteIds"];
        UInt16 noteIdCount = (UInt16)[noteIds count];
        count += noteIdCount;
    }

    length = sizeof(noteIdList2) - sizeof(cmd) - sizeof(length) + count*2*sizeof(UInt32);
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    [tempPacketData appendBytes:&count length:sizeof(UInt16)];
    
    for (NSDictionary *note in notesSupported) {
        section_id = [(NSNumber *)[note objectForKey:@"section"] unsignedCharValue];
        owner_id = (UInt32)[(NSNumber *)[note objectForKey:@"owner"] unsignedIntegerValue];
        sectionOwnerId = (section_id << 24) | owner_id;
        noteIds = (NSArray *)[note objectForKey:@"noteIds"];
        UInt16 noteIdCount = (UInt16)[noteIds count];
        for (int i = 0; i < noteIdCount; i++) {
            [tempPacketData appendBytes:&sectionOwnerId length:sizeof(UInt32)];
            
            note_Id = (UInt32)[(NSNumber *)[noteIds objectAtIndex:i] unsignedIntegerValue];
            [tempPacketData appendBytes:&note_Id length:sizeof(UInt32)];
            
        }
    }
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSUInteger btMtu;
    NSUInteger returnedMTU = _commManager.mtu;
    
    if (IS_OS_9_OR_LATER && (returnedMTU > 100))
        btMtu = BT_MTU;
    else
        btMtu = DEFAULT_BT_MTU;
    
    if (wholePacketData.length > btMtu) {
        NSData *data = [NSData dataWithData:wholePacketData];
        //NSLog(@"setNoteList 0x11 data %@", data);
        
        NSUInteger dataLocation =  0;
        NSUInteger dataLength = 0;
        
        while (dataLocation < data.length) {
            if ((dataLocation + btMtu) > data.length ){
                dataLength = data.length - dataLocation;
            }
            else {
                dataLength = btMtu;
            }
            
            NSData *splitData = [NSData dataWithBytesNoCopy:(char *)[data bytes] + dataLocation
                                                     length:dataLength
                                               freeWhenDone:NO];
            
            NSLog(@"setNoteList 0x11 splitData %@", splitData);
            [_commManager writePen2SetData:splitData];
            [NSThread sleepForTimeInterval:0.2];
            dataLocation += btMtu;
        }
        
    }  else {
        NSData *data = [NSData dataWithData:wholePacketData];
        NSLog(@"setNoteIdListFromPList2 0x11 data %@", data);
        [_commManager writePen2SetData:data];
    }
    
}

- (BOOL) requestOfflineFileList2
{
    if (_offlineFileProcessing) {
        return NO;
    }
    
    UInt8  sof, eof;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    _offlineFileList = [[NSMutableDictionary alloc] init];
    _offlineFileParsedList = [[NSMutableDictionary alloc] init];
    SetRequestOfflineFileListStruct request;

    request.cmd = 0x21;
    request.length = sizeof(request) - sizeof(request.cmd) - sizeof(request.length);// - 2;
    request.sectionOwnerId = 0xFFFFFFFF;

    NSMutableData *tempPacketData = [NSMutableData dataWithBytes:&request length:sizeof(request)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"requestOfflineFileList2 0x21 data %@", data);
    
    [_commManager writePen2SetData:data];
    
    return YES;
}

- (BOOL) requestOfflinePageListSectionOwnerId:(UInt32) sectionOwnerId AndNoteId:(UInt32) noteId
{
    if (_offlineFileProcessing) {
        return NO;
    }
    UInt8  sof, eof;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];

    _offlineFileList = [[NSMutableDictionary alloc] init];
    _offlineFileParsedList = [[NSMutableDictionary alloc] init];
    SetRequestOfflinePageListStruct request;

    request.cmd = 0x22;
    request.length = sizeof(request) - sizeof(request.cmd) - sizeof(request.length);// - 2;
    request.sectionOwnerId = sectionOwnerId;
    request.noteId = noteId;

    NSMutableData *tempPacketData = [NSMutableData dataWithBytes:&request length:sizeof(request)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"requestOfflinePageListSectionOwnerId 0x22 data %@", data);
    
    [_commManager writePen2SetData:data];

    return YES;
}

- (BOOL) requestOfflineData2WithOwnerId:(UInt32)ownerId noteId:(UInt32)noteId pageId:(NSMutableArray *)pagesArray
{
    NSArray *noteList = [_offlineFileList objectForKey:[NSNumber numberWithUnsignedInt:ownerId]];
    if (noteList == nil) return NO;
    if ([noteList indexOfObject:[NSNumber numberWithUnsignedInt:noteId]] == NSNotFound) return NO;
    
    SetRequestOfflineDataStruct request;
    UInt8  sof, cmd, eof, transOption, dataZipOption; UInt16 length;
    UInt32 sectionOwnerId, note_Id, pageCnt, pageId;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSUInteger count = [pagesArray count];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x23;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    length = sizeof(request) - sizeof(cmd) - sizeof(length) + count*sizeof(pageCnt);
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    transOption = 1;
    [tempPacketData appendBytes:&transOption length:sizeof(UInt8)];
    
    dataZipOption = 1;
    [tempPacketData appendBytes:&dataZipOption length:sizeof(UInt8)];
    
    sectionOwnerId = ownerId;
    [tempPacketData appendBytes:&sectionOwnerId length:sizeof(UInt32)];
    
    note_Id = noteId;
    [tempPacketData appendBytes:&note_Id length:sizeof(UInt32)];
    
    if (count) {
        pageCnt = (UInt32)count;
    } else {
        pageCnt = 0;
    }
    [tempPacketData appendBytes:&pageCnt length:sizeof(UInt32)];
    
    for (int i = 0; i < count; i++) {
        pageId = (UInt32)[pagesArray objectAtIndex:i];
        [tempPacketData appendBytes:&pageId length:sizeof(UInt32)];
    }

    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"requestOfflineData2WithOwnerId 0x23 data %@", data);
    [_commManager writePen2SetData:data];
    return YES;
}

- (BOOL) response2AckToOfflineDataWithPacketID:(UInt16)packetId errCode:(UInt8)errCode AndTransOption: (UInt8)transOption
{
    UInt8  sof, eof;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    Response2OffLineData request;
    
    request.cmd = 0xA4;
    request.errorCode = errCode;
    request.length = 3;
    request.packetId = packetId;
    request.transOption = transOption;
    
    NSMutableData *tempPacketData = [NSMutableData dataWithBytes:&request length:sizeof(request)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"response2AckToOfflineDataWithPacketID 0xA4 data %@", data);
    
    [_commManager writePen2SetData:data];
    
    return YES;
}

- (BOOL) requestDelOfflineFile2SectionOwnerId:(UInt32)sectionOwnerId AndNoteIds:(NSMutableArray *)noteIdsArray
{
    SetRequestDelOfflineDataStruct request;

    UInt8  sof, cmd, eof, noteCnt; UInt16 length;
    UInt32 sectionOwner_Id, note_Id;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    noteCnt = (UInt8)[noteIdsArray count];
    
    NSMutableData *tempPacketData = [[NSMutableData alloc] init];
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    cmd = 0x25;
    [tempPacketData appendBytes:&cmd length:sizeof(UInt8)];
    
    length = sizeof(request) - sizeof(cmd) - sizeof(length) + noteCnt*sizeof(UInt32);
    [tempPacketData appendBytes:&length length:sizeof(UInt16)];
    
    sectionOwner_Id = sectionOwnerId;
    [tempPacketData appendBytes:&sectionOwner_Id length:sizeof(UInt32)];

    [tempPacketData appendBytes:&noteCnt length:sizeof(UInt8)];
    
    for (int i = 0; i < noteCnt; i++) {
        note_Id = (UInt32)[noteIdsArray objectAtIndex:i];
        [tempPacketData appendBytes:&note_Id length:sizeof(UInt32)];
    }
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"requestDelOfflineFile2SectionOwnerId 0x25 data %@", data);
    [_commManager writePen2SetData:data];
    return YES;
}

- (BOOL) sendUpdateFileInfo2AtUrl:(NSURL *)fileUrl
{
    SetRequestFWUpdateStruct request;
    UInt8  sof, eof;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *filteredPacketData = [[NSMutableData alloc] init];
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    
    self.cancelFWUpdate = NO;
    
    request.cmd = 0x31;
    request.length = sizeof(request) - sizeof(request.cmd) - sizeof(request.length);
    
    memset(request.deviceName, 0, sizeof(request.deviceName));
    NSString *inputStr = _commManager.deviceName;
    NSData *stringData = [inputStr dataUsingEncoding:NSUTF8StringEncoding];
    //or nameStrLen
    memcpy(request.deviceName, [stringData bytes], sizeof(request.deviceName));
    NSUInteger nameStrLen = [inputStr length];

    for(int i = 0 ; i < (16 - nameStrLen) ; i++)
    {
        request.deviceName[i + nameStrLen] = (unsigned char)NULL;
    }
    
    memset(request.fwVer, 0, sizeof(request.fwVer));
    NSString *inputStrVer = _commManager.fwVerServer;
    NSData *stringVerData = [inputStrVer dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(request.fwVer, [stringVerData bytes], sizeof(request.fwVer));
    NSUInteger verStrLen = [inputStrVer length];
    
    for(int i = 0 ; i < (16 - verStrLen) ; i++)
    {
        request.fwVer[i + verStrLen] = (unsigned char)NULL;
    }
    
    [self readUpdateDataFromUrl:fileUrl];
    request.fileSize = (UInt32)[self.updateFileData length];
    request.packetSize = UPDATE2_DATA_PACKET_SIZE;
    
    request.dataZipOpt = 1;

    request.nCheckSum = [self checkSum:self.updateFileData AndLength:request.fileSize];
    
    NSMutableData *tempPacketData = [NSMutableData dataWithBytes:&request length:sizeof(request)];
    
    unsigned char *tempDataBytes = (unsigned char *)[tempPacketData bytes];
    
    for ( int i =0 ; i < tempPacketData.length; i++){
        
        int int_data = (int) (tempDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [filteredPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = tempDataBytes[0] ^ 0x20;
            [filteredPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [filteredPacketData appendBytes:tempDataBytes length:sizeof(unsigned char)];
        }
        tempDataBytes = tempDataBytes + 1;
    }
    
    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[filteredPacketData bytes] length:filteredPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    NSData *data = [NSData dataWithData:wholePacketData];
    NSLog(@"sendUpdateFileInfo2AtUrl 0x31 data %@", data);
    
    [_commManager writePen2SetData:data];
    
    [self notifyFWUpdateStatus:FW_UPDATE_DATA_RECEIVE_START percent:0.0f];
    
    NSUInteger returnedMTU = _commManager.mtu;
    
    if (IS_OS_9_OR_LATER && (returnedMTU > 100))
        _fwBtMtu = BT_MTU;
    else
        _fwBtMtu = DEFAULT_BT_MTU;
    
    return YES;
}

- (unsigned char) checkSum:(NSData *)fileData AndLength:(unsigned int)length
{
    unsigned int dataPosition = 0;
    unsigned int Sum = 0;
    unsigned char data;
    NSRange range;
    
    range.length = 1;
    for (dataPosition = 0; dataPosition < length; dataPosition++){
        range.location = dataPosition;
        [fileData getBytes:&data range:range];
        Sum = Sum + data;
    }
    return (Sum & 0xFF);
}

- (BOOL) sendUpdateFileData2At:(UInt32)fileOffset AndStatus:(UInt8)status
{
    UInt8  sof, cmd, error, transContinue, nChecksum, eof;
    UInt16 length; UInt32 sizeBeforeZip, sizeAfterZip;
    unsigned char dleData[1]; unsigned char packetData[1];
    
    NSMutableData *wholePacketData = [[NSMutableData alloc] init];
    NSMutableData *hdrPacketData = [[NSMutableData alloc] init];
    NSMutableData *fwPacketData = [[NSMutableData alloc] init];
    
    NSRange range;
    
    range.location = fileOffset;
    
    if ((range.location + UPDATE2_DATA_PACKET_SIZE) > self.updateFileData.length ){
        range.length = self.updateFileData.length - range.location;
    }
    else {
        range.length = UPDATE2_DATA_PACKET_SIZE;
    }
    
    NSData* dividedData = [NSData dataWithBytesNoCopy:(char *)[self.updateFileData bytes] + range.location
                                              length:UPDATE2_DATA_PACKET_SIZE
                                        freeWhenDone:NO];
    
    NSMutableData* zippedData = [NSMutableData dataWithLength:(UPDATE2_DATA_PACKET_SIZE + 512)];
    
    uLongf zippedDataLen = zippedData.length;
    
    int result = compress OF(((Bytef*)zippedData.mutableBytes, &zippedDataLen,
                                (Bytef*)dividedData.bytes, UPDATE2_DATA_PACKET_SIZE));
    
    NSLog(@"compress result: %d",result);
    
    cmd = 0xB2;
    [hdrPacketData appendBytes:&cmd length:sizeof(UInt8)];
    if (status == 3){
        error = 3;
        [self notifyFWUpdateStatus:FW_UPDATE_DATA_RECEIVE_FAIL percent:0.0f];
    }else
        error = 0;
    
    [hdrPacketData appendBytes:&error length:sizeof(UInt8)];
    length = zippedDataLen + 14;
    [hdrPacketData appendBytes:&length length:sizeof(UInt16)];
    
    //0: continue, 1: stop
    if (!_cancelFWUpdate)
        transContinue = 0;
    else
        transContinue = 1;

    [hdrPacketData appendBytes:&transContinue length:sizeof(UInt8)];
    
    [hdrPacketData appendBytes:&fileOffset length:sizeof(UInt32)];
    
    nChecksum = [self checkSum:dividedData AndLength:UPDATE2_DATA_PACKET_SIZE];
    [hdrPacketData appendBytes:&nChecksum length:sizeof(UInt8)];
    
    sizeBeforeZip = UPDATE2_DATA_PACKET_SIZE;
    [hdrPacketData appendBytes:&sizeBeforeZip length:sizeof(UInt32)];
    
    sizeAfterZip = (UInt32)zippedDataLen;
    [hdrPacketData appendBytes:&sizeAfterZip length:sizeof(UInt32)];
    
    unsigned char *hdrDataBytes = (unsigned char *)[hdrPacketData bytes];
    
    for ( int i =0 ; i < hdrPacketData.length; i++){
        
        int int_data = (int) (hdrDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [fwPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = hdrDataBytes[0] ^ 0x20;
            [fwPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [fwPacketData appendBytes:hdrDataBytes length:sizeof(unsigned char)];
        }
        hdrDataBytes = hdrDataBytes + 1;
    }
    
    unsigned char *fwDataBytes = (unsigned char *)[zippedData bytes];
    
    for ( int i =0 ; i < zippedDataLen; i++){
       
        int int_data = (int) (fwDataBytes[0] & 0xFF);
        if ((int_data == PACKET_START) || (int_data == PACKET_END) || (int_data == PACKET_DLE)) {
            dleData[0] = PACKET_DLE;
            [fwPacketData appendBytes:dleData length:sizeof(unsigned char)];
            packetData[0] = fwDataBytes[0] ^ 0x20;
            [fwPacketData appendBytes:packetData length:sizeof(unsigned char)];
        } else {
            [fwPacketData appendBytes:fwDataBytes length:sizeof(unsigned char)];
        }
        fwDataBytes = fwDataBytes + 1;
    }

    sof = PACKET_START;
    [wholePacketData appendBytes:&sof length:sizeof(UInt8)];
    
    [wholePacketData appendBytes:[fwPacketData bytes] length:fwPacketData.length];
    
    eof = PACKET_END;
    [wholePacketData appendBytes:&eof length:sizeof(UInt8)];
    
    if ((range.length) > 0 && (result == Z_OK)) {
        NSData *data = [NSData dataWithData:wholePacketData];
        //NSLog(@"FW 0xB2 data %@", data);
        NSLog(@"FW 0xB2 data");
        
        NSUInteger dataLocation =  0;
        NSUInteger dataLength = 0;
        
        while (dataLocation < data.length) {
            if ((dataLocation + _fwBtMtu) > data.length ){
                dataLength = data.length - dataLocation;
            }
            else {
                dataLength = _fwBtMtu;
            }
            
            NSData *splitData = [NSData dataWithBytesNoCopy:(char *)[data bytes] + dataLocation
                                                     length:dataLength
                                               freeWhenDone:NO];
            
            //NSLog(@"FW 0xB2 splitData %@", splitData);
            [_commManager writePen2SetData:splitData];
            [NSThread sleepForTimeInterval:0.02];
            dataLocation += _fwBtMtu;
        }
        
    }
    
    float size = (float)[self.updateFileData length] / UPDATE2_DATA_PACKET_SIZE;
    float packetCount = ceilf(size);
    
    UInt16 index = (fileOffset + UPDATE2_DATA_PACKET_SIZE)/ UPDATE2_DATA_PACKET_SIZE;
    float progress_percent = (((float)index)/((float)packetCount))*100.0f;
    [self notifyFWUpdateStatus:FW_UPDATE_DATA_RECEIVE_PROGRESSING percent:progress_percent];

    return YES;
}

#pragma mark - Send data
- (void)setPenState
{
    NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970]*1000;
    NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
    NSInteger millisecondsFromGMT = 1000 * [localTimeZone secondsFromGMT] + [localTimeZone daylightSavingTimeOffset]*1000;
    SetPenStateStruct setPenStateData;
    setPenStateData.timeTick=(UInt64)timeInMiliseconds;
    setPenStateData.timezoneOffset=(int32_t)millisecondsFromGMT;
    NSLog(@"set timezoneOffset %d, timeTick %llu", setPenStateData.timezoneOffset, setPenStateData.timeTick);
    if (self.penStatus) {
        UInt32 color = self.penStatus->colorState;
        setPenStateData.colorState = (color & 0x00FFFFFF) | (0x01000000);
        setPenStateData.usePenTipOnOff = self.penStatus->usePenTipOnOff;
        setPenStateData.useAccelerator = self.penStatus->useAccelerator;
        setPenStateData.useHover = 2;
        setPenStateData.beepOnOff = self.penStatus->beepOnOff;
        setPenStateData.autoPwrOnTime = self.penStatus->autoPwrOffTime;
        setPenStateData.penPressure = self.penStatus->penPressure;
        
    } else {

        UIColor *color = nil;
        if (color != nil) {
            CGFloat r, g, b, a;
            [color getRed:&r green:&g blue:&b alpha:&a];
            UInt32 ir=(UInt32)(r*255);UInt32 ig=(UInt32)(g*255);
            UInt32 ib=(UInt32)(b*255);UInt32 ia=(UInt32)(a*255);
            setPenStateData.colorState=(ia<<24)|(ir<<16)|(ig<<8)|(ib);
        }
        else
            setPenStateData.colorState = 0;
        setPenStateData.usePenTipOnOff = 1;
        setPenStateData.useAccelerator = 1;
        setPenStateData.useHover = 2;
        setPenStateData.beepOnOff = 1;
        
    }
    NSData *data = [NSData dataWithBytes:&setPenStateData length:sizeof(setPenStateData)];
    [_commManager writeSetPenState:data];
}

- (void)setPenStateWithTimeTick
{
    NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970]*1000;
    NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
    NSInteger millisecondsFromGMT = 1000 * [localTimeZone secondsFromGMT] + [localTimeZone daylightSavingTimeOffset]*1000;
    SetPenStateStruct setPenStateData;
    setPenStateData.timeTick=(UInt64)timeInMiliseconds;
    setPenStateData.timezoneOffset=(int32_t)millisecondsFromGMT;
    NSLog(@"set timezoneOffset %d, timeTick %llu", setPenStateData.timezoneOffset, setPenStateData.timeTick);
    
    if (self.penStatus) {
        UInt32 color = self.penStatus->colorState;
        setPenStateData.colorState = (color & 0x00FFFFFF) | (0x01000000);
        setPenStateData.usePenTipOnOff = self.penStatus->usePenTipOnOff;
        setPenStateData.useAccelerator = self.penStatus->useAccelerator;
        setPenStateData.useHover = 2;
        setPenStateData.beepOnOff = self.penStatus->beepOnOff;
        setPenStateData.autoPwrOnTime = self.penStatus->autoPwrOffTime;
        setPenStateData.penPressure = self.penStatus->penPressure;
    
        NSData *data = [NSData dataWithBytes:&setPenStateData length:sizeof(setPenStateData)];
        [_commManager writeSetPenState:data];
    }else{
        NSLog(@"setPenStateWithTimeTick, self.penStatus : nil");
    }
}

- (void)setPenStateWithPenPressure:(UInt16)penPressure
{
    NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970]*1000;
    NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
    NSInteger millisecondsFromGMT = 1000 * [localTimeZone secondsFromGMT] + [localTimeZone daylightSavingTimeOffset]*1000;
    SetPenStateStruct setPenStateData;
    setPenStateData.timeTick=(UInt64)timeInMiliseconds;
    setPenStateData.timezoneOffset=(int32_t)millisecondsFromGMT;
    NSLog(@"set timezoneOffset %d, timeTick %llu", setPenStateData.timezoneOffset, setPenStateData.timeTick);
    
    if (self.penStatus) {
        UInt32 color = self.penStatus->colorState;
        setPenStateData.colorState = (color & 0x00FFFFFF) | (0x01000000);
        setPenStateData.usePenTipOnOff = self.penStatus->usePenTipOnOff;
        setPenStateData.useAccelerator = self.penStatus->useAccelerator;
        setPenStateData.useHover = 2;
        setPenStateData.beepOnOff = self.penStatus->beepOnOff;
        setPenStateData.autoPwrOnTime = self.penStatus->autoPwrOffTime;
    }
    setPenStateData.penPressure = penPressure;
    
    NSData *data = [NSData dataWithBytes:&setPenStateData length:sizeof(setPenStateData)];
    [_commManager writeSetPenState:data];
}

- (void)setPenStateWithAutoPwrOffTime:(UInt16)autoPwrOff
{
    NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970]*1000;
    NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
    NSInteger millisecondsFromGMT = 1000 * [localTimeZone secondsFromGMT] + [localTimeZone daylightSavingTimeOffset]*1000;
    SetPenStateStruct setPenStateData;
    setPenStateData.timeTick=(UInt64)timeInMiliseconds;
    setPenStateData.timezoneOffset=(int32_t)millisecondsFromGMT;
    NSLog(@"set timezoneOffset %d, timeTick %llu", setPenStateData.timezoneOffset, setPenStateData.timeTick);
    
    if (self.penStatus) {
        UInt32 color = self.penStatus->colorState;
        setPenStateData.colorState = (color & 0x00FFFFFF) | (0x01000000);
        setPenStateData.usePenTipOnOff = self.penStatus->usePenTipOnOff;
        setPenStateData.useAccelerator = self.penStatus->useAccelerator;
        setPenStateData.useHover = 2;
        setPenStateData.beepOnOff = self.penStatus->beepOnOff;
        setPenStateData.penPressure = self.penStatus->penPressure;
    }
    setPenStateData.autoPwrOnTime = autoPwrOff;
    
    NSData *data = [NSData dataWithBytes:&setPenStateData length:sizeof(setPenStateData)];
    [_commManager writeSetPenState:data];
}

- (void)setPenStateAutoPower:(unsigned char)autoPower Sound:(unsigned char)sound
{
    NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970]*1000;
    NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
    NSInteger millisecondsFromGMT = 1000 * [localTimeZone secondsFromGMT] + [localTimeZone daylightSavingTimeOffset]*1000;
    SetPenStateStruct setPenStateData;
    setPenStateData.timeTick=(UInt64)timeInMiliseconds;
    setPenStateData.timezoneOffset=(int32_t)millisecondsFromGMT;
    NSLog(@"set timezoneOffset %d, timeTick %llu", setPenStateData.timezoneOffset, setPenStateData.timeTick);
    
    if (self.penStatus) {
        UInt32 color = self.penStatus->colorState;
        setPenStateData.colorState = (color & 0x00FFFFFF) | (0x01000000);
        setPenStateData.usePenTipOnOff = autoPower;
        setPenStateData.useAccelerator = self.penStatus->useAccelerator;
        setPenStateData.useHover = 2;
        setPenStateData.beepOnOff = sound;
        setPenStateData.autoPwrOnTime = self.penStatus->autoPwrOffTime;
        setPenStateData.penPressure = self.penStatus->penPressure;
        
    }else{
        
        UIColor *color = nil;
        if (color != nil) {
            CGFloat r, g, b, a;
            [color getRed:&r green:&g blue:&b alpha:&a];
            UInt32 ir=(UInt32)(r*255);UInt32 ig=(UInt32)(g*255);
            UInt32 ib=(UInt32)(b*255);UInt32 ia=(UInt32)(a*255);
            setPenStateData.colorState=(ia<<24)|(ir<<16)|(ig<<8)|(ib);
        }
        else
            setPenStateData.colorState = 0;
        setPenStateData.usePenTipOnOff = autoPower;
        setPenStateData.useAccelerator = 1;
        setPenStateData.useHover = 2;
        setPenStateData.beepOnOff = sound;
        setPenStateData.autoPwrOnTime = 15;
        setPenStateData.penPressure = 20;
    }
    
    NSData *data = [NSData dataWithBytes:&setPenStateData length:sizeof(setPenStateData)];
    [_commManager writeSetPenState:data];

}

- (void)setPenStateWithRGB:(UInt32)color
{
    NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970]*1000;
    NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
    NSInteger millisecondsFromGMT = 1000 * [localTimeZone secondsFromGMT] + [localTimeZone daylightSavingTimeOffset]*1000;
    SetPenStateStruct setPenStateData;
    setPenStateData.timeTick=(UInt64)timeInMiliseconds;
    setPenStateData.timezoneOffset=(int32_t)millisecondsFromGMT;
    NSLog(@"set timezoneOffset %d, timeTick %llu", setPenStateData.timezoneOffset, setPenStateData.timeTick);
    
    if (self.penStatus) {
        NSLog(@"setPenStateWithRGB color 0x%x", (unsigned int)color);
        setPenStateData.colorState = (color & 0x00FFFFFF) | (0x01000000);
        setPenStateData.usePenTipOnOff = self.penStatus->usePenTipOnOff;
        setPenStateData.useAccelerator = self.penStatus->useAccelerator;
        setPenStateData.useHover = 2;
        setPenStateData.beepOnOff = self.penStatus->beepOnOff;
        setPenStateData.autoPwrOnTime = self.penStatus->autoPwrOffTime;
        setPenStateData.penPressure = self.penStatus->penPressure;
    }else{
        NSLog(@"setPenStateWithRGB color 0x%x", (unsigned int)color);
        setPenStateData.colorState = (color & 0x00FFFFFF) | (0x01000000);
        setPenStateData.usePenTipOnOff = 1;
        setPenStateData.useAccelerator = 1;
        setPenStateData.useHover = 2;
        setPenStateData.beepOnOff = 1;
        setPenStateData.autoPwrOnTime = 15;
        setPenStateData.penPressure = 20;
    }
    
    NSData *data = [NSData dataWithBytes:&setPenStateData length:sizeof(setPenStateData)];
    [_commManager writeSetPenState:data];

}

- (void)setPenStateWithHover:(UInt16)useHover
{
    NSTimeInterval timeInMiliseconds = [[NSDate date] timeIntervalSince1970]*1000;
    NSTimeZone *localTimeZone = [NSTimeZone localTimeZone];
    NSInteger millisecondsFromGMT = 1000 * [localTimeZone secondsFromGMT] + [localTimeZone daylightSavingTimeOffset]*1000;
    SetPenStateStruct setPenStateData;
    setPenStateData.timeTick=(UInt64)timeInMiliseconds;
    setPenStateData.timezoneOffset=(int32_t)millisecondsFromGMT;
    NSLog(@"set timezoneOffset %d, timeTick %llu", setPenStateData.timezoneOffset, setPenStateData.timeTick);
    
    if (self.penStatus) {
        UInt32 color = self.penStatus->colorState;
        setPenStateData.colorState = (color & 0x00FFFFFF) | (0x01000000);
        setPenStateData.usePenTipOnOff = self.penStatus->usePenTipOnOff;
        setPenStateData.useAccelerator = self.penStatus->useAccelerator;
        setPenStateData.beepOnOff = self.penStatus->beepOnOff;
        setPenStateData.autoPwrOnTime = self.penStatus->autoPwrOffTime;
        setPenStateData.penPressure = self.penStatus->penPressure;
    }
    
    setPenStateData.useHover = useHover;
    
    NSData *data = [NSData dataWithBytes:&setPenStateData length:sizeof(setPenStateData)];
    [_commManager writeSetPenState:data];
}

- (UIColor *)convertRGBToUIColor:(UInt32)penTipColor
{
    UInt8 red = (UInt8)(penTipColor >> 16) & 0xFF;
    UInt8 green = (UInt8)(penTipColor >> 8) & 0xFF;
    UInt8 blue = (UInt8)penTipColor & 0xFF;
    
    UIColor *color = [UIColor colorWithRed:red/255 green:green/255 blue:blue/255 alpha:1.0];
    
    return color;
}

- (void)setNoteIdList
{
    
    if (self.canvasStartDelegate) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSLog(@"setNoteIdList when canvasStartDelegate is not nil");
            [self.canvasStartDelegate setPenCommNoteIdList];
            
        });
    } else {
        NSLog(@"setNoteIdList doesn't work because canvasStartDelegate is nil");
    }
}

- (void)setAllNoteIdList
{
    SetNoteIdListStruct noteIdList;
    NSData *data;

    NSLog(@"setAllNoteIdList SDK1.0");
//NISDK -
    noteIdList.type = 3;
    int index = 0;

    noteIdList.count = index;
    data = [NSData dataWithBytes:&noteIdList length:sizeof(noteIdList)];
    [self.commManager writeNoteIdList:data];
}

- (void)setNoteIdListFromPList
{
    
    SetNoteIdListStruct noteIdList;
    NSData *data;
    unsigned char section_id;
    UInt32 owner_id;
    NSArray *noteIds;
    NPPaperManager *noteInfo = [NPPaperManager sharedInstance];
    NSArray *notesSupported = [noteInfo notesSupported];
    
    
    if (isEmpty(noteInfo.paperInfos)) return;
    NSArray *allKeyName = [noteInfo.paperInfos allKeys];
    
    NSLog(@"setNoteIdListFromPList SDK1.0");
    noteIdList.type = 1; // Note Id
    for (NSDictionary *note in notesSupported) {
        section_id = [(NSNumber *)[note objectForKey:@"section"] unsignedCharValue];
        owner_id = (UInt32)[(NSNumber *)[note objectForKey:@"owner"] unsignedIntegerValue];
        noteIds = (NSArray *)[note objectForKey:@"noteIds"];

        noteIdList.params[0] = (section_id << 24) | owner_id;
        int noteIdCount = (int)[noteIds count];
        int index = 0;
        for (int i = 0; i < noteIdCount; i++) {
            noteIdList.params[index+1] = (UInt32)[(NSNumber *)[noteIds objectAtIndex:i] unsignedIntegerValue];
            NSLog(@"note id at %d : %d", i, (unsigned int)noteIdList.params[index+1]);
            index++;
            if (index == (NOTE_ID_LIST_SIZE-1)) {
                noteIdList.count = index;
                data = [NSData dataWithBytes:&noteIdList length:sizeof(noteIdList)];
                [_commManager writeNoteIdList:data];
                index = 0;
            }
        }
        if (index != 0) {
            noteIdList.count = index;
            data = [NSData dataWithBytes:&noteIdList length:sizeof(noteIdList)];
            [_commManager writeNoteIdList:data];
        }
    }
    //Season note
    noteIdList.type = 1; // Note Id
    section_id = 0;
    owner_id = 19;
    noteIdList.params[0] = (section_id << 24) | owner_id;;
    noteIdList.params[1] = 1;
    noteIdList.count = 1;
    data = [NSData dataWithBytes:&noteIdList length:sizeof(noteIdList)];
    [_commManager writeNoteIdList:data];

    // To get Seal ID
    noteIdList.type = 2;
    UInt32 noteId;
    for (NSDictionary *note in notesSupported) {
        section_id = SEAL_SECTION_ID; // Fixed for seal
        noteIds = (NSArray *)[note objectForKey:@"noteIds"];
        int noteIdCount = (int)[noteIds count];
        int index = 0;
        for (int i = 0; i < noteIdCount; i++) {
            noteId = (UInt32)[(NSNumber *)[noteIds objectAtIndex:i] unsignedIntegerValue];
            noteIdList.params[index] = (section_id << 24) | noteId;
            index++;
            if (index == (NOTE_ID_LIST_SIZE)) {
                noteIdList.count = index;
                NSData *data = [NSData dataWithBytes:&noteIdList length:sizeof(noteIdList)];
                [_commManager writeNoteIdList:data];
                index = 0;
            }
        }
        if (index != 0) {
            noteIdList.count = index;
            data = [NSData dataWithBytes:&noteIdList length:sizeof(noteIdList)];
            [_commManager writeNoteIdList:data];
        }
    }
    
}

- (void)setNoteIdListSectionOwnerFromPList
{
    SetNoteIdListStruct noteIdList;
    NSData *data;
    unsigned char section_id;
    UInt32 owner_id;
    NPPaperManager *noteInfo = [NPPaperManager sharedInstance];
    NSArray *notesSupported = [noteInfo notesSupported];

    NSLog(@"setNoteIdListSectionOwnerFromPList SDK1.0");
    
    noteIdList.type = 2;
    int index = 0;
    
    for (NSDictionary *note in notesSupported) {
        section_id = [(NSNumber *)[note objectForKey:@"section"] unsignedCharValue];
        owner_id = (UInt32)[(NSNumber *)[note objectForKey:@"owner"] unsignedIntegerValue];
        noteIdList.params[index++] = (section_id << 24) | owner_id;
    }
    noteIdList.count = index;
    data = [NSData dataWithBytes:&noteIdList length:sizeof(noteIdList)];
    [_commManager writeNoteIdList:data];
}

- (void) setPassword:(NSString *)pinNumber
{
    PenPasswordChangeRequestStruct request;

    //NSString *currentPassword = [MyFunctions loadPasswd];
    NSString *currentPassword = @"0000";
    NSData *stringData = [currentPassword dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(request.prevPassword, [stringData bytes], sizeof(stringData));
    
    NSData *newData = [pinNumber dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(request.newPassword, [newData bytes], sizeof(newData));
    
    for(int i = 0 ; i < 12 ; i++)
    {
        request.prevPassword[i+4] = (unsigned char)NULL;
        request.newPassword[i+4] = (unsigned char)NULL;
    }
    
    NSData *data = [NSData dataWithBytes:&request length:sizeof(PenPasswordChangeRequestStruct)];
    [_commManager writeSetPasswordData:data];

}

- (void) changePasswordFrom:(NSString *)curNumber To:(NSString *)pinNumber
{
    PenPasswordChangeRequestStruct request;
    
    NSData *stringData = [curNumber dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(request.prevPassword, [stringData bytes], sizeof(stringData));
    
    NSData *newData = [pinNumber dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(request.newPassword, [newData bytes], sizeof(newData));
    
    for(int i = 0 ; i < 12 ; i++)
    {
        request.prevPassword[i+4] = (unsigned char)NULL;
        request.newPassword[i+4] = (unsigned char)NULL;
    }
    
    NSData *data = [NSData dataWithBytes:&request length:sizeof(PenPasswordChangeRequestStruct)];
    [_commManager writeSetPasswordData:data];
    
}

- (void) setBTComparePassword:(NSString *)pinNumber
{
    PenPasswordResponseStruct response;
    NSData *stringData = [pinNumber dataUsingEncoding:NSUTF8StringEncoding];
    memcpy(response.password, [stringData bytes], sizeof(stringData));    
    for(int i = 0 ; i < 12 ; i++)
    {
        response.password[i+4] = (unsigned char)NULL;
    }
    NSData *data = [NSData dataWithBytes:&response length:sizeof(PenPasswordResponseStruct)];
    [_commManager writePenPasswordResponseData:data];
}

- (void) writeReadyExchangeData:(BOOL)ready
{
    ReadyExchangeDataStruct request;
    request.ready = ready ? 1 : 0;
    NSData *data = [NSData dataWithBytes:&request length:sizeof(ReadyExchangeDataStruct)];
    [_commManager writeReadyExchangeData:data];
    if (ready == YES) {
        //flag should be YES when 2AB4 (response App ready)
        _isReadyExchangeSent = YES;
        NSLog(@"isReadyExchangeSent set into YES because it is sent to Pen");
    } else if (ready == NO){
        [self resetDataReady];
        NSLog(@"isReadyExchangeSent set into NO because of disconnected signal");
    }

}

- (void) resetDataReady
{
    //reset isReadyExchangeSent flag when disconnected
    _isReadyExchangeSent = NO;
    _penExchangeDataReady = NO;
    _penCommUpDownDataReady = NO;
    _penCommIdDataReady = NO;
    _penCommStrokeDataReady = NO;
    
    NSLog(@"resetDataReady is performed because of disconnected signal");
}

- (BOOL) requestOfflineFileList
{
    if (_commManager.isPenSDK2) {
        [self requestOfflineFileList2];
        return YES;
    }
    if (_offlineFileProcessing) {
        return NO;
    }
    _offlineFileList = [[NSMutableDictionary alloc] init];
    _offlineFileParsedList = [[NSMutableDictionary alloc] init];
    RequestOfflineFileListStruct request;
    request.status = 0x00;
    NSData *data = [NSData dataWithBytes:&request length:sizeof(request)];
    [_commManager writeRequestOfflineFileList:data];
    return YES;
}
- (BOOL) requestDelOfflineFile:(UInt32)sectionOwnerId
{
    RequestDelOfflineFileStruct request;
    request.sectionOwnerId = sectionOwnerId;
    NSData *data = [NSData dataWithBytes:&request length:sizeof(request)];
    [_commManager writeRequestDelOfflineFile:data ];
    return YES;
}
- (BOOL) requestOfflineDataWithOwnerId:(UInt32)ownerId noteId:(UInt32)noteId
{
    NSArray *noteList = [_offlineFileList objectForKey:[NSNumber numberWithUnsignedInt:ownerId]];
    if (noteList == nil) return NO;
    if ([noteList indexOfObject:[NSNumber numberWithUnsignedInt:noteId]] == NSNotFound) return NO;
    
    RequestOfflineFileStruct request;
    request.sectionOwnerId = ownerId;
    request.noteCount = 1;
    request.noteId[0] = noteId;
    NSData *data = [NSData dataWithBytes:&request length:sizeof(request)];
    [_commManager writeRequestOfflineFile:data];
    return YES;
}
- (void) offlineFileAckForType:(unsigned char)type index:(unsigned char)index
{
    OfflineFileAckStruct fileAck;
    fileAck.type = type;
    fileAck.index = index;
    NSData *data = [NSData dataWithBytes:&fileAck length:sizeof(fileAck)];
    [_commManager writeOfflineFileAck:data];
}
- (void) sendUpdateFileInfoAtUrl:(NSURL *)fileUrl
{
    [self readUpdateDataFromUrl:fileUrl];
    UpdateFileInfoStruct fileInfo;
    char *fileName = "\\Update.zip";
    memset(fileInfo.filePath, 0, sizeof(fileInfo.filePath));
    memcpy(fileInfo.filePath, fileName, strlen(fileName));
    fileInfo.fileSize = (UInt32)[self.updateFileData length];
    float size = (float)fileInfo.fileSize / UPDATE_DATA_PACKET_SIZE;
    fileInfo.packetCount = ceilf(size);
    fileInfo.packetSize = UPDATE_DATA_PACKET_SIZE;
    NSData *data = [NSData dataWithBytes:&fileInfo length:sizeof(fileInfo)];
    [_commManager writeUpdateFileInfo:data];
}
- (void) sendUpdateFileDataAt:(UInt16)index
{
    NSLog(@"sendUpdateFileDataAt %d", index);
    UpdateFileDataStruct updateData;
    updateData.index = index;
    NSRange range;
    range.location = index*UPDATE_DATA_PACKET_SIZE;
    if ((range.location + UPDATE_DATA_PACKET_SIZE) > self.updateFileData.length ){
        range.length = self.updateFileData.length - range.location;
    }
    else {
        range.length = UPDATE_DATA_PACKET_SIZE;
    }
    if (range.length > 0) {
        [self.updateFileData getBytes:updateData.fileData range:range];
        NSData *data = [NSData dataWithBytes:&updateData length:(sizeof(updateData.index) + range.length)];
        [_commManager writeUpdateFileData:data];
    }
    float progress_percent = (((float)index)/((float)self.packetCount))*100.0f;
    [self notifyFWUpdateStatus:FW_UPDATE_DATA_RECEIVE_PROGRESSING percent:progress_percent];

}
- (void) readUpdateDataFromUrl:(NSURL *)fileUrl
{
    self.updateFileData = [NSData dataWithContentsOfURL:fileUrl];
    self.updateFilePosition = 0;
}

- (void) sendUpdateFileInfoAtUrlToPen:(NSURL *)fileUrl
{
    self.cancelFWUpdate = NO;
    
    [self readUpdateDataFromUrl:fileUrl];
    UpdateFileInfoStruct fileInfo;
    //char *fileName = "\\Update.zip";
    NSString *fileNameString = [NSString stringWithFormat:@"\\%@",[[fileUrl path] lastPathComponent]];
    const char *fileName = [fileNameString UTF8String];
    
    memset(fileInfo.filePath, 0, sizeof(fileInfo.filePath));
    memcpy(fileInfo.filePath, fileName, strlen(fileName));
    fileInfo.fileSize = (UInt32)[self.updateFileData length];
    float size = (float)fileInfo.fileSize / UPDATE_DATA_PACKET_SIZE;
    fileInfo.packetCount = ceilf(size);
    fileInfo.packetSize = UPDATE_DATA_PACKET_SIZE;
    self.packetCount = fileInfo.packetCount;
    NSData *data = [NSData dataWithBytes:&fileInfo length:sizeof(fileInfo)];
    [_commManager writeUpdateFileInfo:data];
    [self notifyFWUpdateStatus:FW_UPDATE_DATA_RECEIVE_START percent:0.0f];    
    
}

#pragma mark - Page data
- (float) getDotScale
{
    if(_mDotToScreenScale == 0)
        return 1;
    
    return _mDotToScreenScale;
}

- (void) calcDotScaleScreenW:(float)screenW screenH:(float)screenH
{
    float dotWidth = 600;
    float dotHeight = 900;
    
    float widthScale = screenW / dotWidth;
    float heightScale = screenH / dotHeight;
    
    float dotToScreenScale = widthScale > heightScale ? heightScale : widthScale;
    _mDotToScreenScale = dotToScreenScale;
}

//////////////////////////////////////////////////////////////////
//
//
//             Pen Password
//
//////////////////////////////////////////////////////////////////

- (void) parsePenPasswordRequest:(unsigned char *)data withLength:(int) length
{
    PenPasswordRequestStruct *request = (PenPasswordRequestStruct *)data;

    if (_penCommIdDataReady && _penCommStrokeDataReady && _penCommUpDownDataReady && _penExchangeDataReady){
        dispatch_async(dispatch_get_main_queue(), ^{
        [self.penPasswordDelegate penPasswordRequest:request];
        });
    }
}

- (void) parsePenPasswordChangeResponse:(unsigned char *)data withLength:(int) length
{
    PenPasswordChangeResponseStruct *response = (PenPasswordChangeResponseStruct *)data;
    if (response->passwordState == 0x00) {
        NSLog(@"password change success");
        _commManager.hasPenPassword = YES;
    }else if(response->passwordState == 0x01){
        NSLog(@"password change fail");
    }
    BOOL PasswordChangeResult = (response->passwordState)? NO : YES;
    NSDictionary *info = @{@"result":[NSNumber numberWithBool:PasswordChangeResult]};
    dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:NJPenCommParserPenPasswordSutupSuccess object:nil userInfo:info];
    });
}

//////////////////////////////////////////////////////////////////
//
//
//            Online Dot Checker
//
//////////////////////////////////////////////////////////////////
//SDK2.0
- (void) dotCheckerForOfflineSync2:(OffLineData2DotStruct *)aDot pointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    if (offlineDotCheckState == OFFLINE_DOT_CHECK_NORMAL) {
        if ([self offline2DotCheckerForMiddle:aDot]) {
            [self offline2DotAppend:&offline2DotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
            offline2DotData0 = offline2DotData1;
            offline2DotData1 = offline2DotData2;
        }
        else {
            NSLog(@"offlineDotChecker error : middle");
        }
        offline2DotData2 = *aDot;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_FIRST) {
        offline2DotData0 = *aDot;
        offline2DotData1 = *aDot;
        offline2DotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_SECOND;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_SECOND) {
        offline2DotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_THIRD;
    }
    else if(offlineDotCheckState == OFFLINE_DOT_CHECK_THIRD) {
        if ([self offline2DotCheckerForStart:aDot]) {
            [self offline2DotAppend:&offline2DotData1 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
            if ([self offline2DotCheckerForMiddle:aDot]) {
                [self offline2DotAppend:&offline2DotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
                offline2DotData0 = offline2DotData1;
                offline2DotData1 = offline2DotData2;
            }
            else {
                NSLog(@"offlineDotChecker error : middle2");
            }
        }
        else {
            offline2DotData1 = offline2DotData2;
            NSLog(@"offlineDotChecker error : start");
        }
        offline2DotData2 = *aDot;
        offlineDotCheckState = OFFLINE_DOT_CHECK_NORMAL;
    }
}

- (void) offline2DotAppend:(OffLineData2DotStruct *)dot pointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    float pressure, x, y;
    
    x = (float)dot->x + (float)dot->fx * 0.01f;
    y = (float)dot->y + (float)dot->fy * 0.01f;
    pressure = [self processPressure:(float)dot->force];

    point_x_buff[point_index] = x;
    point_y_buff[point_index] = y;
    point_p_buff[point_index] = pressure;
    time_diff_buff[point_index] = dot->nTimeDelta;
    point_index++;
}

- (BOOL) offline2DotCheckerForStart:(OffLineData2DotStruct *)aDot
{
    static const float delta = 10.0f;
    if (offline2DotData1.x > 150 || offline2DotData1.x < 1) return NO;
    if (offline2DotData1.y > 150 || offline2DotData1.y < 1) return NO;
    if ((aDot->x - offline2DotData1.x) * (offline2DotData2.x - offline2DotData1.x) > 0
        && ABS(aDot->x - offline2DotData1.x) > delta && ABS(offline2DotData1.x - offline2DotData2.x) > delta)
    {
        return NO;
    }
    if ((aDot->y - offline2DotData1.y) * (offline2DotData2.y - offline2DotData1.y) > 0
        && ABS(aDot->y - offline2DotData1.y) > delta && ABS(offline2DotData1.y - offline2DotData2.y) > delta)
    {
        return NO;
    }
    return YES;
}
- (BOOL) offline2DotCheckerForMiddle:(OffLineData2DotStruct *)aDot
{
    static const float delta = 10.0f;
    if (offline2DotData2.x > 150 || offline2DotData2.x < 1) return NO;
    if (offline2DotData2.y > 150 || offline2DotData2.y < 1) return NO;
    if ((offline2DotData1.x - offline2DotData2.x) * (aDot->x - offline2DotData2.x) > 0
        && ABS(offline2DotData1.x - offline2DotData2.x) > delta && ABS(aDot->x - offline2DotData2.x) > delta)
    {
        return NO;
    }
    if ((offline2DotData1.y - offline2DotData2.y) * (aDot->y - offline2DotData2.y) > 0
        && ABS(offline2DotData1.y - offline2DotData2.y) > delta && ABS(aDot->y - offline2DotData2.y) > delta)
    {
        return NO;
    }
    
    return YES;
}
- (BOOL) offline2DotCheckerForEnd
{
    static const float delta = 10.0f;
    if (offline2DotData2.x > 150 || offline2DotData2.x < 1) return NO;
    if (offline2DotData2.y > 150 || offline2DotData2.y < 1) return NO;
    if ((offline2DotData2.x - offline2DotData0.x) * (offline2DotData2.x - offline2DotData1.x) > 0
        && ABS(offline2DotData2.x - offline2DotData0.x) > delta && ABS(offline2DotData2.x - offline2DotData1.x) > delta)
    {
        return NO;
    }
    if ((offline2DotData2.y - offline2DotData0.y) * (offline2DotData2.y - offline2DotData1.y) > 0
        && ABS(offline2DotData2.y - offline2DotData0.y) > delta && ABS(offline2DotData2.y - offline2DotData1.y) > delta)
    {
        return NO;
    }
    return YES;
}

- (void) offline2DotCheckerLastPointX:(float *)point_x_buff pointY:(float *)point_y_buff pointP:(float *)point_p_buff timeDiff:(int *)time_diff_buff
{
    if ([self offline2DotCheckerForEnd]) {
        [self offline2DotAppend:&offline2DotData2 pointX:point_x_buff pointY:point_y_buff pointP:point_p_buff timeDiff:time_diff_buff];
        offline2DotData2.x = 0.0f;
        offline2DotData2.y = 0.0f;
    }
    else {
        NSLog(@"offlineDotChecker error : end");
    }
    offlineDotCheckState = OFFLINE_DOT_CHECK_NONE;
}

//SDK1.0
- (float) dotcode2PixelX:(int) dot Y:(int)fdot
{
    float doScale = [self getDotScale];
    return (dot * doScale + (float)(fdot * doScale * 0.01f));
}

- (void) dotChecker:(dotDataStruct *)aDot
{
    if (dotCheckState == DOT_CHECK_NORMAL) {
        if ([self dotCheckerForMiddle:aDot]) {
            [self dotAppend:&dotData2];
            dotData0 = dotData1;
            dotData1 = dotData2;
        }
        else {
            NSLog(@"dotChecker error : middle");
        }
        dotData2 = *aDot;
    }
    else if(dotCheckState == DOT_CHECK_FIRST) {
        dotData0 = *aDot;
        dotData1 = *aDot;
        dotData2 = *aDot;
        dotCheckState = DOT_CHECK_SECOND;
    }
    else if(dotCheckState == DOT_CHECK_SECOND) {
        dotData2 = *aDot;
        dotCheckState = DOT_CHECK_THIRD;
    }
    else if(dotCheckState == DOT_CHECK_THIRD) {
        if ([self dotCheckerForStart:aDot]) {
            [self dotAppend:&dotData1];
            if ([self dotCheckerForMiddle:aDot]) {
                [self dotAppend:&dotData2];
                dotData0 = dotData1;
                dotData1 = dotData2;
            }
            else {
                NSLog(@"dotChecker error : middle2");
            }
        }
        else {
            dotData1 = dotData2;
            NSLog(@"dotChecker error : start");
        }
        dotData2 = *aDot;
        dotCheckState = DOT_CHECK_NORMAL;
    }
}
- (void) dotCheckerLast
{
    if ([self dotCheckerForEnd]) {
        [self dotAppend:&dotData2];
        dotData2.x = 0.0f;
        dotData2.y = 0.0f;
    }
    else {
        NSLog(@"dotChecker error : end");
    }
}
- (BOOL) dotCheckerForStart:(dotDataStruct *)aDot
{
    static const float delta = 10.0f;
    if (dotData1.x > 150 || dotData1.x < 1) return NO;
    if (dotData1.y > 150 || dotData1.y < 1) return NO;
    if ((aDot->x - dotData1.x) * (dotData2.x - dotData1.x) > 0 && ABS(aDot->x - dotData1.x) > delta && ABS(dotData1.x - dotData2.x) > delta)
    {
        return NO;
    }
    if ((aDot->y - dotData1.y) * (dotData2.y - dotData1.y) > 0 && ABS(aDot->y - dotData1.y) > delta && ABS(dotData1.y - dotData2.y) > delta)
    {
        return NO;
    }
    return YES;
}
- (BOOL) dotCheckerForMiddle:(dotDataStruct *)aDot
{
    static const float delta = 10.0f;
    if (dotData2.x > 150 || dotData2.x < 1) return NO;
    if (dotData2.y > 150 || dotData2.y < 1) return NO;
    if ((dotData1.x - dotData2.x) * (aDot->x - dotData2.x) > 0 && ABS(dotData1.x - dotData2.x) > delta && ABS(aDot->x - dotData2.x) > delta)
    {
        return NO;
    }
    if ((dotData1.y - dotData2.y) * (aDot->y - dotData2.y) > 0 && ABS(dotData1.y - dotData2.y) > delta && ABS(aDot->y - dotData2.y) > delta)
    {
        return NO;
    }

    return YES;
}
- (BOOL) dotCheckerForEnd
{
    static const float delta = 10.0f;
    if (dotData2.x > 150 || dotData2.x < 1) return NO;
    if (dotData2.y > 150 || dotData2.y < 1) return NO;
    if ((dotData2.x - dotData0.x) * (dotData2.x - dotData1.x) > 0 && ABS(dotData2.x - dotData0.x) > delta && ABS(dotData2.x - dotData1.x) > delta)
    {
        return NO;
    }
    if ((dotData2.y - dotData0.y) * (dotData2.y - dotData1.y) > 0 && ABS(dotData2.y - dotData0.y) > delta && ABS(dotData2.y - dotData1.y) > delta)
    {
        return NO;
    }
    return YES;
}
- (void) dotAppend:(dotDataStruct *)aDot
{
    float pressure = [self processPressure:aDot->pressure];
    point_x[point_count] = aDot->x;
    point_y[point_count] = aDot->y;
    point_p[point_count] = pressure;
    time_diff[point_count] = aDot->diff_time;
    point_count++;
    node_count++;
//    NSLog(@"time %d, x %f, y %f, pressure %f", aDot->diff_time, aDot->x, aDot->y, pressure);
    if(point_count >= MAX_NODE_NUMBER){
        // call _penDown setter
        self.penDown = NO;
        self.penDown = YES;
    }
    NJNode *node = [[NJNode alloc] initWithPointX:aDot->x poinY:aDot->y pressure:pressure];
    //requested
    node.timeDiff = aDot->diff_time;
    NSDictionary *new_node = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"stroke", @"type",
                              node, @"node",
                              nil];
    if (self.strokeHandler != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.strokeHandler processStroke:new_node];
        });
    }
}
@end
