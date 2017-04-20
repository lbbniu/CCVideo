//
//  LBModuleCCVideo.m
//  UZApp
//
//  Created by 刘兵兵 on 15/11/5.
//  Copyright (c) 2015年 APICloud. All rights reserved.
//

#import "LBModuleCCVideo.h"
#import "UZAppDelegate.h"
#import "NSDictionaryUtils.h"

///lbbbb
#import <UIKit/UIKit.h>
#import "DWSDK.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "DWPlayerMenuView.h"
#import "DWTableView.h"
#import "DWTools.h"
#import "DWMediaSubtitle.h"

#define logerror(format, ...) NSLog(@"%s():%d ERROR============ "format, __func__, __LINE__, ##__VA_ARGS__)
#define logdebug(format, ...) NSLog(@"%s():%d DEBUG------------ "format, __func__, __LINE__, ##__VA_ARGS__)

typedef NS_ENUM(NSInteger, ZXPanDirection){
    
    ZXPanDirectionHorizontal, // 横向移动
    ZXPanDirectionVertical,   // 纵向移动
};

enum {
    DWPlayerScreenSizeModeFill=1,
    DWPlayerScreenSizeMode100,
    DWPlayerScreenSizeMode75,
    DWPlayerScreenSizeMode50
};

typedef NSInteger DWPLayerScreenSizeMode;

@interface LBModuleCCVideo ()<UIAlertViewDelegate,UIGestureRecognizerDelegate>
{
    NSInteger _cbId;
    NSString  *title;
    NSString *userId;
    NSString *apiKey;
    NSInteger definition;
    NSInteger isEncryption;
    NSString *lastStudyTime;
    float viewx;
    float viewy;
    float viewwidth;
    float viewheight;
    DWDownloader *downloader;
    
    UIPanGestureRecognizer *tapPan;
}
@property (strong, nonatomic) UILabel *tipLabel;
@property (strong, nonatomic)UIView *headerView;
@property (strong, nonatomic)UIView *footerView;

@property (strong, nonatomic)UIButton *backButton;

@property (strong, nonatomic)UIActivityIndicatorView *activityView;//菊花
//@property (strong, nonatomic)UILabel *movieSubtitleLabel;
@property (strong, nonatomic)DWMediaSubtitle *mediaSubtitle;

@property (strong, nonatomic)UIButton *playbackButton;
@property (strong, nonatomic)UIButton *playjiangyiButton;

@property (strong, nonatomic)UISlider *durationSlider;//进度条

@property (strong, nonatomic)UILabel *currentPlaybackTimeLabel;//播放时间和总时间

@property (nonatomic, strong)UISlider *customVolumeSlider; // 用来接收系统音量条
@property (strong, nonatomic)UIView *overlayView;
@property (strong, nonatomic)UIView *videoBackgroundView;//播放背景
@property (strong, nonatomic)UITapGestureRecognizer *signelTap;//点击手势
@property (strong, nonatomic)UITapGestureRecognizer *doubleTap;//点击手势
@property (strong, nonatomic)UILabel *videoStatusLabel;

@property (strong, nonatomic)DWMoviePlayerController  *player;//播放器
@property (strong, nonatomic)NSDictionary *playUrls;//播放信息
@property (strong, nonatomic)NSDictionary *currentPlayUrl;//当前播放链接
@property (assign, nonatomic)NSTimeInterval historyPlaybackTime;

@property (strong, nonatomic)NSTimer *timer;

@property (assign, nonatomic)BOOL hiddenAll;//是否隐藏
@property (assign, nonatomic)NSInteger hiddenDelaySeconds;//几秒后隐藏
@property (assign, nonatomic)BOOL isfirst;
@property (assign, nonatomic)NSInteger downloadedSize;//下载大小
@property (assign, nonatomic)DWDownloadItem *ditem;

@property(nonatomic,strong)NSDictionary *playPosition;

@property (nonatomic, assign)ZXPanDirection panDirection;// pan手势移动方向
@property (nonatomic, assign)CGFloat sumTime;// 快进退的总时长
@property (nonatomic, assign)BOOL isVolumeAdjust;// 是否在调节音量

@property (assign, nonatomic)int playFinshNum;//区别是自动播放完成还是点击返回按钮退出时，更新播放状态

@property (nonatomic, strong)NSString *passProgress;//给h5传播放进度

@property (strong, nonatomic)UIButton *switchScrBtn;
@property (assign, nonatomic)BOOL isFullscreen;

@end

@implementation LBModuleCCVideo

static NSMutableArray *array;

+ (void)launch {
    array =[[NSMutableArray alloc] init];
}

+ (NSString*)dictionaryToJson:(NSDictionary *)dic
{
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (id)initWithUZWebView:(UZWebView *)webView_ {
    
    if (self = [super initWithUZWebView:webView_]){
        
        NSDictionary *feature = [self getFeatureByName:@"lbbVideo"];
        userId = [feature stringValueForKey:@"UserId" defaultValue:nil];
        apiKey = [feature stringValueForKey:@"apiKey" defaultValue:nil];
    }
    return self;
}

- (void)dispose {
    //do clean
    // 停止 drmServer
    //[drmServer stop];
}

- (void)open:(NSDictionary *)paramDict{
    
   
    NSLog(@"-----diccc----=%@",paramDict);
    userId = [paramDict stringValueForKey:@"userId" defaultValue:nil];
    apiKey = [paramDict stringValueForKey:@"apiKey" defaultValue:nil];
    lastStudyTime = [paramDict stringValueForKey:@"totime" defaultValue:nil];
    definition =[paramDict integerValueForKey:@"definition" defaultValue:1];
    isEncryption =[paramDict integerValueForKey:@"isEncryption" defaultValue:0];
    self.isfirst = TRUE;
    self.player = [[DWMoviePlayerController alloc] initWithUserId:userId key:apiKey];
    self.player.currentPlaybackRate = 1;
    
    [self addObserverForMPMoviePlayController];
    [self removeTimer];
    [self addTimer];
    
    _cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    
    viewx = [paramDict floatValueForKey:@"x" defaultValue:0];
    viewy = [paramDict floatValueForKey:@"y" defaultValue:20];
    float mainScreenWidth = [UIScreen mainScreen].bounds.size.width;
    float mainScreenHeight = [UIScreen mainScreen].bounds.size.height - 20;
    viewwidth = mainScreenWidth;//[paramDict floatValueForKey:@"w" defaultValue:mainScreenWidth];
    viewheight = mainScreenHeight;//[paramDict floatValueForKey:@"h" defaultValue:mainScreenHeight-viewy];
    
    title = [paramDict stringValueForKey:@"title" defaultValue:nil];//视频id
    self.videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];//视频id
    
    self.localoVideoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];//视频id
    self.videoLocalPath = [paramDict stringValueForKey:@"videoLocalPath" defaultValue:nil];//视频本地地址
    
    NSString * viewName = [paramDict stringValueForKey:@"fixedOn" defaultValue:nil];
    BOOL fixed = [paramDict boolValueForKey:@"fixed" defaultValue:YES];
    
    // 加载播放器 必须第一个加载
    [self loadPlayer:viewName fixed:fixed];
    
    // 加载播放器覆盖视图，它作为所有空间的父视图。
    self.overlayView = [[UIView alloc] initWithFrame:CGRectMake(viewx, viewy, viewwidth,viewheight)];
    self.overlayView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.overlayView fixedOn:viewName fixed:fixed];
    
    //快进，快退
    [self.overlayView addSubview:self.timeIndicatorView];
    // 音量指示器
    [self.overlayView addSubview:self.volumeIndicatorView];
    //亮度
    [self.overlayView addSubview:self.brightnessIndicatorView];
    
    //左右滑动快进
    tapPan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panDirection:)];
    tapPan.delegate = self;
    //    [self.overlayView addGestureRecognizer:pan];
    
    
    [self loadHeaderView];
    [self loadFooterView];
    [self loadVolumeView];
    
    self.signelTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSignelTap:)];
    self.signelTap.numberOfTapsRequired = 1;
    self.signelTap.delegate = self;
    [self.overlayView addGestureRecognizer:self.signelTap];
    
    self.doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    [self.doubleTap setNumberOfTapsRequired:2];
    [self.overlayView addGestureRecognizer:self.doubleTap];
    [self.signelTap requireGestureRecognizerToFail:self.doubleTap];
    
    // 开始下载
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSArray *cpaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cdocumentDirectory = [cpaths objectAtIndex:0];
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    BOOL isLocalPlay = [paramDict boolValueForKey:@"isFinish" defaultValue:NO];
    
    if (isLocalPlay) {
        
        NSString *videoPath;
        NSString *cvideoPath;
        if(isEncryption==1){//加密视频
            
            videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, self.videoId];
            cvideoPath = [NSString stringWithFormat:@"%@/%@.mp4", cdocumentDirectory, self.videoId];
            NSString *tmpPath = [NSString stringWithFormat:@"%@/%@.pcm", documentDirectory, self.videoId];
            NSString *ctmpPath = [NSString stringWithFormat:@"%@/%@.pcm", cdocumentDirectory, self.videoId];
            
            if ([fileMgr fileExistsAtPath:tmpPath]) {
                
                self.videoId = nil;
                self.videoLocalPath = tmpPath;
                
            }else if([fileMgr fileExistsAtPath:ctmpPath]){
                
                self.videoId = nil;
                self.videoLocalPath = ctmpPath;
            }
            
        }else{
            
            videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, self.videoId];
            cvideoPath = [NSString stringWithFormat:@"%@/%@.mp4", cdocumentDirectory, self.videoId];
        }
        
        BOOL bRet = [fileMgr fileExistsAtPath:videoPath];
        if (bRet) {
            
            self.videoId = nil;
            self.videoLocalPath = videoPath;
            
        }else if([fileMgr fileExistsAtPath:cvideoPath]){
            
            self.videoId = nil;
            self.videoLocalPath = cvideoPath;
        }
    }
    
    if (self.videoId) {
        
        [self loadVideoStatusLabel];//在线播放时添加
        // 获取videoId的播放url
        [self loadPlayUrls];
        
    } else if (self.videoLocalPath) {
        
        // 播放本地视频
        [self playLocalVideo];
        
    } else {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示"
                                                        message:@"没有可以播放的视频"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil, nil];
        [alert show];
    }
    // 10 秒后隐藏所有窗口
    self.hiddenDelaySeconds = 10;
}

