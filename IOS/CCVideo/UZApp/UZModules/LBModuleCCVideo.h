//
//  LBModuleCCVideo.h
//  UZApp
//
//  Created by 刘兵兵 on 15/11/5.
//  Copyright (c) 2015年 APICloud. All rights reserved.
//

#import "UZModule.h"
//#import "DWDownloader.h"
#import "DWDownloadItem.h"
#import "ZXVideoPlayerTimeIndicatorView.h"
#import "ZXVideoPlayerVolumeView.h"
#import "ZXVideoPlayerBrightnessView.h"
@interface LBModuleCCVideo : UZModule

@property (copy, nonatomic)NSString *videoId;
@property (copy, nonatomic)NSString *localoVideoId;
@property (copy, nonatomic)NSString *videoLocalPath;
@property (copy, nonatomic)NSString *downloadVideoId;
@property (copy, nonatomic)NSString *progress;
// 快进、快退指示器
@property (nonatomic, strong) ZXVideoPlayerTimeIndicatorView *timeIndicatorView;

// 音量指示器
@property (nonatomic, strong, readwrite) ZXVideoPlayerVolumeView *volumeIndicatorView;

// 亮度
@property (nonatomic, strong) ZXVideoPlayerBrightnessView *brightnessIndicatorView;

@end
