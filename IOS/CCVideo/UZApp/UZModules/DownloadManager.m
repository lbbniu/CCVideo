//
//  DownloadManager.m
//  CCVideo
//
//  Created by 刘兵兵 on 17/5/11.
//  Copyright © 2017年 APICloud. All rights reserved.
//

#import "DownloadManager.h"
#define DWDownloadingItemPlistFilename @"downloadingItems.plist"
#define DWDownloadFinishItemPlistFilename @"downloadFinishItems.plist"

@interface DownloadManager ()

@end

static DownloadManager *_instance;

@implementation DownloadManager

@synthesize isDownloaded;
@synthesize _downloadCbId;
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
        _instance.count = 0;
    });
    return _instance;
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        _instance.count = 0;
    });
    return _instance;
}

- (id)copyWithZone:(NSZone *)zone
{
    return _instance;
}

- (void)loadDownloadItems
{
    // 下载
    if (!self.downloadingItems) {
        self.downloadingItems = [[DWDownloadItems alloc] initWithPath:DWDownloadingItemPlistFilename];
    }
    if (!self.downloadFinishItems) {
        self.downloadFinishItems = [[DWDownloadItems alloc] initWithPath:DWDownloadFinishItemPlistFilename];
    }
}


@end