#pragma mark--------创建快进，快退view----------
- (ZXVideoPlayerTimeIndicatorView *)timeIndicatorView
{
    if (!_timeIndicatorView) {
        
        _timeIndicatorView = [[ZXVideoPlayerTimeIndicatorView alloc] initWithFrame:CGRectMake(self.overlayView.frame.size.width/2 -60, self.overlayView.frame.size.height/2 - 60, kVideoTimeIndicatorViewSide, kVideoTimeIndicatorViewSide)];
    }
    return _timeIndicatorView;
}

- (ZXVideoPlayerBrightnessView *)brightnessIndicatorView
{
    if (!_brightnessIndicatorView){
        
        _brightnessIndicatorView = [[ZXVideoPlayerBrightnessView alloc] initWithFrame:CGRectMake(self.overlayView.frame.size.width/2 -60, self.overlayView.frame.size.height/2 - 60, kVideoTimeIndicatorViewSide, kVideoTimeIndicatorViewSide)];
    }
    return _brightnessIndicatorView;
}

//- (ZXVideoPlayerVolumeView *)volumeIndicatorView
//{
//    if (!_volumeIndicatorView) {
//        _volumeIndicatorView = [[ZXVideoPlayerVolumeView alloc] initWithFrame:CGRectMake(self.overlayView.frame.size.width/2 -60,self.overlayView.frame.size.height/2 - 60, kVideoVolumeIndicatorViewSide, kVideoVolumeIndicatorViewSide)];
//    }
//    return _volumeIndicatorView;
//}

#pragma mark------快进，快退，音量增大，减小手势--------
- (void)panDirection:(UIPanGestureRecognizer *)pan
{
    CGPoint locationPoint = [pan locationInView:self.overlayView];
    CGPoint veloctyPoint = [pan velocityInView:self.overlayView];
    
    switch (pan.state) {
            
        case UIGestureRecognizerStateBegan: { // 开始移动
            
            CGFloat x = fabs(veloctyPoint.x);
            CGFloat y = fabs(veloctyPoint.y);
            
            if (x > y) { // 水平移动
                
                self.panDirection = ZXPanDirectionHorizontal;
                self.sumTime = self.player.currentPlaybackTime; // sumTime初值
                [self.player pause];
                [self stopDurationTimer];
                
            } else if (x < y) { // 垂直移动
                
                self.panDirection = ZXPanDirectionVertical;
                
                if (locationPoint.x > self.overlayView.bounds.size.width / 2) { // 音量调节
                    
                    self.isVolumeAdjust = YES;
                    
                } else { // 亮度调节
                    
                    self.isVolumeAdjust = NO;
                }
            }
        }
            break;
        case UIGestureRecognizerStateChanged: { // 正在移动
            
            switch (self.panDirection) {
                    
                case ZXPanDirectionHorizontal: {
                    
                    [self horizontalMoved:veloctyPoint.x];
                }
                    break;
                case ZXPanDirectionVertical: {
                    
                    [self verticalMoved:veloctyPoint.y];
                }
                    break;
                    
                default:
                    break;
            }
        }
            break;
        case UIGestureRecognizerStateEnded: { // 移动停止
            
            switch (self.panDirection) {
                    
                case ZXPanDirectionHorizontal: {
                    
                    _timeIndicatorView.hidden = YES;
                    _brightnessIndicatorView.hidden = YES;
                    [self.player setCurrentPlaybackTime:floor(self.sumTime)];
                    [self.player play];
                    [self startDurationTimer];
                }
                    break;
                case ZXPanDirectionVertical: {
                    break;
                }
                    break;
                    
                default:
                    break;
            }
        }
            break;
            
        default:
            break;
    }
}

// 暂停定时器
- (void)stopDurationTimer
{
    if (_timer) {
        
        [self.timer setFireDate:[NSDate distantFuture]];
    }
}

#pragma mark-----pan水平移动时弹出快进，快退view------
- (void)horizontalMoved:(CGFloat)value
{
    self.brightnessIndicatorView.hidden = YES;
    // 每次滑动叠加时间
    self.sumTime += value / 200;
    // 容错处理
    if (self.sumTime > self.player.duration) {
        
        self.sumTime = self.player.duration;
        
    } else if (self.sumTime < 0) {
        
        self.sumTime = 0;
    }
    
    // 时间更新
    double currentTime = self.sumTime;
    double totalTime = self.player.duration;
    [self setTimeLabelValues:currentTime totalTime:totalTime];
    // 提示视图
    self.timeIndicatorView.labelText = self.currentPlaybackTimeLabel.text;
    // 播放进度更新
    self.durationSlider.value = self.sumTime;
    
    // 快进or后退 状态调整
    ZXTimeIndicatorPlayState playState = ZXTimeIndicatorPlayStateRewind;
    
    if (value < 0) { // left
        
        playState = ZXTimeIndicatorPlayStateRewind;
        
    } else if (value > 0) { // right
        
        playState = ZXTimeIndicatorPlayStateFastForward;
    }
    
    if (self.timeIndicatorView.playState != playState) {
        
        if (value < 0) { // left
            
            self.timeIndicatorView.playState = ZXTimeIndicatorPlayStateRewind;
            [self.timeIndicatorView setNeedsLayout];
            
        } else if (value > 0) { // right
            
            self.timeIndicatorView.playState = ZXTimeIndicatorPlayStateFastForward;
            [self.timeIndicatorView setNeedsLayout];
        }
    }
}

