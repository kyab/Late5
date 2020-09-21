//
//  AppController.h
//  Late5
//
//  Created by kyab on 2020/09/09.
//  Copyright © 2020 kyab. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "AudioEngine.h"
#import "RingBuffer.h"
#import "CircularSlider.h"
#import "TurnTableView.h"

#include <dispatch/dispatch.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppController : NSObject{
    AudioEngine *_ae;
    RingBuffer *_ring;
    RingBuffer *_ring5a;
    RingBuffer *_ring5b;
    RingBuffer *_tempRing;

    
    RingBuffer *_ringVocals;
    RingBuffer *_ringDrums;
    RingBuffer *_ringBass;
    RingBuffer *_ringPiano;
    RingBuffer *_ringOther;
    
    float _volVocals;
    float _volDrums;
    float _volBass;
    float _volPiano;
    float _volOther;
    
    float _panVocals;
    float _panDrums;
    float _panBass;
    float _panPiano;
    float _panOther;
    
    Boolean _scratchVocals;
    Boolean _scratchDrums;
    Boolean _scratchBass;
    Boolean _scratchPiano;
    Boolean _scratchOther;
    
    
    //GCD
    dispatch_queue_t _dq;
    
    __weak IBOutlet TurnTableView *_turnTable;
    double _speedRate;
    
    NSTimer *_tableStopTimer;
    __weak IBOutlet NSButton *_btnTTStartStop;
    
    
}


-(void)terminate;

@end

NS_ASSUME_NONNULL_END
