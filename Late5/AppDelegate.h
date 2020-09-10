//
//  AppDelegate.h
//  Late5
//
//  Created by kyab on 2020/09/09.
//  Copyright © 2020 kyab. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AppController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>{

    __weak IBOutlet AppController *_controller;
}


@end