#pragma mark-----快进，快退时跟新播放时间和进度条-----

- (void)setTimeLabelValues:(double)currentTime totalTime:(double)totalTime {
    
    double minutesElapsed = floor(currentTime / 60.0);
    double secondsElapsed = fmod(currentTime, 60.0);
    NSString *timeElapsedString = [NSString stringWithFormat:@"%02.0f:%02.0f", minutesElapsed, secondsElapsed];
    
    double minutesRemaining = floor(totalTime / 60.0);
    double secondsRemaining = floor(fmod(totalTime, 60.0));
    NSString *timeRmainingString = [NSString stringWithFormat:@"%02.0f:%02.0f", minutesRemaining, secondsRemaining];
    
    self.currentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@/%@",timeElapsedString,timeRmainingString];
}

#pragma mark-----pan垂直移动改变音量-----
// pan垂直移动
- (void)verticalMoved:(CGFloat)value
{
    self.brightnessIndicatorView.hidden = NO;
    if (self.isVolumeAdjust)
    {
        self.brightnessIndicatorView.hidden = YES;
        //快进，快退
        self.customVolumeSlider.value -= value / 10000;
        
    }else {
        
        self.timeIndicatorView.hidden = YES;
        // 亮度
        [UIScreen mainScreen].brightness -= value / 10000;
    }
}

// 开启定时器
- (void)startDurationTimer
{
    if (self.timer) {
        
        [self.timer setFireDate:[NSDate date]];
    }
}

