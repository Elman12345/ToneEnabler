//
//  ToneEnabler.xm
//
//  Created by eni9889 on 12-24-2013.
//  Copyright 2013 UnlimApps Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "stdio.h"
#include "dlfcn.h"

@interface TKTonePickerViewController : UITableViewController
@end

@interface SoundsPrefController : UIViewController
@property (nonatomic, strong) UITableView *table;
@end

%group IOS7

%hook TKToneTableController

- (id)loadRingtonesFromPlist
{
    NSDictionary *original = %orig;
    
    NSMutableDictionary *allRingtones = [NSMutableDictionary dictionary];
    NSMutableArray *classicRingtones = [NSMutableArray arrayWithArray:[original objectForKey:@"classic"]];
    NSMutableArray *modernRingtones = [NSMutableArray arrayWithArray:[original objectForKey:@"modern"]];
    
    NSString *tonesDirectory = @"/Library/Ringtones";
    NSFileManager *localFileManager = [[NSFileManager alloc] init];
    NSDirectoryEnumerator *dirEnum  = [localFileManager enumeratorAtPath:tonesDirectory];
    
    NSString *file;
    while ((file = [dirEnum nextObject]))
    {
        if ([[file pathExtension] isEqualToString: @"m4r"])
        {
            NSString *properToneIdentifier = [NSString stringWithFormat:@"system:%@",[file stringByDeletingPathExtension]];
            BOOL isClassicTone = [classicRingtones containsObject:properToneIdentifier];
            BOOL isModernTone  = [modernRingtones containsObject:properToneIdentifier];
            
            if(!isClassicTone && !isModernTone)
            {
                [modernRingtones addObject:properToneIdentifier];
            }
        }
    }
    
    [allRingtones setObject:classicRingtones forKey:@"classic"];
    [allRingtones setObject:modernRingtones  forKey:@"modern"];
    
    return allRingtones;
}
%end

%end

%group IOS8


%hook TKTonePickerController

- (id)_loadTonesFromPlistNamed:(id)arg1 {
    %log;
    if ([arg1 isEqualToString:@"TKRingtones"]) {
        NSDictionary *original = %orig;
        NSMutableDictionary *allRingtones = [NSMutableDictionary dictionary];
        NSMutableArray *classicRingtones = [NSMutableArray arrayWithArray:[original objectForKey:@"classic"]];
        NSMutableArray *modernRingtones = [NSMutableArray arrayWithArray:[original objectForKey:@"modern"]];
        
        NSString *tonesDirectory = @"/Library/Ringtones";
        NSFileManager *localFileManager = [[NSFileManager alloc] init];
        NSDirectoryEnumerator *dirEnum  = [localFileManager enumeratorAtPath:tonesDirectory];
        
        NSString *file;
        while ((file = [dirEnum nextObject]))
        {
            if ([[file pathExtension] isEqualToString: @"m4r"])
            {
                NSString *properToneIdentifier = [NSString stringWithFormat:@"system:%@",[file stringByDeletingPathExtension]];
                BOOL isClassicTone = [classicRingtones containsObject:properToneIdentifier];
                BOOL isModernTone  = [modernRingtones containsObject:properToneIdentifier];
                
                if(!isClassicTone && !isModernTone)
                {
                    [modernRingtones addObject:properToneIdentifier];
                }
            }
        }
        
        [allRingtones setObject:classicRingtones forKey:@"classic"];
        [allRingtones setObject:modernRingtones  forKey:@"modern"];
        
        return allRingtones;
        
    } else {
        return %orig;
    }
}

%end

%end


#define XPCObjects "/System/Library/PrivateFrameworks/ToneKit.framework/ToneKit"

%ctor {
    
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.mobilesafari"]) {
        if (!NSClassFromString(@"TKTonePickerController") && !NSClassFromString(@"TKToneTableController")) {
            //load the framework if it does not exist
            dlopen(XPCObjects, RTLD_LAZY);
        }
        
        if (NSClassFromString(@"TKTonePickerController")) {
            NSLog(@"ToneEnabler iOS 8");
            %init(IOS8);
        } else if (NSClassFromString(@"TKToneTableController")) {
            NSLog(@"ToneEnabler iOS 7");
            %init(IOS7);
        }
    }
}