//
//  CircularSlider.h
//  TestCircularSlider
//
//  Created by kyab on 2020/09/16.
//  Copyright © 2020 kyab. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CircularSlider : NSControl{
    float _value;   //-1.0 to 1.0
    CGFloat _offset;
    NSColor *_lineColor;
}

-(float)floatValue;
-(void)setLineColor:(NSColor *) color;

@end

NS_ASSUME_NONNULL_END
