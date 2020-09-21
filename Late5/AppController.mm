//
//  AppController.m
//  Late5
//
//  Created by kyab on 2020/09/09.
//  Copyright © 2020 kyab. All rights reserved.
//

#import "AppController.h"
#import "AudioToolbox/AudioToolbox.h"
#include "spleeter/spleeter.h"
#include <vector>

//#define SPLEETER_MODELS "/Users/koji/work/PartScratch/spleeterpp/build/models/offline"
#define LATE_SAMPLE 132288  // ~= 44100*3, can be devide by 32.

/////////////////////////////////////////////
static double linearInterporation(int x0, double y0, int x1, double y1, double x){
    if (x0 == x1){
        return y0;
    }
    double rate = (x - x0) / (x1 - x0);
    double y = (1.0 - rate)*y0 + rate*y1;
    return y;
}
///////////////////////////////////////////////





@implementation AppController

-(void)awakeFromNib{
    NSLog(@"Late5 awakeFromNib");
    
    [self initSpleeter];
    
    _dq = dispatch_queue_create("spleeter", DISPATCH_QUEUE_SERIAL);
    //    https://stackoverflow.com/questions/17690740/create-a-high-priority-serial-dispatch-queue-with-gcd/17690878
    dispatch_set_target_queue(_dq, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    
    _ring = [[RingBuffer alloc] init];      //the ring for the view
    _ring5a = [[RingBuffer alloc] init];
    _ring5b = [[RingBuffer alloc] init];
    
    _ringVocals = [[RingBuffer alloc] init];
    _ringDrums = [[RingBuffer alloc] init];
    _ringBass = [[RingBuffer alloc] init];
    _ringPiano = [[RingBuffer alloc] init];
    _ringOther = [[RingBuffer alloc] init];
    
    _volVocals = 1.0;
    _volDrums = 1.0;
    _volBass = 1.0;
    _volPiano = 1.0;
    _volOther = 1.0;
    
    _panVocals = 0.0;
    _panDrums = 0.0;
    _panBass = 0.0;
    _panPiano = 0.0;
    _panOther = 0.0;
    
    _scratchVocals = YES;
    _scratchDrums = YES;
    _scratchBass = YES;
    _scratchPiano = YES;
    _scratchOther = YES;
    
    _tempRing = _ring5a;
    
    _ae = [[AudioEngine alloc] init];
    if([_ae initialize]){
        NSLog(@"AudioEngine all OK");
    }else{
        NSLog(@"AudioEngine NG");
    }
    [_ae setRenderDelegate:(id<AudioEngineDelegate>)self];
    
    [_ae changeSystemOutputDeviceToBGM];
    [_ae startInput];
    [_ae startOutput];
    
    _speedRate = 1.0;
    [_turnTable setDelegate:(id<TurnTableDelegate>)self];
    [_turnTable setRingBuffer:_ring];
    [_turnTable start];
    
}

-(void)initSpleeter{
    std::error_code err;
    NSLog(@"Initializing spleeter");
    
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    
    spleeter::Initialize(
                         std::string(resourcePath.UTF8String),{spleeter::FiveStems}, err);
    NSLog(@"spleeter Initialize err = %d", err.value());
    
    //split empty for warm up.
    {
        NSLog(@"First Split");
        std::vector<float> fragment(44100*2);
        spleeter::Waveform vocals, drums, bass, piano, other;
        auto source = Eigen::Map<spleeter::Waveform>(fragment.data(),
                                                    2, fragment.size()/2);
        spleeter::Split(source, &vocals, &drums, &bass, &piano, &other,err);
        NSLog(@"First split error = %d", err.value());
    }
    
}

-(void)turnTableSpeedRateChanged{
    _speedRate = [_turnTable speedRate];
    if(_speedRate == 1.0){
        [_ringVocals followToNatural];
        [_ringDrums followToNatural];
        [_ringBass followToNatural];
        [_ringPiano followToNatural];
        [_ringOther followToNatural];
    }
}




- (IBAction)volVocalsChanged:(id)sender {
    NSSlider *slider = (NSSlider *)sender;
    _volVocals = [slider doubleValue];
}
- (IBAction)volDrumsChanged:(id)sender {
    NSSlider *slider = (NSSlider *)sender;
    _volDrums = [slider doubleValue];
}
- (IBAction)volBassChanged:(id)sender {
    NSSlider *slider = (NSSlider *)sender;
    _volBass = [slider doubleValue];
}
- (IBAction)volPianoChanged:(id)sender {
    NSSlider *slider = (NSSlider *)sender;
    _volPiano = [slider doubleValue];
}
- (IBAction)volOtherChanged:(id)sender {
    NSSlider *slider = (NSSlider *)sender;
    _volOther = [slider doubleValue];
}


- (IBAction)panVocalsChanged:(id)sender {
    CircularSlider *slider = (CircularSlider *)sender;
    _panVocals = [slider floatValue];
}
- (IBAction)panDrumsChanged:(id)sender {
    CircularSlider *slider = (CircularSlider *)sender;
    _panDrums = [slider floatValue];
}
- (IBAction)panBassChanged:(id)sender {
    CircularSlider *slider = (CircularSlider *)sender;
    _panBass = [slider floatValue];
}
- (IBAction)panPianoChanged:(id)sender {
    CircularSlider *slider = (CircularSlider *)sender;
    _panPiano = [slider floatValue];
}
- (IBAction)panOtherChanged:(id)sender {
    CircularSlider *slider = (CircularSlider *)sender;
    _panOther = [slider floatValue];
}


- (IBAction)scratchVocalsChanged:(id)sender {
    NSButton *chk = (NSButton *)sender;
    _scratchVocals = ([chk state] == NSOnState);
}
- (IBAction)scratchDrumsChanged:(id)sender {
    NSButton *chk = (NSButton *)sender;
    _scratchDrums = ([chk state] == NSOnState);
}
- (IBAction)scratchBassChanged:(id)sender {
    NSButton *chk = (NSButton *)sender;
    _scratchBass = ([chk state] == NSOnState);
}
- (IBAction)scratchPianoChanged:(id)sender {
    NSButton *chk = (NSButton *)sender;
    _scratchPiano = ([chk state] == NSOnState);
}
- (IBAction)scratchOtherChanged:(id)sender {
    NSButton *chk = (NSButton *)sender;
    _scratchOther = ([chk state] == NSOnState);
}


- (IBAction)ttStartStopClicked:(id)sender {
    if (_btnTTStartStop.state == NSOnState){
        if (_tableStopTimer){
            [_tableStopTimer invalidate];
        }
        
        _speedRate = 1.0;
        [_ringVocals followToNatural];
        [_ringDrums followToNatural];
        [_ringBass followToNatural];
        [_ringPiano followToNatural];
        [_ringOther followToNatural];
    
    }else{
        _tableStopTimer = [NSTimer scheduledTimerWithTimeInterval:0.01
                           target:self
                           selector:@selector(tableStopTimer:)
                           userInfo:nil
                                                          repeats:YES];
    }
}

-(void)tableStopTimer:(NSTimer *)t{
    if (_speedRate < 0.01f){
        _speedRate = 0.0f;
        [_tableStopTimer invalidate];
    }else{
        _speedRate -= 0.02;
    }
}




- (OSStatus) outCallback:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    
    if (![_ae isPlaying]){
        UInt32 sampleNum = inNumberFrames;
        float *pLeft = (float *)ioData->mBuffers[0].mData;
        float *pRight = (float *)ioData->mBuffers[1].mData;
        bzero(pLeft, sizeof(float)*sampleNum);
        bzero(pRight, sizeof(float)*sampleNum);
        return noErr;
    } 
    
    if([_ringOther isShortage]){
        UInt32 sampleNum = inNumberFrames;
        float *pLeft = (float *)ioData->mBuffers[0].mData;
        float *pRight = (float *)ioData->mBuffers[1].mData;
        bzero(pLeft, sizeof(float)*sampleNum);
        bzero(pRight, sizeof(float)*sampleNum);
        return noErr;
    }

    RingBuffer *rings[5];
    rings[0] = _ringVocals;
    rings[1] = _ringDrums;
    rings[2] = _ringBass;
    rings[3] = _ringPiano;
    rings[4] = _ringOther;
    
    float volumes[5];
    volumes[0] = _volVocals;
    volumes[1] = _volDrums;
    volumes[2] = _volBass;
    volumes[3] = _volPiano;
    volumes[4] = _volOther;
    
    float pans[5];
    pans[0] = _panVocals;
    pans[1] = _panDrums;
    pans[2] = _panBass;
    pans[3] = _panPiano;
    pans[4] = _panOther;
    
    Boolean scratch[5];
    scratch[0] = _scratchVocals;
    scratch[1] = _scratchDrums;
    scratch[2] = _scratchBass;
    scratch[3] = _scratchPiano;
    scratch[4] = _scratchOther;
    std::vector<UInt32> scratches;
    std::vector<UInt32> noScratches;
    for(int i = 0; i < 5; i++){
        if (scratch[i]){
            scratches.push_back(i);
        }else{
            noScratches.push_back(i);
        }
    }
    
    [_ring advanceReadPtrSample:inNumberFrames*_speedRate];
    
    std::vector<float> leftSrc(inNumberFrames);
    std::vector<float> rightSrc(inNumberFrames);
    
    for(UInt32 si : scratches){
        std::vector<float> scratchedBufLeft(inNumberFrames);
        std::vector<float> scratchedBufRight(inNumberFrames);
        {

            float *pTempLeft = [rings[si] readPtrLeft];
            float *pTempRight = [rings[si] readPtrRight];
            for (int i = 0; i < inNumberFrames; i++){
                int x0 = floor(i*_speedRate);
                int x1 = ceil(i*_speedRate);
                float y0_l = pTempLeft[x0];
                float y0_r = pTempRight[x0];
                float y1_l = pTempLeft[x1];
                float y1_r = pTempRight[x1];
                scratchedBufLeft[i] = linearInterporation(x0, y0_l, x1, y1_l , i*_speedRate);
                scratchedBufRight[i] = linearInterporation(x0, y0_r, x1, y1_r , i*_speedRate);

                //pan control
                float panVolLeft = 1.0;
                float panVolRight = 1.0;
                if (pans[si] >= 0){     //say 0.8
                    panVolRight = 1.0;
                    panVolLeft = 1.0 - pans[si];
                }else{
                    panVolLeft = 1.0;
                    panVolRight = 1.0 + pans[si];
                }
                
                leftSrc[i]  += scratchedBufLeft[i]*volumes[si] * panVolLeft;
                rightSrc[i] += scratchedBufRight[i]*volumes[si] * panVolRight;
            }

        }
        [rings[si] advanceReadPtrSample:round(inNumberFrames*_speedRate)];
        [rings[si] advanceNaturalPtrSample:inNumberFrames];
    }
    
    for(UInt32 si : noScratches){
        float *startLeft = [rings[si] readPtrLeft];
        float *startRight = [rings[si] readPtrRight];
        for(int i = 0 ; i < inNumberFrames; i++){
            
            //pan control
            float panVolLeft = 1.0;
            float panVolRight = 1.0;
            if (pans[si] >= 0){     //say 0.8
                panVolRight = 1.0;
                panVolLeft = 1.0 - pans[si];
            }else{
                panVolLeft = 1.0;
                panVolRight = 1.0 + pans[si];
            }
            leftSrc[i] += *(startLeft + i) * volumes[si] * panVolLeft;
            rightSrc[i] += *(startRight + i) * volumes[si] * panVolRight;
            
        }
        [rings[si] advanceReadPtrSample:inNumberFrames];
        [rings[si] advanceNaturalPtrSample:inNumberFrames];

    }

    memcpy(ioData->mBuffers[0].mData, leftSrc.data(), inNumberFrames * sizeof(float));
    memcpy(ioData->mBuffers[1].mData, rightSrc.data(), inNumberFrames * sizeof(float));
    
    
    return noErr;
    
    
}

