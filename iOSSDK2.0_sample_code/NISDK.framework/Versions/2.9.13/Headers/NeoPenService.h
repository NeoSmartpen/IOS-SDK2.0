#import "NPNotebookInfo.h"
#import "NPPaperInfo.h"
#import "NPPUIInfo.h"
/* Pen2.0 Service UUID
 */
#define NEO_PEN2_SERVICE_UUID  @"19F1"
#define NEO_PEN2_SYSTEM_SERVICE_UUID  @"19F0"
#define PEN2_DATA_UUID            @"2BA1"
#define PEN2_SET_DATA_UUID        @"2BA0"

/* Pen Service UUID
 */
#define NEO_PEN_SERVICE_UUID    @"18F1"
#define STROKE_DATA_UUID        @"2AA0"
#define ID_DATA_UUID            @"2AA1"
#define UPDOWN_DATA_UUID        @"2AA2"
#define SET_RTC_UUID            @"2AB1"

/* OFFLINE Data Service UUID
 */
#define NEO_OFFLINE_SERVICE_UUID @"18F2"
#define REQUEST_OFFLINE_FILE_LIST_UUID @"2AC1"
#define OFFLINE_FILE_LIST_UUID @"2AC2"
#define REQUEST_DEL_OFFLINE_FILE_UUID @"2AC3"

/* OFFLINE2 Data Service UUID
 */
#define NEO_OFFLINE2_SERVICE_UUID @"18F3"
#define REQUEST_OFFLINE2_FILE_UUID        @"2AC7"
#define OFFLINE2_FILE_LIST_INFO_UUID @"2AC8"
#define OFFLINE2_FILE_INFO_UUID   @"2AC9"
#define OFFLINE2_FILE_DATA_UUID   @"2ACA"
#define OFFLINE2_FILE_ACK_UUID   @"2ACB"
#define OFFLINE2_FILE_STATUS_UUID      @"2ACC"

/* Update Service UUID
 */
#define NEO_UPDATE_SERVICE_UUID         @"18F4"
#define UPDATE_FILE_INFO_UUID           @"2AD1"
#define REQUEST_UPDATE_FILE_UUID   @"2AD2"
#define UPDATE_FILE_DATA_UUID           @"2AD3"
#define UPDATE_FILE_STATUS_UUID         @"2AD4"

/* System Service UUID
 */
#define NEO_SYSTEM_SERVICE_UUID @"18F5"
#define PEN_STATE_UUID          @"2AB0"
#define SET_PEN_STATE_UUID      @"2AB1"
#define SET_NOTE_ID_LIST_UUID   @"2AB2"
#define READY_EXCHANGE_DATA_UUID   @"2AB4"
#define READY_EXCHANGE_DATA_REQUEST_UUID   @"2AB5"

/* System2 Service UUID
 */
#define NEO_SYSTEM2_SERVICE_UUID @"18F6"
#define PEN_PASSWORD_REQUEST_UUID   @"2AB7"
#define PEN_PASSWORD_RESPONSE_UUID  @"2AB8"
#define PEN_PASSWORD_CHANGE_REQUEST_UUID    @"2AB9"
#define PEN_PASSWORD_CHANGE_RESPONSE_UUID   @"2ABA"

/* device information Service UUID
 */
#define NEO_DEVICE_INFO_SERVICE_UUID @"180A"
#define FW_VERSION_UUID          @"2A26"

#define HAS_LINE_COLOR

typedef struct __attribute__((packed)){
	unsigned char diff_time;
	unsigned short x;
	unsigned short y;
	unsigned char f_x;
	unsigned char f_y;
    UInt16 force;
} COMM2_WRITE_DATA;

typedef struct __attribute__((packed)){
    unsigned char diff_time;
    unsigned short x;
    unsigned short y;
    unsigned char f_x;
    unsigned char f_y;
    unsigned char force;
} COMM_WRITE_DATA;