//暂停播放
- (void)stop:(NSDictionary *)paramDict{
    
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    self.hiddenDelaySeconds = 5;
    
    if (!self.playUrls || self.playUrls.count == 0) {
        [self loadPlayUrls];
        return;
    }
    
    UIImage *image = nil;
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        // 暂停播放
        image = [UIImage imageNamed:@"res_lbbVideo/player-playbutton"];
        [self.player pause];
        [self.playbackButton setImage:image forState:UIControlStateNormal];
    }
    
    if (cbId >= 0) {
        
        NSDictionary *ret = @{@"btnType":@"stop",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
}
//关闭播放器
- (void)close:(NSDictionary *)paramDict{
    
    [self.player cancelRequestPlayInfo];
    [self saveNsUserDefaults];
    self.player.currentPlaybackTime = self.player.duration;
    self.player.contentURL = nil;
    [self.player stop];
    self.player = nil;
    [self removeAllObserver];
    [self removeTimer];
    // 显示 状态栏  quanping
    //[[UIApplication sharedApplication] setStatusBarHidden:NO];
    //[self.navigationController popViewControllerAnimated:YES];
    [self.videoBackgroundView removeFromSuperview];
    [self.overlayView removeFromSuperview];
}
//开始播放
- (void)start:(NSDictionary *)paramDict{
    
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    self.hiddenDelaySeconds = 5;
    
    if (!self.playUrls || self.playUrls.count == 0) {
        
        [self loadPlayUrls];
        return;
    }
    
    UIImage *image = nil;
    if (self.player.playbackState != MPMoviePlaybackStatePlaying) {
        // 继续播放
        image = [UIImage imageNamed:@"res_lbbVideo/player-pausebutton"];
        [self.player play];
        [self.playbackButton setImage:image forState:UIControlStateNormal];
    }
    if (cbId >= 0) {
        
        NSDictionary *ret = @{@"btnType":@"start",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
}

-(void)iosGetStudyProgress:(NSDictionary *)paramDict
{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    if (cbId >= 0){
        
        NSDictionary *ret = @{@"status":@"100",@"ctime":[NSString stringWithFormat:@"%@",self.passProgress]};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
}
//跳到指定位置播放
- (void)seekTo:(NSDictionary *)paramDict{
    
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    if (cbId >= 0){
        
        NSDictionary *ret = @{@"status":@"100",@"ctime":[NSString stringWithFormat:@"%@",self.passProgress]};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
}

-(void)downloadCourseTabel:(NSDictionary *)paramDict
{
    [[DWTools shareInstance] creatDownloadTable];//课程下载表
    [[DWTools shareInstance] creatVideoCourseJsonTable];//课程详情json表
}

-(void)insertDowndCourseState:(NSDictionary *)paramDict{
    
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    NSString *tempUserId =[paramDict stringValueForKey:@"UserId" defaultValue:nil];
    NSString *tempCourseId = [paramDict stringValueForKey:@"courseId" defaultValue:nil];
    NSString *tempVideoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];
    NSString *tempExpirationTime = [paramDict stringValueForKey:@"videoId" defaultValue:nil];
    NSString *tempPath = [paramDict stringValueForKey:@"path" defaultValue:nil];
    NSString *tempIsbuy =  [paramDict stringValueForKey:@"isbuy" defaultValue:nil];
    NSString *tempIslock =  [paramDict stringValueForKey:@"islock" defaultValue:nil];
    NSString *tempActivestate =  [paramDict stringValueForKey:@"activestate" defaultValue:nil];
    NSString *tempTaskIndex =  [paramDict stringValueForKey:@"videoId" defaultValue:nil];
    
    NSDictionary *ret = @{@"data":@"1"};
    [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:NO];
    
    NSDate *tempTime = [NSDate date];
    NSString *timeStr = [NSString stringWithFormat:@"%ld", (long)[tempTime timeIntervalSince1970]];
    
    BOOL isExist = [[DWTools shareInstance] isExistDownloadingTask:@"1" :tempUserId];
    NSString *tempState = nil;
    if (isExist) {
        
        tempState = @"5";
        
    }else
    {
        tempState = @"1";
    }
    
    [[DWTools shareInstance] managerDownlodTableWithUserid:tempUserId courseId:tempCourseId videoId:tempVideoId state:tempState progress:@"0" expitationTime:tempExpirationTime path:tempPath downloadTime:timeStr isBuy:tempIsbuy isLock:tempIslock activeState:tempActivestate modifyTime:timeStr playTime:@"0" taskIndex:tempTaskIndex];
}

-(void)inserCourseDetailJson:(NSDictionary *)paramDict{
    
    NSString *tempUserId = [paramDict stringValueForKey:@"userId" defaultValue:nil];
    NSString *courseId = [paramDict stringValueForKey:@"courseId" defaultValue:nil];
    NSString *jsonStr = [paramDict stringValueForKey:@"courseJson" defaultValue:nil];
    
    [[DWTools shareInstance] managerCourseJsonTableWithUserId:tempUserId andCourseId:courseId andCourseJson:jsonStr];
    
}

-(void)updatePlayTime:(NSDictionary *)paramDict
{
    NSString *tempUserId = [paramDict stringValueForKey:@"userId" defaultValue:nil];
    NSString *videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];
    NSString *playTime = [paramDict stringValueForKey:@"playTime" defaultValue:nil];
    [[DWTools shareInstance] updatePlayTimeWithUserID:tempUserId andVideoId:videoId andPlayTime:playTime];
}

-(void)getTaskData:(NSDictionary *)paramDict
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSArray *cpaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cdocumentDirectory = [cpaths objectAtIndex:0];
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    NSString *tempUserId = [paramDict stringValueForKey:@"UserId" defaultValue:nil];
    NSString *readTime = [paramDict stringValueForKey:@"readTime" defaultValue:nil];
    
    NSMutableArray *array = [[DWTools shareInstance] getAllCourseJson:tempUserId];
    for (NSString *tempVideoId in array) {
        
        NSString *videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, tempVideoId];
        NSString *cvideoPath = [NSString stringWithFormat:@"%@/%@.mp4", cdocumentDirectory, tempVideoId];
        NSString *tmpPath = [NSString stringWithFormat:@"%@/%@.pcm", documentDirectory, tempVideoId];
        NSString *ctmpPath = [NSString stringWithFormat:@"%@/%@.pcm", cdocumentDirectory, tempVideoId];
        
        if (![fileMgr fileExistsAtPath:videoPath] && ![fileMgr fileExistsAtPath:cvideoPath] && ![fileMgr fileExistsAtPath:tmpPath] && ![fileMgr fileExistsAtPath:ctmpPath])
        {
            [[DWTools shareInstance] updateCourseState:tempUserId andVideoId:tempVideoId andState:@"3" andModifyTime:@"1"];
        }
        
    }
    NSString *str = [[DWTools shareInstance] getTaskData:tempUserId andTime:readTime];
    
    NSDictionary *ret = @{@"data":str};
    [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
}
-(void)getCourseJsonWithCourseId:(NSDictionary *)paramDict
{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    
    NSString *tempUserId = [paramDict stringValueForKey:@"userId" defaultValue:nil];
    NSString *courseId = [paramDict stringValueForKey:@"courseId" defaultValue:nil];
    if ([courseId isEqualToString:@""]||courseId == nil || courseId ==NULL) {
        
        NSMutableArray *courseArr = [[DWTools shareInstance] getAllCourseJson:tempUserId];
        NSDictionary *ret = @{@"data":courseArr};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
        
    }else
    {
        NSMutableArray *courseArr = [[DWTools shareInstance] getCourseJsonWithCourseId:courseId andUserId:tempUserId];
        NSDictionary *ret = @{@"data":courseArr};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
}

-(void)deleteCourseTask:(NSDictionary *)paramDict
{
    NSString *tempUserId = [paramDict stringValueForKey:@"userId" defaultValue:nil];
    NSString *videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];
    [[DWTools shareInstance] deleteCourseTaskWithUserId:tempUserId andVideoId:videoId];
}

- (void)download:(NSDictionary *)paramDict{
    
    __block LBModuleCCVideo  *that  = self;
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    
    userId = [paramDict stringValueForKey:@"UserId" defaultValue:nil];//用户Id
    
    NSString *videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];//视频id
    
    NSDate *tempTime = [NSDate date];
    NSString *timeStr = [NSString stringWithFormat:@"%ld", (long)[tempTime timeIntervalSince1970]];
    [[DWTools shareInstance] managerDownlodTableWithUserid:userId courseId:@"1" videoId:videoId state:@"5" progress:@"0" expitationTime:@"1" path:@"1" downloadTime:timeStr isBuy:@"1" isLock:@"1" activeState:@"1" modifyTime:timeStr playTime:@"0" taskIndex:@"1"];
    
    if (!videoId) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示"
                                                        message:@"videoId不能为空"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil, nil];
        [alert show];
        NSDictionary *ret = @{@"videoId":videoId,@"status":@"0",@"progress":@"0"};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:NO];
        return;
    }
    // 开始下载
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    userId = [paramDict stringValueForKey:@"UserId" defaultValue:nil];
    apiKey = [paramDict stringValueForKey:@"apiKey" defaultValue:nil];
    NSInteger  isDEncryption = [paramDict integerValueForKey:@"isEncryption" defaultValue:0];
    NSString *videoPath;
    if(isDEncryption==0){//不加密
        
        videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, videoId];
        
    }else{//加密账号
        
        videoPath = [NSString stringWithFormat:@"%@/%@.pcm", documentDirectory, videoId];
    }
    //一个视频id被多次连续调用下载，不处理，直接返回
    if([videoId isEqualToString:self.downloadVideoId] && (self.ditem.videoDownloadStatus==DWDownloadStatusStart || self.ditem.videoDownloadStatus == DWDownloadStatusDownloading)){
        
        return;
    }
    
    if(downloader != nil){
        //切换视频下载文件时候，前一个视频文件并没有真正的开始下载，而是还在获取下载信息过程中
        //这个时候不能切换下载视频文件，防止多个进程下载同一个视频文件
        if(self.ditem.videoDownloadStatus == DWDownloadStatusStart){
            
            NSDictionary *ret = @{@"videoId":videoId,@"status":@"2",@"progress":@"0",@"result":@"系统繁忙无法切换视频下载"};
            [that sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
            
            return;
        }
        [downloader pause];
        self.ditem.videoDownloadStatus = DWDownloadStatusPause;
    }
    downloader = nil;
    for(DWDownloadItem *item in array){
        
        if([videoId isEqualToString:item.videoId]){
            
            downloader = item.downloader;
            self.ditem = item;
            break;
        }
    }
    
    if(downloader == nil){
        
        DWDownloadItem *item = [[DWDownloadItem alloc] initWithVideoId:videoId];
        item.downloader = [[DWDownloader alloc] initWithUserId:userId
                                                    andVideoId:videoId
                                                           key:apiKey
                                               destinationPath:videoPath];
        
        downloader = item.downloader;
        item.time =  [[NSDate date] timeIntervalSince1970];
        self.ditem = item;
        [array insertObject:item atIndex:0];
    }
    
    self.downloadVideoId = videoId;
    self.progress = @"0";
    
    self.ditem.downloader.timeoutSeconds = 10;
    
    self.ditem.downloader.progressBlock = ^(float progress, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite){
        
        that.ditem.videoDownloadStatus = DWDownloadStatusDownloading;
        that.downloadedSize = totalBytesWritten;
        if(that.ditem.downloader.remoteFileSize < 2000){
            
            [that rmFile:that.downloadVideoId];
            return;
        }
        
        if (cbId >= 0) {
            
            float downloadedSizeMB = totalBytesWritten/1024.0/1024.0;
            float fileSizeMB = downloader.remoteFileSize/1024.0/1024.0;
            float videoDownloadProgress =(float)(downloadedSizeMB/fileSizeMB*100);
            
            NSString *progre =[NSString stringWithFormat:@"%0.0f" ,progress];
            
            if(videoDownloadProgress>0 && true != [progre isEqualToString:that.progress]){
                
                that.progress =  progre;
                
                NSDictionary *ret = @{@"videoId":videoId,@"status":@"1",@"progress":progre,@"finish":@"NO"};
                [that sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:NO];
                
                NSDate *tempTime = [NSDate date];
                NSString *timeStr = [NSString stringWithFormat:@"%ld", (long)[tempTime timeIntervalSince1970]];
                
                [[DWTools shareInstance] updateDownloadTableWithUserid:userId andVideoId:videoId andState:@"1" andProgress:[NSString stringWithFormat:@"%f",progress] andModifyTime:timeStr];
            }
        }else{
            //logerror(@"download progressBlock %@", @"lbbniu");
        }
    };
    
    self.ditem.downloader.failBlock = ^(NSError *error) {
        
        that.ditem.time -= 7200;
        
        if(that.ditem.downloader.remoteFileSize == -1){
            
            NSDate *tempTime = [NSDate date];
            NSString *timeStr = [NSString stringWithFormat:@"%ld", (long)[tempTime timeIntervalSince1970]];
            [[DWTools shareInstance] updateCourseState:userId andVideoId:videoId andState:@"4" andModifyTime:timeStr];
            
            NSDictionary *ret = @{@"videoId":videoId,@"status":@"3",@"progress":@"0",@"result":[error localizedDescription]};
            [that sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:NO];
        }
        if(that.ditem.downloader.remoteFileSize < 2000){
            
            that.progress = @"0";
            [that rmFile:that.downloadVideoId];
        }
        if(that.ditem.count <= 3){
            
            that.ditem.count = that.ditem.count +1;
            [that.ditem.downloader start];
            return;
        }
        if (cbId >= 0) {
            
            that.ditem.videoDownloadStatus = DWDownloadStatusFail;
            NSDictionary *ret = @{@"videoId":videoId,@"status":@"0",@"progress":@"0",@"result":[error localizedDescription]};
            [that sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
            
            NSDate *tempTime = [NSDate date];
            NSString *timeStr = [NSString stringWithFormat:@"%ld", (long)[tempTime timeIntervalSince1970]];
            [[DWTools shareInstance] updateCourseState:userId andVideoId:videoId andState:@"4" andModifyTime:timeStr];
        }
    };
    
    self.ditem.downloader.finishBlock = ^() {
        
        if (cbId >= 0) {
            
            NSDictionary *ret = @{@"videoId":videoId,@"progress":@"100",@"result":@"下载完成",@"status":@"1",@"finish":@"YES"};
            that.ditem.videoDownloadStatus = DWDownloadStatusFinish;
            [that sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
            
            NSDate *tempTime = [NSDate date];
            NSString *timeStr = [NSString stringWithFormat:@"%ld", (long)[tempTime timeIntervalSince1970]];
            
            [[DWTools shareInstance] updateDownloadTableWithUserid:userId andVideoId:videoId andState:@"4" andProgress:@"100" andModifyTime:timeStr];
        }
    };
    
    if(downloader != nil && self.ditem.videoDownloadStatus == DWDownloadStatusFinish){
        
        if (cbId >= 0) {
            
            NSDictionary *ret = @{@"videoId":videoId,@"progress":@"100",@"result":@"下载完成",@"status":@"1",@"finish":@"YES"};
            [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
            
            NSDate *tempTime = [NSDate date];
            NSString *timeStr = [NSString stringWithFormat:@"%ld", (long)[tempTime timeIntervalSince1970]];
            
            [[DWTools shareInstance] updateDownloadTableWithUserid:userId andVideoId:videoId andState:@"1" andProgress:@"100" andModifyTime:timeStr];
        }
        return;
    }
    if(downloader != nil && self.ditem.videoDownloadStatus == DWDownloadStatusPause){
        
        if([[NSDate date] timeIntervalSince1970] - self.ditem.time < 6000){
            
            [downloader resume];
            self.ditem.videoDownloadStatus = DWDownloadStatusStart;
            
            return;
        }
    }
    self.ditem.time = [[NSDate date] timeIntervalSince1970];
    [self.ditem.downloader start];
    self.ditem.count = 1;
    self.ditem.videoDownloadStatus = DWDownloadStatusStart;
    
}

- (void)downloadStop:(NSDictionary *)paramDict{
    
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    if (downloader && self.ditem.videoDownloadStatus != DWDownloadStatusStart) {
        
        [self.ditem.downloader pause];
        self.ditem.videoDownloadStatus = DWDownloadStatusPause;
        
        if (cbId >= 0) {
            
            NSDictionary *ret = @{@"status":@"1"};
            [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
            return;
        }
    }
    if (cbId >= 0) {
        
        NSDictionary *ret;
        if(downloader == nil){
            
            ret = @{@"status":@"1"};
            
        }else{
            
            ret = @{@"status":@"0"};
        }
        
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
}

- (void)downloadStart:(NSDictionary *)paramDict{
    
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    
    if (downloader) {
        
        [self.ditem.downloader resume];
        self.ditem.videoDownloadStatus = DWDownloadStatusDownloading;
    }
    
    if (cbId >= 0) {
        
        NSDictionary *ret = @{@"status":@"1"};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
}

-(void)getDownloadProgress:(NSDictionary *)paramDict
{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    userId = [paramDict stringValueForKey:@"UserId" defaultValue:nil];//用户Id
    NSString *videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];//视频id
    
    NSDictionary *tempDic = [[DWTools shareInstance] getProgressStateWithVideoId:videoId andUserId:userId ];
    NSLog(@"----tempDic-----=%@",tempDic);
    [self sendResultEventWithCallbackId:cbId dataDict:tempDic errDict:nil doDelete:YES];
}

- (void)removeDownloadVideo:(NSDictionary *)paramDict{
    
    NSString *videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];//视频id
    if (!videoId) {
        return;
    }
    [self rmFile:videoId];
}

- (void)rmFile:(NSString *)videoId{
    
    if (!videoId) {
        return;
    }
    //document目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSString *videoPath;
    NSError *err;
    videoPath = [NSString stringWithFormat:@"%@/%@.pcm", documentDirectory, videoId];
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    BOOL bRet = [fileMgr fileExistsAtPath:videoPath];
    if (bRet) {
        
        [fileMgr removeItemAtPath:videoPath error:&err];
    }
    videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, videoId];
    bRet = [fileMgr fileExistsAtPath:videoPath];
    if (bRet) {
        
        [fileMgr removeItemAtPath:videoPath error:&err];
    }
    //caches目录
    paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    documentDirectory = [paths objectAtIndex:0];
    videoPath = [NSString stringWithFormat:@"%@/%@.pcm", documentDirectory, videoId];
    bRet = [fileMgr fileExistsAtPath:videoPath];
    if (bRet) {
        
        [fileMgr removeItemAtPath:videoPath error:&err];
    }
    videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, videoId];
    bRet = [fileMgr fileExistsAtPath:videoPath];
    if (bRet) {
        
        [fileMgr removeItemAtPath:videoPath error:&err];
    }
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        [self.player stop];
        self.player.contentURL = nil;
        self.player = nil;
        [self removeAllObserver];
        [self removeTimer];
        //[self.navigationController popViewControllerAnimated:YES];
    }
    if (buttonIndex == 1) {
        [self.player play];
    }
}
# pragma mark - 音量
- (void)loadVolumeView
{
    MPVolumeView *volum = [[MPVolumeView alloc] init];
    volum.center = CGPointMake(-1000, 0);
    // 遍历volumView上控件，取出音量slider
    for (UIView *view in volum.subviews){
        
        if ([view isKindOfClass:[UISlider class]]) {
            // 接收系统音量条
            self.customVolumeSlider = (UISlider *)view;
        }
    }
}

- (void)volumeSliderMoved:(UISlider *)slider
{
    self.customVolumeSlider.value = slider.value;
}

# pragma mark - 手势识别 UIGestureRecognizerDelegate
-(void)handleSignelTap:(UIGestureRecognizer*)gestureRecognizer
{
    if (self.hiddenAll) {
        
        [self showBasicViews];
        self.hiddenDelaySeconds = 5;
        
    }else {
        
        [self hiddenAllView];
        self.hiddenDelaySeconds = 0;
    }
}

-(void)handleDoubleTap:(UIGestureRecognizer *)gesture
{
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        // 暂停播放
        [self.player pause];
        
    }else if (self.player.playbackState == MPMoviePlaybackStatePaused)
    {
        [self.player play];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (gestureRecognizer == self.signelTap) {
        if ([touch.view isKindOfClass:[UIButton class]]) {
            return NO;
        }
        
        if ([touch.view isKindOfClass:[DWTableView class]]) {
            return NO;
        }
        if ([touch.view isKindOfClass:[UISlider class]]) {
            return NO;
        }
        if ([touch.view isKindOfClass:[UIImageView class]]) {
            return NO;
        }
        
        if ([touch.view isKindOfClass:[UITableView class]]) {
            return NO;
        }
        if ([touch.view isKindOfClass:[UITableViewCell class]]) {
            return NO;
        }
        // UITableViewCellContentView => UITableViewCell
        if([touch.view.superview isKindOfClass:[UITableViewCell class]]) {
            return NO;
        }
        
        // UITableViewCellContentView => UITableViewCellScrollView => UITableViewCell
        if([touch.view.superview.superview isKindOfClass:[UITableViewCell class]]) {
            return NO;
        }
    }
    return YES;
}

# pragma mark - 加载播放器
- (void)loadPlayer:(NSString *)viewName fixed:(BOOL)fixed
{
    self.videoBackgroundView = [[UIView alloc] init];
    self.videoBackgroundView.frame = CGRectMake(viewx, viewy, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    
    self.videoBackgroundView.backgroundColor = [UIColor whiteColor];
    
    [self addSubview:self.videoBackgroundView fixedOn:viewName fixed:fixed];
    
    self.player.scalingMode = MPMovieScalingModeAspectFit;
    self.player.controlStyle = MPMovieControlStyleNone;
    self.player.view.backgroundColor = [UIColor clearColor];
    self.player.view.frame = self.videoBackgroundView.bounds;
    
    [self.videoBackgroundView addSubview:self.player.view];
}

# pragma mark - 播放视频
- (void)loadPlayUrls
{
    self.player.videoId = self.videoId;
    self.player.timeoutSeconds = 10;
    
    __weak LBModuleCCVideo *blockSelf = self;
    self.player.failBlock = ^(NSError *error) {
        blockSelf.videoStatusLabel.hidden = NO;
        blockSelf.videoStatusLabel.text = @"加载失败";
    };
    
    self.player.getPlayUrlsBlock = ^(NSDictionary *playUrls) {
        // [必须]判断 status 的状态，不为"0"说明该视频不可播放，可能正处于转码、审核等状态。
        NSNumber *status = [playUrls objectForKey:@"status"];
        if (status == nil || [status integerValue] != 0) {
            
            NSString *message = [NSString stringWithFormat:@"%@ %@:%@",
                                 blockSelf.videoId,
                                 [playUrls objectForKey:@"status"],
                                 [playUrls objectForKey:@"statusinfo"]];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示"
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil, nil];
            [alert show];
            return;
        }
        
        blockSelf.playUrls = playUrls;
        
        [blockSelf resetViewContent];
    };
    
    [self.player startRequestPlayInfo];
}

# pragma mark - 根据播放url更新涉及的视图

- (void)resetViewContent
{
    // 获取默认清晰度播放url
    NSNumber *defaultquality = [self.playUrls objectForKey:@"defaultquality"];
    if(definition == 1){
        
        defaultquality = [NSNumber numberWithInteger:10];
        
    }else{
        
        defaultquality = [NSNumber numberWithInteger:20];
    }
    for (NSDictionary *playurl in [self.playUrls objectForKey:@"qualities"]) {
        
        if (defaultquality == [playurl objectForKey:@"quality"]) {
            
            self.currentPlayUrl = playurl;
            break;
        }
    }
    
    if (!self.currentPlayUrl) {
        
        self.currentPlayUrl = [[self.playUrls objectForKey:@"qualities"] objectAtIndex:0];
    }
    
    [self.player prepareToPlay];
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    [self.player play];
}

# pragma mark - headerView
- (void)loadHeaderView
{
    //全屏
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,self.overlayView.frame.size.width, 38)];
    self.headerView.backgroundColor = [UIColor colorWithRed:33/255.0 green:41/255.0 blue:43/255.0 alpha:1];
    [self.overlayView addSubview:self.headerView];
    /**
     *  NOTE: 由于各个view之间的坐标有依赖关系，所以以下view的加载顺序必须为：
     *  qualityView -> subtitleView -> backButton
     */
    
    if (self.videoId){
        // 清晰度   右上角按钮，不是清晰度，回调按钮
        //        [self loadQualityView];
    }
    
    // 返回按钮及视频标题
    [self loadBackButton];
}




