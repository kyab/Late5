//
//  TurnTableView.m
//  Fluent Scratch
//
//  Created by kyab on 2017/05/08.
//  Copyright © 2017年 kyab. All rights reserved.
//

#import "TurnTableView.h"

@implementation TurnTableView


- (void)awakeFromNib{
    _currentRad = 28 * (M_PI / 180);
    _speedRate = 1.0f;
    
    _timer2 = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(onTimerScratch:) userInfo:nil repeats:YES];

    [[NSRunLoop currentRunLoop] addTimer:_timer2 forMode:NSRunLoopCommonModes];
    
    _timer3 = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self
                                             selector:@selector(onTimerMIDIScratch:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_timer3 forMode:NSRunLoopCommonModes];
    
}

- (void)start{
    if (!_timer){
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    }
}

-(void)stop{
    [_timer invalidate];
    _timer = nil;
}

-(double) baseRadS{
    if (!_reverse){
        return -33.3/60 * M_PI*2;
    }else{
        return 33.3/60 * M_PI*2;
    }
}

double rad2deg(double rad){
    return rad / M_PI * 180;
}

-(void)onTimer:(NSTimer *)t{
    if (_pressing) return;
    
    if (!_MIDIScratching) {
        _currentRad += [self baseRadS]*0.01;
        if (_currentRad > 2*M_PI){
            _currentRad -= 2*M_PI;
        }else if (_currentRad < 0){
            _currentRad += 2*M_PI;
        }
    }
    [self setNeedsDisplay:YES];
}


- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    CGFloat r1 = self.bounds.size.height/2 /*- 10*/;
    CGFloat r2 = self.bounds.size.width/2 /*- 10*/;
    CGFloat r = 0;
    if (r1 > r2){
        r = r2;
    }else{
        r = r1;
    }
    
    //table circle
    NSRect circleRect = NSMakeRect(
                                   self.bounds.size.width/2 - r,
                                   self.bounds.size.height/2 - r,
                                   2*r,
                                   2*r);
    
    NSBezierPath *circlePath = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    

    [[NSColor grayColor] set];
    [circlePath fill];
    
    
    CGFloat centerX = self.bounds.size.width/2;
    CGFloat centerY = self.bounds.size.height/2;


    //record with lightGray
//    NSBezierPath *lineRecord = [NSBezierPath bezierPath];
//    [lineRecord moveToPoint:NSMakePoint(centerX,centerY)];
//    double thetaRecordRad = [_ring recordFrame]/44100.0 * (-33.3/60 * 2 * M_PI);
//    [lineRecord lineToPoint:NSMakePoint(centerX + r*cos(thetaRecordRad)/3, centerY + r*sin(thetaRecordRad)/3)];
//    [[NSColor lightGrayColor] set];
//    [lineRecord setLineWidth:1.0];
//    [lineRecord stroke];
    
    
    
    //current playFrame with orange
    NSBezierPath *linePlay = [NSBezierPath bezierPath];
    [linePlay moveToPoint:NSMakePoint(centerX,centerY)];
    double thetaPlayRad = [_ring playFrame]/44100.0 * (-33.3/60 * 2 * M_PI);
    [linePlay lineToPoint:NSMakePoint(centerX + r*cos(thetaPlayRad), centerY + r*sin(thetaPlayRad))];
    if (_pressing){
        [[NSColor orangeColor] set ];
    }else{
        [[NSColor orangeColor] set];
    }
    [linePlay setLineWidth:3.0];
    [linePlay stroke];
    
    

    
}

-(NSPoint)eventLocation:(NSEvent *) theEvent{
    return [self convertPoint:theEvent.locationInWindow fromView:nil];
}


-(void)mouseDown:(NSEvent *)theEvent{
    CGFloat x = [self eventLocation:theEvent].x;
    CGFloat y = [self eventLocation:theEvent].y;
    
    x = x - self.bounds.size.width/2;
    y = y - self.bounds.size.height/2;
    
    
    CGFloat dist = sqrt(x*x + y*y);
    CGFloat r = self.bounds.size.height/2/* - 10*/;
    
    if (dist <= r){
        _pressing = YES;
        _startOffsetRad = x/sqrt(x*x + y*y);
        _startOffsetRad = acos(_startOffsetRad);
        if (y < 0 ) _startOffsetRad = 2*M_PI - _startOffsetRad;
        _startOffsetRad = _startOffsetRad - _currentRad;
        
        [self setNeedsDisplay:YES];
        [[NSCursor openHandCursor] set];
        _prevRadValid = NO;
    
    }else{
        _pressing = NO;
    }
    
    
}