- (OSStatus) inCallback:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    
    AudioBufferList *bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) +  sizeof(AudioBuffer)); // for 2 buffers for left and right
    

    float *leftPtr = [_tempRing writePtrLeft];
    float *rightPtr = [_tempRing writePtrRight];

    
    bufferList->mNumberBuffers = 2;
    bufferList->mBuffers[0].mDataByteSize = 32*inNumberFrames;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mData = leftPtr;
    bufferList->mBuffers[1].mDataByteSize = 32*inNumberFrames;
    bufferList->mBuffers[1].mNumberChannels = 1;
    bufferList->mBuffers[1].mData = rightPtr;
    
    
    OSStatus ret = [_ae readFromInput:ioActionFlags inTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:bufferList];
    
    if ( 0!=ret ){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed AudioUnitRender err=%d(%@)", ret, [err description]);
        return ret;
    }
    
    free(bufferList);
    
    [_tempRing advanceWritePtrSample:inNumberFrames];
    [_ring advanceWritePtrSample:inNumberFrames];

    if ([_ae isRecording]){
        
        float *startPtrLeft = [_tempRing startPtrLeft];
        float *currentPtrLeft = [_tempRing writePtrLeft];
        if (currentPtrLeft - startPtrLeft >= LATE_SAMPLE){
            
            RingBuffer *bgRing = self->_tempRing;
            
            //switch tempRing
            if (self->_tempRing == self->_ring5a){
                self->_tempRing = self->_ring5b;
            }else{
                self->_tempRing = self->_ring5a;
            }
            
            dispatch_async(_dq, ^{

                //ready interleaved samples for spleeter
                std::vector<float> fragment(44100*2/*head*/ + LATE_SAMPLE*2);
                for(int i = 0; i < LATE_SAMPLE; i++){
                    fragment[44100*2 + i*2] = *([bgRing startPtrLeft]+i);
                    fragment[44100*2 +i*2+1] = *([bgRing startPtrRight]+i);
                }

                //spleet it!
                spleeter::Waveform vocals, drums, bass, piano, other;
                auto source = Eigen::Map<spleeter::Waveform>(fragment.data(),
                                                            2, fragment.size()/2);
                std::error_code err;
                spleeter::Split(source, &vocals, &drums, &bass, &piano, &other,err);
                NSLog(@"Split error = %d", err.value());
                
                std::vector<float> left(LATE_SAMPLE);
                std::vector<float> right(LATE_SAMPLE);
                spleeter::Waveform *waveForms[5];
                waveForms[0] = &vocals;
                waveForms[1] = &drums;
                waveForms[2] = &bass;
                waveForms[3] = &piano;
                waveForms[4] = &other;
                
                RingBuffer *rings[5];
                rings[0] = self->_ringVocals;
                rings[1] = self->_ringDrums;
                rings[2] = self->_ringBass;
                rings[3] = self->_ringPiano;
                rings[4] = self->_ringOther;
                
                for (int si = 0; si < 5 ; si++){
                    //back to non-interleaved,
                    for (int i = 0; i < LATE_SAMPLE; i++){
                        left[i] = *(waveForms[si]->data() + 44100*2 + i*2);
                        right[i] = *(waveForms[si]->data() + 44100*2 + i*2+1);
                    }
                    
                    //then write to rings
                    memcpy([rings[si] writePtrLeft], left.data(), LATE_SAMPLE*sizeof(float));
                    memcpy([rings[si] writePtrRight], right.data(), LATE_SAMPLE*sizeof(float));
                    [rings[si] advanceWritePtrSample:LATE_SAMPLE];
                    
                }
                
                [bgRing resetBuffer];
            });
        }
    }
    
    return ret;
}

-(void)terminate{
    [_ae stopOutput];
    [_ae stopInput];
    [_ae restoreSystemOutputDevice];
    
}

@end
