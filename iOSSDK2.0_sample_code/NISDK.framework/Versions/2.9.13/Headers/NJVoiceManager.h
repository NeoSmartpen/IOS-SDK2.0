//
//  NJVoiceManager.h
//  NISDK
//
//  Created by Heogun You on 15/06/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef enum {
    VM_NUMBER_DUMMY = 0,
    VM_NUMBER_TIME,
    VM_NUMBER_NOTE_ID,
    VM_NUMBER_PAGE_ID
}VM_NUMBER_TYPE;

@protocol NJVoiceManagerDelegate <NSObject>
@optional
- (void)voicePlayerDidFinishPlaying;
- (void)voiceRecorderStopped;
@end

@class NJVoiceMemo;

@interface NJVoiceManager : NSObject  <AVAudioRecorderDelegate, AVAudioPlayerDelegate>
@property (weak, nonatomic)id<NJVoiceManagerDelegate> delegate;
@property (nonatomic,strong) AVAudioRecorder *recorder;
@property (nonatomic,strong) AVAudioPlayer *player;


+ (NJVoiceManager *) sharedInstance;
+ (BOOL) isVoiceMemoFileExist:(NSString *)fileName;
+ (UInt64) getNumberFor:(VM_NUMBER_TYPE)kind from:(NSString*)fileName;
+ (void) deleteVoiceMemoFile:(NSString *)fileName;

+ (BOOL) isVoiceMemoFileExistForNoteId:(NSUInteger)noteId andPageNum:(NSUInteger)pageNum;
+ (NSUInteger) getNumberOfVoiceMemoForNoteId:(NSUInteger)noteId;
+ (BOOL) deleteAllVoiceMemoForNoteId:(NSUInteger)noteId andPageNum:(NSUInteger)pageNum;

- (NSTimeInterval) playerCurrentTime;
- (void) setPlayerCurrentTime:(NSTimeInterval)newTime;
- (NSTimeInterval) playerDuration;
- (NSTimeInterval) playerTimeLeft;
- (NSTimeInterval) recoderCurrentTime;
- (BOOL) isRecording;
- (BOOL) isPlaying;
- (void) startRecording;
- (void) stopRecording;
- (void) startPlayFileName:(NSString *)fileName;
- (void) resumePlay;
- (void) pausePlay;
- (void) stopPlay;
- (void) addVoiceMemoPageChangingTo:(UInt32)noteId pageNumber:(UInt32)pageNumber;
- (void) addVoiceMemoPageChanged;
- (void) setPlayFileName:(NSString *)fileName;
- (NJVoiceMemo *)playerMetaFromTimestamp:(UInt64)timestamp;
@end
