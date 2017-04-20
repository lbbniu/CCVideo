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

@interface LbbCCVideo : UZModule

@property (copy, nonatomic)NSString *videoId;
@property (copy, nonatomic)NSString *localoVideoId;
@property (copy, nonatomic)NSString *videoLocalPath;
//@property (copy, nonatomic)NSString *downloadVideoId;
//@property (copy, nonatomic)NSString *progress;
//@property (assign, nonatomic)BOOL playMode;
@property (strong, nonatomic)NSArray *videos;
@property (assign, nonatomic)NSInteger indexpath;
@end