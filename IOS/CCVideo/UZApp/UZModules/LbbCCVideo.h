//
//  LbbCCVideo.h
//  CCVideo
//
//  Created by 刘兵兵 on 17/4/20.
//  Copyright © 2017年 APICloud. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "DWSDK.h"
#import "UZModule.h"
#import "ZXVideoPlayerTimeIndicatorView.h"
#import "ZXVideoPlayerVolumeView.h"
#import "ZXVideoPlayerBrightnessView.h"

@interface LbbCCVideo : UZModule

@property (copy, nonatomic)NSString *videoId;
@property (copy, nonatomic)NSString *localoVideoId;
@property (copy, nonatomic)NSString *videoLocalPath;

// 快进、快退指示器
@property (nonatomic, strong) ZXVideoPlayerTimeIndicatorView *timeIndicatorView;

// 音量指示器
@property (nonatomic, strong, readwrite) ZXVideoPlayerVolumeView *volumeIndicatorView;

// 亮度
@property (nonatomic, strong) ZXVideoPlayerBrightnessView *brightnessIndicatorView;
@end