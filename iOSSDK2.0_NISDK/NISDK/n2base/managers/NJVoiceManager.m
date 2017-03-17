//
//  NJVoiceManager.m
//  NISDK
//
//  Created by Heogun You on 15/06/2014.
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJVoiceManager.h"
#import "NJVoiceMemo.h"

extern NSString * NJPageChangedNotification;

@interface NJVoiceManager () {
}
@property (strong, nonatomic) NSString *fileName;
@property (strong, nonatomic) NJVoiceMemo *voiceMemoStater;
@property (strong, nonatomic) NSMutableData *vmRecoderMetaData;
@property (strong, nonatomic) NSMutableArray *vmPlayerMetaList;

- (NSString *)newVoiceFileName;
+ (NSString *) voiceMemoDirectory;
- (NSURL *) newVoiceFileUrl;
@end

@implementation NJVoiceManager
@synthesize recorder,player;
- (instancetype)init
{
    self = [super init];
    if (self == nil) return nil;
    

    return self;
}

+ (NJVoiceManager *) sharedInstance
{
    static NJVoiceManager *shared = nil;
    
    @synchronized(self) {
        if(!shared){
            shared = [[NJVoiceManager alloc] init];
        }
    }
    return shared;
}


+ (BOOL) isVoiceMemoFileExistForNoteId:(NSUInteger)noteId andPageNum:(NSUInteger)pageNum
{
    return NO;
}
+ (NSUInteger) getNumberOfVoiceMemoForNoteId:(NSUInteger)noteId
{
    NSUInteger count = 0;
    return count;
}
+ (BOOL) deleteAllVoiceMemoForNoteId:(NSUInteger)noteId andPageNum:(NSUInteger)pageNum
{
    return YES;
}



- (void)AEAudioControllerSessionInterruptionEnded:(NSNotification *)notification
{

}
- (void) vmMetaDataListInit
{
    _vmRecoderMetaData = [[NSMutableData alloc] init];
}
- (NSTimeInterval) playerCurrentTime
{
    return player.currentTime;
}
- (void) setPlayerCurrentTime:(NSTimeInterval)newTime
{
    [player setCurrentTime:newTime];
}
- (NSTimeInterval) playerDuration
{
    
    return player.duration;
}
- (NSTimeInterval) playerTimeLeft
{
    return (player.duration - player.currentTime);
}
- (NSTimeInterval) recoderCurrentTime
{
    return recorder.currentTime;
}

- (BOOL) isRecording
{
    if (recorder != nil && recorder.recording) {
        return YES;
    }
    return NO;
}

- (BOOL) isPlaying
{
    if (player != nil && player.playing) {
        return YES;
    }
    return NO;
}
- (void) saveVmRecoderMeta
{
    NSString *metaFileName = [self.fileName stringByDeletingPathExtension];
    metaFileName = [NSString stringWithFormat:@"%@.meta", metaFileName];
    NSString *path = [[NJVoiceManager voiceMemoDirectory] stringByAppendingPathComponent:metaFileName];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createFileAtPath:path contents:_vmRecoderMetaData attributes:nil];
    _vmRecoderMetaData = nil;
}
- (void) startRecording
{
}
- (void)stopRecording
{
}
- (void) startPlayFileName:(NSString *)fileName
{
}
- (void) setPlayFileName:(NSString *)fileName
{

}
- (NJVoiceMemo *)playerMetaFromTimestamp:(UInt64)timestamp
{
    if(_vmPlayerMetaList == nil) return nil;
    for (int i = (int)[_vmPlayerMetaList count]-1; i >= 0; i--) {
        NJVoiceMemo *vm = _vmPlayerMetaList[i];
        if (vm.startTime <= timestamp) {
            return vm;
        }
    }
    return nil;
}
-(void) setAudioRouting
{

}
+ (BOOL) isVoiceMemoFileExist:(NSString *)fileName
{
    return NO;
}
+ (void) deleteVoiceMemoFile:(NSString *)fileName
{
}

+ (UInt64) getNumberFor:(VM_NUMBER_TYPE)kind from:(NSString*)fileName
{
    return 0;
}
- (void) resumePlay
{
}
- (void) pausePlay
{
}
- (void) stopPlay
{
}

- (void) addVoiceMemoStartWithFileName:(NSString *)fileName
{

}

- (void) addVoiceMemoPageChangingTo:(UInt32)noteId pageNumber:(UInt32)pageNumber
{
}
- (void) addVoiceMemoPageChanged
{

}

- (void) addVoiceMemoEnd
{

}
#pragma mark - Private Methods
// Voice recording has some latency before actually start recording....
#define VOICE_RECORD_LATENCY 200   //ms
- (NSString *) newVoiceFileName
{
    return nil;
}

+ (NSString *) voiceMemoDirectory
{
    return nil;
}

- (NSURL *) newVoiceFileUrl
{
    return nil;
}
#pragma mark - AVAudioRecorderDelegate
/* audioRecorderDidFinishRecording:successfully: is called when a recording has been finished or stopped. 
 This method is NOT called if the recorder is stopped due to an interruption. */
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    NSLog(@"audioRecorderDidFinishRecording");
}
/* if an error occurs while encoding it will be reported to the delegate. */
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
    NSLog(@"audioRecorderEncodeErrorDidOccur");
}
/* audioRecorderBeginInterruption: is called when the audio session has been interrupted while the recorder was recording. 
 The recorded file will be closed. */
- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)a_recorder
{
    NSLog(@"audioRecorderBeginInterruption");
}
/* audioRecorderEndInterruption:withOptions: is called when the audio session interruption has ended and this recorder had been interrupted while recording. */
/* Currently the only flag is AVAudioSessionInterruptionFlags_ShouldResume. */
- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder withOptions:(NSUInteger)flags
{
    NSLog(@"audioRecorderEndInterruption");
}
#pragma mark - AVAudioPlayerDelegate
/* audioPlayerDidFinishPlaying:successfully: is called when a sound has finished playing. 
 This method is NOT called if the player is stopped due to an interruption. */
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    NSLog(@"audioPlayerDidFinishPlaying");
}

/* if an error occurs while decoding it will be reported to the delegate. */
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"audioPlayerDecodeErrorDidOccur");
}

/* audioPlayerBeginInterruption: is called when the audio session has been interrupted while the player was playing. The player will have been paused. */
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player
{
    
}

/* audioPlayerEndInterruption:withOptions: is called when the audio session interruption has ended and this player had been interrupted while playing. */
/* Currently the only flag is AVAudioSessionInterruptionFlags_ShouldResume. */
- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags
{
    
}
@end