typedef struct __attribute__((packed)){
	UInt32 owner_id;
	UInt32 note_id;
	UInt32 page_id;
} COMM_CHANGEDID2_DATA;
typedef struct __attribute__((packed)){
	UInt64 time;
	unsigned char upDown;
    UInt32 penColor;
} COMM_PENUP_DATA;

// Offline File Data
typedef struct  __attribute__((packed)){
    unsigned char status;
} RequestOfflineFileListStruct; //Ox2AC1
typedef struct  __attribute__((packed)){
    unsigned char status;
    UInt32 sectionOwnerId;
    unsigned char noteCount;
    UInt32 noteId[10];
} OfflineFileListStruct; //0x2AC2
typedef struct  __attribute__((packed)){
    UInt32 sectionOwnerId;
    UInt64 noteId;
} RequestDelOfflineFileStruct; //0x2AC3

// Offline2 File Data
typedef struct __attribute__((packed)){
	UInt32 sectionOwnerId;
    unsigned char noteCount;
    UInt32 noteId[10];
} RequestOfflineFileStruct; //0x2AC7
typedef struct __attribute__((packed)){
	UInt32 fileCount;
	UInt32 fileSize;
} OfflineFileListInfoStruct; //0x2AC8
typedef struct __attribute__((packed)){
	unsigned char type;
    UInt32 file_size;
	UInt16 packet_count;
    UInt16 packet_size;
	UInt16 slice_count;
    UInt16 slice_size;
} OFFLINE_FILE_INFO_DATA; //0x2AC9
typedef struct __attribute__((packed)){
	UInt16 index;
	unsigned char slice_index;
	unsigned char data;
} OFFLINE_FILE_DATA; //0x2ACA
typedef struct __attribute__((packed)){
    unsigned char type;
    unsigned char index;  //packet index
} OfflineFileAckStruct; //0x2ACB
typedef struct __attribute__((packed)){
    unsigned char status;
} OfflineFileStatusStruct; //0x2ACC

// Offline File Format
typedef struct __attribute__((packed)){ //64 bytes
	unsigned char abVersion[5];
	unsigned char isActive;
	UInt32 nOwnerId;
	UInt32 nNoteId;
	UInt32 nPageId;
	UInt32 nSubId;
	UInt32 nNumOfStrokes;
	UInt32 cbDataSize; //header 크기를 제외한 값
	unsigned char abReserved[33];
	unsigned char nCheckSum;
}  OffLineDataFileHeaderStruct ;

typedef struct __attribute__((packed)){
	UInt64 nStrokeStartTime;
	UInt64 nStrokeEndTime;
	UInt32 nDotCount;
	unsigned char cbDotStructSize;
#ifdef HAS_LINE_COLOR
	UInt32 nLineColor;
#endif
	unsigned char nCheckSum;
} OffLineDataStrokeHeaderStruct;

typedef struct __attribute__((packed)){
	unsigned char nTimeDelta;
	UInt16 x, y;
	unsigned char fx, fy;
	unsigned char force;
} OffLineDataDotStruct;

/* Update Service Data Structure
 */
typedef struct __attribute__((packed)){
	unsigned char filePath[52];
    UInt32 fileSize;
    UInt16 packetCount;
    UInt16 packetSize;
} UpdateFileInfoStruct; //0x2AD1
typedef struct __attribute__((packed)){
    UInt16 index;
} RequestUpdateFileStruct; //0x2AD2
#define UPDATE_DATA_PACKET_SIZE 112
typedef struct __attribute__((packed)){
    UInt16 index;
	unsigned char fileData[UPDATE_DATA_PACKET_SIZE];
} UpdateFileDataStruct; //0x2AD3
typedef struct __attribute__((packed)){
    UInt16 status;
} UpdateFileStatusStruct; //0x2AD4

/* System Service Data Structure
 */
