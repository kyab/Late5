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
#define LATE_SEC 3

@implementation AppController

-(void)awakeFromNib{
    NSLog(@"Late5 awakeFromNib");
    
    [self initSpleeter];
//    https://stackoverflow.com/questions/17690740/create-a-high-priority-serial-dispatch-queue-with-gcd/17690878
    _dq = dispatch_queue_create("spleeter", DISPATCH_QUEUE_SERIAL);
    
    _ring = [[RingBuffer alloc] init];
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
//        NSLog(@"shortage");
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
    
    std::vector<float> leftSrc(inNumberFrames);
    std::vector<float> rightSrc(inNumberFrames);
    
    for(int si = 0; si < 5; si++){
        float *startLeft = [rings[si] readPtrLeft];
        float *startRight = [rings[si] readPtrRight];
        for(int i = 0 ; i < inNumberFrames; i++){
            
            //pan gain control
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
        memcpy(ioData->mBuffers[0].mData, leftSrc.data(), inNumberFrames * sizeof(float));
        memcpy(ioData->mBuffers[1].mData, rightSrc.data(), inNumberFrames * sizeof(float));
        [rings[si] advanceReadPtrSample:inNumberFrames];
        
    }
    
    
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

    if ([_ae isRecording]){
        
        float *startPtrLeft = [_tempRing startPtrLeft];
        float *currentPtrLeft = [_tempRing writePtrLeft];
        if (currentPtrLeft - startPtrLeft >= 44100*LATE_SEC){
            
            RingBuffer *bgRing = self->_tempRing;
            
            //switch tempRing
            if (self->_tempRing == self->_ring5a){
                self->_tempRing = self->_ring5b;
            }else{
                self->_tempRing = self->_ring5a;
            }
            
            dispatch_async(_dq, ^{
                NSLog(@"block start");
                //ready interleaved samples for spleeter
                std::vector<float> fragment(44100*2/*head*/ + 44100*2*LATE_SEC);
                for(int i = 0; i < 44100*LATE_SEC; i++){
                    fragment[44100*2 + i*2] = *([bgRing startPtrLeft]+i);
                    fragment[44100*2 +i*2+1] = *([bgRing startPtrRight]+i);
                }

                spleeter::Waveform vocals, drums, bass, piano, other;
                auto source = Eigen::Map<spleeter::Waveform>(fragment.data(),
                                                            2, fragment.size()/2);
                std::error_code err;
                spleeter::Split(source, &vocals, &drums, &bass, &piano, &other,err);
                NSLog(@"Split error = %d", err.value());
                
                std::vector<float> left(44100*LATE_SEC);
                std::vector<float> right(44100*LATE_SEC);
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
                    for (int i = 0; i < 44100*LATE_SEC; i++){
                        left[i] = *(waveForms[si]->data() + 44100*2 + i*2);
                        right[i] = *(waveForms[si]->data() + 44100*2 + i*2+1);
                    }
                    
                    //then write to rings
                    memcpy([rings[si] writePtrLeft], left.data(), 44100*LATE_SEC*sizeof(float));
                    memcpy([rings[si] writePtrRight], right.data(), 44100*LATE_SEC*sizeof(float));
                    [rings[si] advanceWritePtrSample:44100*LATE_SEC];
                    
                }
                
                [bgRing resetBuffer];
                NSLog(@"block done");
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
