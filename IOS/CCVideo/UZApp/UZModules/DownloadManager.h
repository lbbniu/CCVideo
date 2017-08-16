//
//  DownloadManager.h
//  CCVideo
//
//  Created by 刘兵兵 on 17/5/11.
//  Copyright © 2017年 APICloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DWDownloadItem.h"

@interface DownloadManager : NSObject
{
    BOOL isDownloaded;
    NSInteger _downloadCbId;
}
@property (assign, nonatomic)BOOL isDownloaded;
@property (strong, nonatomic)DWDownloadItems *downloadFinishItems;
@property (strong, nonatomic)DWDownloadItems *downloadingItems;
@property (assign,nonatomic)NSInteger count;
@property (assign,nonatomic)NSInteger _downloadCbId;
/**
 *  单例
 *
 *  @return 返回单例对象
 */
+ (instancetype)sharedInstance;
- (void)loadDownloadItems;
@end