typedef struct __attribute__((packed)){
    unsigned char version;
    unsigned char penStatus;
	int32_t timezoneOffset;
	UInt64 timeTick;
    unsigned char pressureMax;
    unsigned char battLevel;
    unsigned char memoryUsed;
    UInt32 colorState;
	unsigned char usePenTipOnOff;
    unsigned char useAccelerator;
    unsigned char useHover;
    unsigned char beepOnOff;
    UInt16 autoPwrOffTime;
    UInt16 penPressure;
    unsigned char reserved[11];
} PenStateStruct;
typedef struct __attribute__((packed)){
	int32_t timezoneOffset;
	UInt64 timeTick;
    UInt32 colorState;
	unsigned char usePenTipOnOff;
    unsigned char useAccelerator;
    unsigned char useHover;
    unsigned char beepOnOff;
    UInt16 autoPwrOnTime;
    UInt16 penPressure;
    unsigned char reserved[16];
} SetPenStateStruct;


#define NOTE_ID_LIST_SIZE 10

typedef struct __attribute__((packed)){
    unsigned char type;
	unsigned char count;
    UInt32 params[NOTE_ID_LIST_SIZE + 1];
} SetNoteIdListStruct; //ox2AB2

typedef struct __attribute__((packed)){
    unsigned char ready;
} ReadyExchangeDataStruct; //0x2AB4
typedef struct __attribute__((packed)){
    unsigned char ready;
} ReadyExchangeDataRequestStruct; //0x2AB5

typedef struct __attribute__((packed)){
    unsigned char retryCount;
    unsigned char resetCount;
} PenPasswordRequestStruct; //0x2AB7
typedef struct __attribute__((packed)){
    unsigned char password[16];
} PenPasswordResponseStruct; //0x2AB8

typedef struct __attribute__((packed)){
    unsigned char prevPassword[16];
    unsigned char newPassword[16];
} PenPasswordChangeRequestStruct; //0x2AB9
typedef struct __attribute__((packed)){
    unsigned char passwordState;
} PenPasswordChangeResponseStruct; //0x2ABA

//SDK2.0 structure
typedef struct __attribute__((packed)){//0x01
    UInt8  cmd;
    UInt16 length;
    unsigned char connectionCode[16];
    UInt16 appType;
    unsigned char appVer[16];
} SetVersionInfoStruct;

typedef struct __attribute__((packed)){
    UInt8  cmd;
    UInt16 length;
    unsigned char password[16];
} SetPenPasswordStruct;

typedef struct __attribute__((packed)){
    UInt8  cmd;
    UInt16 length;
    unsigned char usePwd;
    unsigned char oldPassword[16];
    unsigned char newPassword[16];
} SetChangePenPasswordStruct;

typedef struct __attribute__((packed)){//0x04
    UInt8  cmd;
    UInt16 length;
} SetRequestPenStateStruct;

typedef struct __attribute__((packed)){ //0x84
    UInt8 lock;
    UInt8 maxRetryCnt;
    UInt8 retryCnt;
    UInt64 timeTick;
    UInt16 autoPwrOffTime;
    UInt16 maxPressure;
    UInt8 memoryUsed;
    unsigned char usePenCapOnOff;
    unsigned char usePenTipOnOff; //auto power on
    unsigned char beepOnOff;
    unsigned char useHover;
    unsigned char battLevel;
    unsigned char offlineOnOff;
    unsigned char penPressure;
    unsigned char usbMode; //0: disk, 1:bulk
    unsigned char downSampling;
    unsigned char btLocalName[16];
    
} PenState2Struct;

typedef struct __attribute__((packed)){ //0x05
    UInt8  cmd;
    UInt16 length;
    UInt64 timeTick;
    UInt16 autoPwrOffTime;
    unsigned char usePenCapOnOff;
    unsigned char usePenTipOnOff; //auto power on
    unsigned char beepOnOff;
    unsigned char useHover;
    unsigned char offlineOnOff;
    unsigned char colorType;
    UInt32 colorState;
    unsigned char penPressure;
} SetPenState2Struct;