# pragma mark 返回按钮及视频标题
- (void)loadBackButton
{
    self.backButton = [[UIButton alloc]init];
    self.backButton.frame = CGRectMake(15, 4, self.headerView.frame.size.width - 260, 30);
    self.backButton.backgroundColor = [UIColor clearColor];
    self.backButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.backButton setTitle: title forState:UIControlStateNormal];
    [self.backButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.backButton setImage:[UIImage imageNamed:@"res_lbbVideo/player-back-button"] forState:UIControlStateNormal];
    self.backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.backButton addTarget:self action:@selector(backButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.backButton];
}

- (void)backButtonAction:(UIButton *)button
{
    //菊花结束
    [_activityView stopAnimating];
    
    if (_cbId >= 0) {
        
        NSDictionary *ret = @{@"btnType":@"1",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
    [self.player cancelRequestPlayInfo];
    [self saveNsUserDefaults];
    self.player.currentPlaybackTime = self.player.duration;
    self.player.contentURL = nil;
    [self.player stop];
    self.player = nil;
    [self removeAllObserver];
    [self removeTimer];
    // 显示 状态栏  quanping
    [self.videoBackgroundView removeFromSuperview];
    [self.overlayView removeFromSuperview];
}

- (void)loadFooterView
{
    self.footerView = [[UIView alloc] initWithFrame:CGRectMake(0, self.overlayView.frame.size.height-50, self.overlayView.frame.size.width, 50)];
    self.footerView.backgroundColor = [UIColor colorWithWhite:31/255.0f alpha:1];
    [self.overlayView addSubview:self.footerView];
    
    // 播放按钮
    [self loadPlaybackButton];
    
    // 当前播放时间
    [self loadCurrentPlaybackTimeLabel];
    
    
    // 时间滑动条
    [self loadPlaybackSlider];
    
    //屏幕翻转
    [self loadSwitchScrBtn];

}

#pragma -------mark 上一节  播放按钮  下一节---------
- (void)loadPlaybackButton
{
    //播放按钮
    self.playbackButton = [[UIButton alloc]init];
    self.playbackButton.frame = CGRectMake(15,5, 40, 40);
    [self.playbackButton setImage:[UIImage imageNamed:@"res_lbbVideo/player-playbutton"] forState:UIControlStateNormal];
    [self.playbackButton addTarget:self action:@selector(playbackButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:self.playbackButton];
}

#pragma -------mark-----创建笔记，讲义等----
-(void)loadSwitchScrBtn
{
    CGRect frame;
    if (_isFullscreen == NO) {
        frame.origin.x = self.footerView.frame.size.width - 35;
        frame.origin.y = self.footerView.frame.origin.y;
        frame.size.width = 38;
        frame.size.height = 38;
    }
    else{
        frame.origin.x = self.footerView.frame.size.width - 35;
        frame.origin.y = self.footerView.frame.origin.y;
        frame.size.width = 40;
        frame.size.height = 40;
    }
    
    
    self.switchScrBtn.frame = frame;
    self.switchScrBtn.backgroundColor = [UIColor clearColor];
    self.switchScrBtn.showsTouchWhenHighlighted = YES;
    [self.switchScrBtn setImage:[UIImage imageNamed:@"fullscreen.png"] forState:UIControlStateNormal];
    [self.switchScrBtn setImage:[UIImage imageNamed:@"nonfullscreen.png"] forState:UIControlStateSelected];
    [self.switchScrBtn addTarget:self action:@selector(switchScreenAction:)
                forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:self.switchScrBtn];
    logdebug(@"self.switchScrBtn.frame: %@", NSStringFromCGRect(self.switchScrBtn.frame));
}
-(void)switchScreenAction:(UIButton *)button
{
    self.switchScrBtn.selected = !self.switchScrBtn.selected;
    
//    if (self.switchScrBtn.selected == YES) {
//        [self FullScreenFrameChanges];
//        if (_adPlay && _playMode) {
//            [self loadAdview];
//        }
//        [[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationLandscapeLeft] forKey:@"orientation"];
//        self.isFullscreen = YES;
//        NSLog(@"点击按钮 to Full");
//    }
//    else{
//        [self SmallScreenFrameChanges];
//        if (_adPlay && _playMode) {
//            [self loadAdview];
//        }
//        self.isFullscreen = NO;
//        NSLog(@"点击按钮 to Small");
//    }
}
#pragma -------mark-----播放按钮-------
- (void)playbackButtonAction:(UIButton *)button
{
    self.hiddenDelaySeconds = 5;
    
    if (!self.playUrls || self.playUrls.count == 0) {
        
        [self loadPlayUrls];
        return;
    }
    
    UIImage *image = nil;
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        // 暂停播放
        image = [UIImage imageNamed:@"res_lbbVideo/player-playbutton"];
        [self.player pause];
        
    } else {
        // 继续播放
        image = [UIImage imageNamed:@"res_lbbVideo/player-pausebutton"];
        [self.player play];
    }
    
    [self.playbackButton setImage:image forState:UIControlStateNormal];
    
    if (_cbId >= 0) {
        
        NSDictionary *ret = @{@"btnType":@"play",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
}




# pragma mark ----------当前播放时间--------
- (void)loadCurrentPlaybackTimeLabel
{
    self.currentPlaybackTimeLabel = [[UILabel alloc] init];
    self.currentPlaybackTimeLabel.frame = CGRectMake(self.playbackButton.frame.origin.x + self.playbackButton.frame.size.width + 15, 15, 150, 20);
    self.currentPlaybackTimeLabel.text =[NSString stringWithFormat:@"%@/%@",@"00:00",@"00:00"];
    self.currentPlaybackTimeLabel.textColor = [UIColor whiteColor];
    self.currentPlaybackTimeLabel.font = [UIFont systemFontOfSize:14];
    self.currentPlaybackTimeLabel.backgroundColor = [UIColor clearColor];
    [self.footerView addSubview:self.currentPlaybackTimeLabel];
}

# pragma mark -----------时间滑动条--------
- (void)loadPlaybackSlider
{
    self.durationSlider = [[UISlider alloc] init];
    self.durationSlider.frame = CGRectMake(0,-15, self.footerView.frame.size.width, 30);
    self.durationSlider.value = 0.0f;
    self.durationSlider.minimumValue = 0.0f;
    self.durationSlider.maximumValue = 1.0f;
    [self.durationSlider setMaximumTrackImage:[UIImage imageNamed:@"res_lbbVideo/player-slider-inactive"]
                                     forState:UIControlStateNormal];
    [self.durationSlider setMinimumTrackImage:[UIImage imageNamed:@"res_lbbVideo/player-slider-active"]
                                     forState:UIControlStateNormal];
    [self.durationSlider setThumbImage:[UIImage imageNamed:@"res_lbbVideo/player-slider-handle"]
                              forState:UIControlStateNormal];
    [self.durationSlider addTarget:self action:@selector(durationSliderMoving:) forControlEvents:UIControlEventValueChanged];
    [self.durationSlider addTarget:self action:@selector(durationSliderDone:) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:self.durationSlider];
}

- (void)durationSliderMoving:(UISlider *)slider
{
    if (self.player.playbackState != MPMoviePlaybackStatePaused) {
        [self.player pause];
    }
    self.player.currentPlaybackTime = slider.value;
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
    self.currentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.currentPlaybackTimeLabel.text, [DWTools formatSecondsToString:self.player.duration]];
    self.historyPlaybackTime = self.player.currentPlaybackTime;
}

- (void)durationSliderDone:(UISlider *)slider
{
    if (self.player.playbackState != MPMoviePlaybackStatePlaying) {
        [self.player play];
    }
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
    self.currentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.currentPlaybackTimeLabel.text, [DWTools formatSecondsToString:self.player.duration]];
    self.historyPlaybackTime = self.player.currentPlaybackTime;
}

- (void)resetPlayer
{
    self.player.contentURL = [NSURL URLWithString:[self.currentPlayUrl objectForKey:@"playurl"]];
    self.videoStatusLabel.hidden = NO;
    self.videoStatusLabel.text = @"正在加载...";
    
    [self.player prepareToPlay];
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    [self.player play];
}
# pragma mark --------播放本地文件-------

- (void)playLocalVideo
{
    self.playUrls = [NSDictionary dictionaryWithObject:self.videoLocalPath forKey:@"playurl"];
    self.player.contentURL = [[NSURL alloc] initFileURLWithPath:self.videoLocalPath];
    [self.player prepareToPlay];
    AVAudioSession *audioSession =[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    [self.player play];
}

# pragma mark ------MPMoviePlayController Notifications-------
- (void)addObserverForMPMoviePlayController
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // MPMovieDurationAvailableNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerDurationAvailable) name:MPMovieDurationAvailableNotification object:self.player];
    
    // MPMoviePlayerLoadStateDidChangeNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerLoadStateDidChange) name:MPMoviePlayerLoadStateDidChangeNotification object:self.player];
    
    // MPMoviePlayerPlaybackDidFinishNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerPlaybackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.player];
    
    // MPMoviePlayerPlaybackStateDidChangeNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerPlaybackStateDidChange) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
}

- (void)moviePlayerDurationAvailable
{
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:0];
    self.currentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.currentPlaybackTimeLabel.text, [DWTools formatSecondsToString:self.player.duration]];
    self.durationSlider.minimumValue = 0.0;
    self.durationSlider.maximumValue = self.player.duration;
}

