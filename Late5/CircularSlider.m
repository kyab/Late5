//
//  CircularSlider.m
//  TestCircularSlider
//
//  Created by kyab on 2020/09/16.
//  Copyright © 2020 kyab. All rights reserved.
//

#import "CircularSlider.h"

@implementation CircularSlider

-(void)awakeFromNib{
    _lineColor = [NSColor yellowColor];
}

-(void)setLineColor:(NSColor *) color{
    _lineColor = color;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    //assume width == height
    CGFloat r = self.bounds.size.height/2;
 
    //draw circle
    NSRect circleRect = NSMakeRect(0,0,r*2,r*2);
    NSBezierPath *circlePath = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    [[NSColor grayColor] set];
    [circlePath fill];
    
    //draw value line
    NSBezierPath *line = [NSBezierPath bezierPath];
    [line moveToPoint:NSMakePoint(r, r)];
    float rad = M_PI/2 - (M_PI*4/5)*_value;
    CGFloat x = r + r*cos(rad);
    CGFloat y = r + r*sin(rad);
    [line lineToPoint:NSMakePoint(x,y)];
    [_lineColor set];
    [line setLineWidth:1.5];
    [line stroke];
    
}

- (void)mouseDown:(NSEvent *)event{
//    NSLog(@"mousedown");

    CGFloat y = [self convertPoint:event.locationInWindow fromView:nil].y;
    CGFloat h = self.bounds.size.height;
    
    float y_norm = y/h;
    y_norm = y_norm*2 -1.0;
    
    _offset = y_norm - _value;
//    NSLog(@"offset = %f", _offset);
    
    
}

-(void)mouseDragged:(NSEvent *)event{
    CGFloat y = [self convertPoint:event.locationInWindow fromView:nil].y;
    CGFloat h = self.bounds.size.height;
    
    float y_norm = 0.0;
    y_norm = y/h;
    y_norm = y_norm*2 - 1.0;
    y_norm -= _offset;
    if (y_norm >= 1.0){
        y_norm = 1.0;
    }else if (y_norm <= -1.0){
        y_norm = -1.0;
    }
    _value = y_norm;
    
//    NSLog(@"y = %f, y_norm = %f", y,y_norm);
    if([self target]){
        [self sendAction:self.action to:self.target];
    }
    [self setNeedsDisplay:YES];
}



-(float) floatValue{
    return _value;
}

@end