typedef struct __attribute__((packed)){ //0x11
    UInt8  cmd;
    UInt16 length;
    UInt16 count;
} SetNoteIdList2Struct;

typedef struct  __attribute__((packed)){ //0x21
    UInt8  cmd;
    UInt16 length;
    UInt32 sectionOwnerId;
} SetRequestOfflineFileListStruct;

typedef struct  __attribute__((packed)){ //0x22
    UInt8  cmd;
    UInt16 length;
    UInt32 sectionOwnerId;
    UInt32 noteId;
} SetRequestOfflinePageListStruct;

//SetRequest2FWUpdateStruct not used because of pageId size
typedef struct  __attribute__((packed)){ //0x23
    UInt8  cmd;
    UInt16 length;
    unsigned char transOption;
    unsigned char dataZipOption;
    UInt32 sectionOwnerId;
    UInt32 noteId;
    UInt32 pageCnt;
} SetRequestOfflineDataStruct;

// SDK2.0 Offline Data Format
typedef struct __attribute__((packed)){ //64 bytes
    UInt32 nSectionOwnerId;
    UInt32 nNoteId;
    UInt32 nNumOfStrokes;
}  OffLineData2HeaderStruct ;

typedef struct __attribute__((packed)){
    UInt32 nPageId;
    UInt64 nStrokeStartTime;
    UInt64 nStrokeEndTime;
    UInt8  penTipType;
#ifdef HAS_LINE_COLOR
    UInt32 nLineColor;
#endif
    UInt16 nDotCount;
} OffLineData2StrokeHeaderStruct;

typedef struct __attribute__((packed)){ //16 bytes
    unsigned char nTimeDelta;
    UInt16 force;
    UInt16 x, y;
    unsigned char fx, fy;
    unsigned char xtilt, ytilt;
    UInt16 twist;
    unsigned char reserved[2];
    unsigned char nCheckSum;
} OffLineData2DotStruct;

typedef struct __attribute__((packed)){ //0xA4
    UInt8  cmd;
    UInt8  errorCode;
    UInt16 length;
    UInt16 packetId;
    unsigned char transOption;
} Response2OffLineData;

typedef struct  __attribute__((packed)){ //0x25
    UInt8  cmd;
    UInt16 length;
    UInt32 sectionOwnerId;
    unsigned char noteCnt;
} SetRequestDelOfflineDataStruct;

typedef struct __attribute__((packed)){ //0x31
    UInt8  cmd;
    UInt16 length;
    unsigned char deviceName[16];
    unsigned char fwVer[16];
    UInt32 fileSize;
    UInt32 packetSize;
    unsigned char dataZipOpt;
    unsigned char nCheckSum;
} SetRequestFWUpdateStruct;

#define BT_MTU 153
#define DEFAULT_BT_MTU 61
#define UPDATE2_DATA_PACKET_SIZE 2048
//SetRequest2FWUpdateStruct not used because of file data size
typedef struct __attribute__((packed)){ //0xB2
    UInt8  sof;
    UInt8  cmd;
    UInt8  error;
    UInt16 length;
    UInt8  transContinue;
    UInt32 fileOffset;
    UInt8  nChecksum;
    UInt16 sizeBeforeZip;
    UInt16 sizeAfterZip;
    UInt8  eof;
} SetRequest2FWUpdateStruct;

typedef enum {
    
    PENSTATETYPE_PENCAPOFF = 3,
    PENSTATETYPE_AUTOPWRON = 4,
    PENSTATETYPE_BEEPONOFF = 5,
    PENSTATETYPE_HOVERONOFF= 6,
    PENSTATETYPE_OFFLINESAVE = 7,
    PENSTATETYPE_PENPRESSURE = 9,
    PENSTATETYPE_USBMODE = 10,
    PENSTATETYPE_DOWNSAMPLING = 11,
    PENSTATETYPE_BTLOCALNAME = 12,
    PENSTATETYPE_PENPRESSUREFSC = 13,
    
} REQUEST_PENSTATETYPE;