- (void)moviePlayerLoadStateDidChange
{
    switch (self.player.loadState) {
            
        case MPMovieLoadStatePlayable://1
            
            // 可播放
            self.videoStatusLabel.hidden = YES;
            self.activityView.hidden = YES;
            if (_videoId||self.localoVideoId) {
                
                if (self.player.playNum < 2) {
                    
                    [self readNSUserDefaults];
                    [self.player first_load];
                    self.player.playNum ++;
                }
            }
            break;
        case MPMovieLoadStatePlaythroughOK://2
            
            // 状态为缓冲几乎完成，可以连续播放
            self.videoStatusLabel.hidden = YES;
            self.activityView.hidden = YES;
            if (_videoId||self.localoVideoId) {
                
                if (self.player.playNum < 2) {
                    
                    [self readNSUserDefaults];
                    [self.player first_load];
                    self.player.playNum ++;
                }
            }
            break;
        case MPMovieLoadStateStalled://4
            // 缓冲中
            self.activityView.hidden = NO;
            self.videoStatusLabel.hidden = NO;
            self.videoStatusLabel.text = @"正在加载...";
            break;
            
        case MPMovieLoadStateUnknown://0
            self.activityView.hidden = YES;
            
        default:
            break;
    }
}

- (void)moviePlayerPlaybackDidFinish:(NSNotification *)notification
{
    NSNumber *n = [[notification userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    switch ([n intValue]) {
            
        case MPMovieFinishReasonPlaybackEnded:
            
            [self playFinsh];
            self.activityView.hidden = YES;
            self.videoStatusLabel.hidden = YES;
            break;
            
        case MPMovieFinishReasonPlaybackError:
            
            self.activityView.hidden = YES;
            self.videoStatusLabel.hidden = NO;
            self.videoStatusLabel.text = @"加载失败";
            break;
            
        case MPMovieFinishReasonUserExited:
            
            break;
            
        default:
            break;
    }
}

- (void)moviePlayerPlaybackStateDidChange
{
    switch ([self.player playbackState]) {
            
        case MPMoviePlaybackStateStopped:
            
            self.activityView.hidden = YES;
            self.videoStatusLabel.hidden = YES;
            [self.playbackButton setImage:[UIImage imageNamed:@"res_lbbVideo/player-playbutton"] forState:UIControlStateNormal];
            break;
            
        case MPMoviePlaybackStatePlaying:
            
            [self.activityView  stopAnimating];
            [self.playbackButton setImage:[UIImage imageNamed:@"res_lbbVideo/player-pausebutton"] forState:UIControlStateNormal];
            
            self.activityView.hidden = YES;
            self.videoStatusLabel.hidden = YES;
            [self.overlayView addGestureRecognizer:tapPan];
            self.player.playaction = @"buffereddrag";
            if (_videoId) {
                
                if (self.player.playNum >1 && self.player.isReplay == NO) {
                    [self.player replay];
                }
            }
            break;
            
        case MPMoviePlaybackStatePaused:
            
            [self.playbackButton setImage:[UIImage imageNamed:@"res_lbbVideo/player-playbutton"] forState:UIControlStateNormal];
            //self.videoStatusLabel.hidden = NO;
            self.player.action++;
            self.player.playaction = @"unbuffereddrag";
            if (_videoId) {
                if (self.player.playableDuration < 5 && self.player.playNum >1 && self.player.sourceURL==nil) {
                    
                    [self.player playlog];
                    
                    if (self.player.action == 1 || self.player.action == 3) {
                        
                        [self.player playlog_php];
                    }
                }
            }
            //self.videoStatusLabel.text = @"暂停";
            break;
            
        case MPMoviePlaybackStateInterrupted:
            
            
            [self.activityView  startAnimating];
            self.activityView.hidden = NO;
            self.videoStatusLabel.hidden = YES;
            self.videoStatusLabel.text = @"加载中...";
            break;
            
        case MPMoviePlaybackStateSeekingForward:
            
            self.activityView.hidden = YES;
            self.videoStatusLabel.hidden = YES;
            break;
            
        case MPMoviePlaybackStateSeekingBackward:
            
            self.activityView.hidden = YES;
            self.videoStatusLabel.hidden = YES;
            break;
            
        default:
            break;
    }
}
# pragma mark -------视频播放状态-------
- (void)loadVideoStatusLabel
{
    self.activityView  = [[UIActivityIndicatorView alloc]initWithFrame:CGRectMake(self.overlayView.frame.size.width/2-40,self.overlayView.frame.size.height/2 - 40, 80, 80)];
    
    self.activityView.layer.cornerRadius = 5;
    self.activityView.layer.masksToBounds = YES;
    self.activityView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3];
    
    [self.overlayView addSubview:self.activityView];
    //菊花开始
    [self.activityView startAnimating];
    //菊花结束
    //    [activity stopAnimating];
    
    self.videoStatusLabel = [[UILabel alloc] init];
    self.videoStatusLabel.frame = CGRectMake(0,55,80, 20);
    self.videoStatusLabel.text = @"加载中...";
    self.videoStatusLabel.textColor = [UIColor whiteColor];
    self.videoStatusLabel.backgroundColor = [UIColor clearColor];
    self.videoStatusLabel.font = [UIFont systemFontOfSize:12];
    self.videoStatusLabel.textAlignment = NSTextAlignmentCenter;
    [self.activityView addSubview:self.videoStatusLabel];
}

# pragma mark -------退出时存储播放信息-------
-(void)saveNsUserDefaults
{
    //记录退出时播放信息
    NSTimeInterval time = self.player.currentPlaybackTime;
    long long dTime = [[NSNumber numberWithDouble:time] longLongValue];
    NSString *curTime = [NSString stringWithFormat:@"%llu",dTime];
    self.playPosition = [NSDictionary dictionaryWithObjectsAndKeys:curTime,@"playbackTime",nil];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (self.videoId) {
        //在线视频
        [userDefaults setObject:self.playPosition forKey:_videoId];
        
    } else if (self.videoLocalPath) {
        //本地视频
        [userDefaults setObject:self.playPosition forKey:_videoLocalPath];
    }
    //同步到磁盘
    [userDefaults synchronize];
    
    if (time == self.player.duration) {
        //视频结束进度清零
        if (self.videoId) {
            
            [[NSUserDefaults standardUserDefaults]removeObjectForKey:_videoId];
            
        }else if (self.videoLocalPath)
        {
            [[NSUserDefaults standardUserDefaults]removeObjectForKey:_videoLocalPath];
        }
        [[NSUserDefaults standardUserDefaults]synchronize];
    }
}

-(void)readNSUserDefaults
{
    if (self.videoId) {
        
        self.durationSlider.value = [lastStudyTime intValue]/1000;
        self.player.currentPlaybackTime = [lastStudyTime intValue];
        
    }else
    {
        self.durationSlider.value = [lastStudyTime intValue]/1000;
        self.player.currentPlaybackTime = [lastStudyTime floatValue];
    }
}

-(void)playFinsh
{
    NSDictionary *ret = @{@"btnType":@"4",@"ctime":@"0"};
    [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
}

# pragma mark-----timer--------
- (void)addTimer
{
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(timerHandler) userInfo:nil repeats:YES];
}

- (void)removeTimer
{
    if([self.timer isValid]){
        [self.timer invalidate];
    }
}

- (void)timerHandler
{
    if(!self.videoId){
        
        self.videoStatusLabel.hidden = YES;
    }
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
    self.currentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.currentPlaybackTimeLabel.text, [DWTools formatSecondsToString:self.player.duration]];
    self.durationSlider.value = self.player.currentPlaybackTime;
    
    self.passProgress = [NSString stringWithFormat:@"%f",self.player.currentPlaybackTime];
    
    self.historyPlaybackTime = self.player.currentPlaybackTime;
    if(self.isfirst && self.player.currentPlaybackTime > 0){
        
        self.isfirst = FALSE;
        if (_cbId >= 0){
            
            NSDictionary *ret = @{@"btnType":@"100",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
            [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
        }
    }
    if (!self.hiddenAll){
        
        if (self.hiddenDelaySeconds > 0) {
            
            if (self.hiddenDelaySeconds == 1) {
                [self hiddenAllView];
            }
            self.hiddenDelaySeconds--;
        }
    }
}

- (void)removeAllObserver
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)hiddenAllView
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.headerView.hidden = YES;
    self.footerView.hidden = YES;
    self.hiddenAll = YES;
    
    logdebug(@"videoStatusLabel showBasicViews-----%@",self.videoStatusLabel.hidden?@"YES":@"NO");
}

- (void)hiddenTableViews
{
    //    self.subtitleView.hidden = YES;
    //    self.screenSizeView.hidden = YES;
}

- (void)showBasicViews
{
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    self.headerView.hidden = NO;
    if(_isFullscreen){
        self.backButton.hidden = YES;
    }else{
        self.backButton.hidden = NO;
    }
    self.footerView.hidden = NO;
    self.hiddenAll = NO;
    logdebug(@"videoStatusLabel showBasicViews-----%@",self.videoStatusLabel.hidden?@"YES":@"NO");
}
@end