-(void)mouseDragged:(NSEvent *)theEvent{
//    if (_pressing == NO) return;
//    if (_pressing == YES) return;
//
//    CGFloat x1 = [self eventLocation:theEvent].x;
//    CGFloat y1 = [self eventLocation:theEvent].y;
//
//    x1 = x1 - self.bounds.size.width/2;
//    y1 = y1 - self.bounds.size.height/2;
//    double theta = x1/sqrt(x1*x1 + y1*y1);
//    theta = acos(theta);
//    if (y1 <0 ) theta = 2*M_PI - theta;
//    _currentRad  = theta - _startOffsetRad;
//    if (_currentRad > 2*M_PI){
//        _currentRad = _currentRad -  2*M_PI;
//    }
//    if (_currentRad < 0){
//        _currentRad = 2*M_PI + _currentRad;
//    }
//
//    double delta  = _currentRad - _prevRad;
//    if (fabs(rad2deg(delta)) > 340){
//        if (_currentRad > _prevRad){
//            delta = -1.0*_prevRad - (2*M_PI - _currentRad);
//        }else{
//            delta = (2*M_PI-_prevRad) + _currentRad;
//        }
//    }
//
//    double speed = delta / ([theEvent timestamp] - _prevSec);
//    _speedRate = speed / [self baseRadS];
//
//    [_delegate turnTableSpeedRateChanged];
//
//    _prevRad = _currentRad;
//    _prevSec = [theEvent timestamp];
//    _prevX = x1;
//    _prevY = y1;
//
//    [self setNeedsDisplay:YES];
//
}

-(void)mouseUp:(NSEvent *)theEvent{
    _pressing = NO;
    _speedRate = 1.0f;
    [_delegate turnTableSpeedRateChanged];
    
    [[NSCursor arrowCursor] set];
    [self setNeedsDisplay:YES];
}

-(void)onTimerScratch:(NSTimer *)t{
    if (!_pressing) return;

    //get mouse location
    NSPoint loc = [self.window mouseLocationOutsideOfEventStream];
    CGFloat x = [self convertPoint:loc fromView:nil].x;
    CGFloat y = [self convertPoint:loc fromView:nil].y;
    
    x = x - self.bounds.size.width/2;
    y = y - self.bounds.size.height/2;
    
    double theta = x/sqrt(x*x + y*y);
    theta = acos(theta);
    if (y < 0) theta = 2*M_PI-theta;
    _currentRad = theta - _startOffsetRad;
    if (_currentRad > 2*M_PI){
        _currentRad = _currentRad - 2 * M_PI;
    }
    if (_currentRad < 0 ){
        _currentRad = 2*M_PI + _currentRad;
    }
    
    if (_prevRadValid){
        double delta = _currentRad - _prevRad;
        if (fabs(rad2deg(delta)) > 340){
            if (_currentRad > _prevRad){
                delta = -1.0*_prevRad - (2*M_PI - _currentRad);
            }else{
                delta = (2*M_PI-_prevRad) + _currentRad;
            }
        }
        
        double speed = delta / 0.01;
        _speedRate = speed / [self baseRadS];

        [_delegate turnTableSpeedRateChanged];
    }
    
    _prevRad = _currentRad;
    _prevX = x;
    _prevY = y;
    _prevRadValid = YES;
    
    [self setNeedsDisplay:YES];
    
}

-(void)onTimerMIDIScratch:(NSTimer *)t{
    if (!_MIDIScratching)return;
    
    double deltaRad = _currentRad - _prevRad;
    double currentSec = [[NSDate date] timeIntervalSince1970];

    double speed = deltaRad / (currentSec - _prevSec);
    
    if (speed == 0){
        if (!_MIDITouching){
            _MIDIScratching = NO;
            _speedRate = 1.0f;
            [_delegate turnTableSpeedRateChanged];
            return;
        }else{
//            NSLog(@"speed : 0");
        }
    }
    
    _speedRate = speed / [self baseRadS];
    [_delegate turnTableSpeedRateChanged];
    
    _prevRad = _currentRad;
    _prevSec = currentSec;
    
}

-(void)onMIDITouchStart{
    _MIDITouching = YES;
    _MIDIScratching = YES;
    _prevRad = _currentRad;
    _prevSec = [[NSDate date] timeIntervalSince1970];
//    NSLog(@"scratch start");
}

-(void)onMIDITouchStop{
    _MIDITouching = NO;
    
}

-(void)onMIDIScratch:(int)number value:(int)value chan:(int)chan{
    int delta = value - 64;
    double deltaRad = 2 * M_PI /720.0 * delta;
    
    _currentRad -= deltaRad;

}

-(double)speedRate{
    return _speedRate;
}

-(void)setDelegate:(id<TurnTableDelegate>)delegate{
    _delegate = delegate;
}

-(void)setRingBuffer:(RingBuffer *)ring{
    _ring = ring;
}


-(void)setReverse:(BOOL)reverse{
    _reverse = reverse;
}

@end
