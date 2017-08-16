//
//  LbbCCVideo.m
//  CCVideo
//
//  Created by 刘兵兵 on 17/4/20.
//  Copyright © 2017年 APICloud. All rights reserved.
//
#define DEBUG YES
#if DEBUG
#define logtrace() NSLog(@"%s():%d ", __func__, __LINE__)
#define logdebug(format, ...) NSLog(@"%s():%d "format, __func__, __LINE__, ##__VA_ARGS__)
#else
#define logdebug(format, ...)
#define logtrace()
#endif

#define loginfo(format, ...) NSLog(@"%s():%d "format, __func__, __LINE__, ##__VA_ARGS__)
#define logerror(format, ...) NSLog(@"%s():%d ERROR "format, __func__, __LINE__, ##__VA_ARGS__)

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVKit.h>

#import "LbbCCVideo.h"
#import "DWTools.h"
#import "UZAppDelegate.h"
#import "NSDictionaryUtils.h"
//#import "DWGestureButton.h"
#import "Reachability.h"
//#import "DWDownloaditem.h"

typedef NS_ENUM(NSInteger, ZXPanDirection){
    
    ZXPanDirectionHorizontal, // 横向移动
    ZXPanDirectionVertical,   // 纵向移动
};

typedef NSInteger DWPLayerScreenSizeMode;

@interface LbbCCVideo ()<UIGestureRecognizerDelegate,UIAlertViewDelegate>
{
    
    NSMutableArray *_signArray;
    
    NSInteger _cbId;
    NSInteger _downloadCbId;
    NSString  *title;
    NSString *userId;
    NSString *apiKey;
    float viewx;
    float viewy;
    float viewwidth;
    float viewheight;
    NSString *position;
    
    UIPanGestureRecognizer *tapPan;
    
    NSInteger count;
    NSString *viewName;
    BOOL fixed;
    BOOL autoPlay;
    BOOL cc;
}
@property (strong, nonatomic) UIAlertView *alert;
@property (strong, nonatomic) UILabel *tipLabel;
@property (assign, nonatomic) NSInteger tipHiddenSeconds;

@property (strong, nonatomic)UIView *headerView;
@property (strong, nonatomic)UIView *footerView;
@property (strong, nonatomic)UIActivityIndicatorView *activityView;//菊花x


@property (nonatomic, strong)UISlider *customVolumeSlider; // 用来接收系统音量条
@property (strong, nonatomic)UIView *overlayView;
@property (strong, nonatomic)UIView *videoBackgroundView;
@property (strong, nonatomic)UITapGestureRecognizer *signelTap;
@property (strong, nonatomic)UITapGestureRecognizer *doubleTap;//点击手势
@property (strong, nonatomic)UILabel *videoStatusLabel;
@property (strong, nonatomic)UIButton *lockButton;
@property (assign, nonatomic)BOOL isLock;
@property (strong, nonatomic)UIButton *BigPauseButton;

@property (strong, nonatomic)UIButton *backButton;

@property (assign, nonatomic)NSInteger currentSubtitleStatus;
@property (strong, nonatomic)UITapGestureRecognizer *restviewTap;

@property (strong, nonatomic)UIButton *switchScrBtn;
@property (assign, nonatomic)BOOL isFullscreen;
@property (assign, nonatomic)NSTimeInterval switchTime;
@property (strong, nonatomic)UIButton *playbackButton;
@property (assign, nonatomic)BOOL pausebuttonClick;
@property (strong, nonatomic)UISlider *durationSlider;
@property (strong, nonatomic)UILabel *currentPlaybackTimeLabel;
@property (strong, nonatomic)UILabel *durationLabel;

@property (strong, nonatomic)DWMoviePlayerController  *player;
@property (strong, nonatomic)NSDictionary *playUrls;
@property (strong, nonatomic)NSDictionary *currentPlayUrl;
@property (assign, nonatomic)NSTimeInterval historyPlaybackTime;

@property (strong, nonatomic)NSTimer *timer;
@property (strong, nonatomic)NSTimer *downloadTimer;
@property (assign, nonatomic)BOOL hiddenAll;
@property (assign, nonatomic)NSInteger hiddenDelaySeconds;
@property(nonatomic,strong)NSDictionary *playPosition;

@property (strong, nonatomic)UIImageView *materialView;
@property (strong, nonatomic)UIImage *materialImg;
@property (retain, nonatomic)UILabel *timeLabel;
@property (assign, nonatomic)NSInteger secondsCountDown;
@property (strong, nonatomic)NSTimer *countDownTimer;

@property (nonatomic) Reachability *internetReachability;


@property (nonatomic, assign)ZXPanDirection panDirection;// pan手势移动方向
@property (nonatomic, assign)CGFloat sumTime;// 快进退的总时长
@property (nonatomic, assign)BOOL isVolumeAdjust;// 是否在调节音量

@end

//static DWDownloadItems *downloadFinishItems;
//static DWDownloadItems *downloadingItems;

//实现
@implementation LbbCCVideo
+ (void)launch {
    [DOWNLOADMANAGER loadDownloadItems];
}
//初始化
- (id)initWithUZWebView:(UZWebView *)webView_ {
    
    if (self = [super initWithUZWebView:webView_]){
        count = 0;
        NSDictionary *feature = [self getFeatureByName:@"ccVideo"];
        userId = [feature stringValueForKey:@"userId" defaultValue:nil];
        apiKey = [feature stringValueForKey:@"apiKey" defaultValue:nil];
        [self addObserverForMPMoviePlayController];
        [self addTimer];
    }
    return self;
}
- (void) dispose {
    //do clean
    [self closeVideo];//关闭视频
    
    [self downloadRemoveTimer];
    
    [self saveDownloadItems];
    //self.viewController.didReceiveMemoryWarning();
}

//打开视频界面
- (void)open:(NSDictionary *)paramDict{
    
    _cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    
    
    userId = [paramDict stringValueForKey:@"userId" defaultValue:nil];
    apiKey = [paramDict stringValueForKey:@"apiKey" defaultValue:nil];
    if(self.player != nil){
        [self closeVideo];
    }
    NSDictionary *feature = [self getFeatureByName:@"ccVideo"];
    if(userId == nil){
        userId = [feature stringValueForKey:@"userId" defaultValue:nil];
        apiKey = [feature stringValueForKey:@"apiKey" defaultValue:nil];
    }
    self.videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];//视频id
    //是否背地
    BOOL isLocalPlay = [paramDict boolValueForKey:@"isLocalPlay" defaultValue:NO];
    
    if (isLocalPlay) {
        NSFileManager *fileMgr = [NSFileManager defaultManager];
        NSArray *paths =  NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = [paths objectAtIndex:0];
        NSString *videoPath;
        videoPath = [NSString stringWithFormat:@"%@/%@.mp4", cacheDirectory, self.videoId];
        BOOL bRet = [fileMgr fileExistsAtPath:videoPath];
        if (bRet) {
            self.videoId = nil;
            self.videoLocalPath = videoPath;
        }else{
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStateChange) name:kReachabilityChangedNotification object:nil];
        }
    }else{
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStateChange) name:kReachabilityChangedNotification object:nil];
    }
    
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
    viewwidth = [paramDict floatValueForKey:@"w" defaultValue:mainScreenWidth];
    viewheight = [paramDict floatValueForKey:@"h" defaultValue:mainScreenHeight-viewy];
    
    title = [paramDict stringValueForKey:@"title" defaultValue:nil];//视频标题
    
    
    //self.localoVideoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];//视频id
    //self.videoLocalPath = [paramDict stringValueForKey:@"videoLocalPath" defaultValue:nil];//视频本地地址
    
    viewName = [paramDict stringValueForKey:@"fixedOn" defaultValue:nil];
    fixed = [paramDict boolValueForKey:@"fixed" defaultValue:YES];
    autoPlay  = [paramDict boolValueForKey:@"autoPlay" defaultValue:YES];
    
    _signArray = [NSMutableArray new];
    for (int i=0; i<4; i++) {
        [_signArray addObject:@"0"];
    }
    
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    //if ([_internetReachability currentReachabilityStatus] == ReachableViaWWAN) {
        //self.alert = [[UIAlertView alloc]initWithTitle:@"当前为移动网络，是否继续播放？" message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
        //[self.alert show];
    //}
    //隐藏 状态栏
    [self.viewController.navigationController setNavigationBarHidden:YES animated:NO];
    
    //[[NSNotificationCenter defaultCenter] addObserver:self
    //                                         selector:@selector(onDeviceOrientationChange)
    //                                             name:UIDeviceOrientationDidChangeNotification
    //                                           object:nil
    //];
    self.viewController.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    // 加载播放器 必须第一个加载
    [self loadPlayer];
    // 初始化播放器覆盖视图，它作为所有空间的父视图。
    self.overlayView = [[UIView alloc] initWithFrame:CGRectMake(viewx, viewy, viewwidth,viewheight)];//[[DWGestureView alloc] initWithFrame:self.view.bounds];
    self.overlayView.backgroundColor = [UIColor clearColor];
    //快进，快退
    [self.overlayView addSubview:self.timeIndicatorView];
    // 音量指示器
    [self.overlayView addSubview:self.volumeIndicatorView];
    //亮度
    [self.overlayView addSubview:self.brightnessIndicatorView];
    //左右滑动快进
    tapPan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panDirection:)];
    tapPan.delegate = self;
    
    // 初始化子视图
    [self loadFooterView];
    [self loadHeaderView];
    [self loadVolumeView];
    
    self.videoStatusLabel = [[UILabel alloc] init];
    self.tipLabel = [[UILabel alloc]init];
    [self onDeviceOrientationChange];
    
    self.signelTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSignelTap:)];
    self.signelTap.numberOfTapsRequired = 1;
    self.signelTap.delegate = self;
    [self.overlayView addGestureRecognizer:self.signelTap];
    
    self.doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    [self.doubleTap setNumberOfTapsRequired:2];
    [self.overlayView addGestureRecognizer:self.doubleTap];
    [self.signelTap requireGestureRecognizerToFail:self.doubleTap];
    
    //是否cc视频播放
    cc = [paramDict boolValueForKey:@"cc" defaultValue:YES];
    if(!cc){
        //self.currentPlayUrl = self.videoId;
    }
    
    
    BOOL fullscreen = [paramDict boolValueForKey:@"fullscreen" defaultValue:NO];
    position = [paramDict stringValueForKey:@"position" defaultValue:nil];
    if (self.videoId) {
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
    if(position !=nil ){
        self.player.seekStartTime = [position intValue]/1000;
    }
    // 10 秒后隐藏所有窗口·
    self.hiddenDelaySeconds = 10;
    if(fullscreen){
        self.switchScrBtn.selected = YES;
        [self FullScreenFrameChanges];
        [self evalJs:@"api.setScreenOrientation({orientation: 'landscape_right'});"];
        self.isFullscreen = YES;
    }
    if(_cbId>0){
         NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [sendDict setObject:[NSNumber numberWithInteger:1] forKey:@"status"];
        [self sendResultEventWithCallbackId:_cbId dataDict:sendDict errDict:nil doDelete:NO];
    }
}
- (void)closeVideo {
    if(!self.player){
        return;
    }
    if(self.videoId){
        [self.player cancelRequestPlayInfo];
    }
    [self saveNsUserDefaults];
    [self.player stop];
    self.secondsCountDown = -1;
    self.player.contentURL = nil;
    self.player = nil;
    [self removeAllObserver];
    [self removeTimer];
    // 显示 状态栏  quanping
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [self.videoBackgroundView removeFromSuperview];
    [self.overlayView removeFromSuperview];
}
- (void)callback:(NSInteger)cbId userEvent:(NSString *)userEvent doDelete:(BOOL)del {
    NSString *currentPosition = @"0";
    NSString *duration = @"0";
    if(self.player != nil){
        currentPosition = [NSString stringWithFormat:@"%0.f",self.player.currentPlaybackTime*1000];
        duration = [NSString stringWithFormat:@"%0.f",self.player.duration*1000];
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [sendDict setObject:[NSNumber numberWithInteger:1] forKey:@"status"];
    [sendDict setObject:currentPosition forKey:@"currentPosition"];
    [sendDict setObject:duration forKey:@"duration"];
    if(userEvent != nil){
        [sendDict setObject:userEvent forKey:@"USER_EVENT"];
    }
    [self sendResultEventWithCallbackId:cbId dataDict:sendDict errDict:nil doDelete:del];
}

//关闭播放器
- (void)close:(NSDictionary *)paramDict{
    [self closeVideo];
    //[self.navigationController popViewControllerAnimated:YES];
}

//开始播放
- (void)start:(NSDictionary *)paramDict{
    
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    self.hiddenDelaySeconds = 10;
    
    if (self.videoId !=nil && (!self.playUrls || self.playUrls.count == 0)) {
        [self loadPlayUrls];
        return;
    }
    
    UIImage *image = nil;
    if (self.player.playbackState != MPMoviePlaybackStatePlaying) {
        // 继续播放
        self.pausebuttonClick = NO;
        self.BigPauseButton.hidden = YES;
        image = [UIImage imageNamed:@"res_ccVideo/player-pausebutton"];
        [self.player play];
        [self.materialView setHidden:YES];
        [self.playbackButton setImage:image forState:UIControlStateNormal];
    }
    if (cbId >= 0) {
        [self callback:cbId userEvent:nil doDelete:YES];
    }
}

//暂停播放
- (void)stop:(NSDictionary *)paramDict{
    
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    self.hiddenDelaySeconds = 10;
    
    if (self.videoId !=nil && (!self.playUrls || self.playUrls.count == 0)) {
        [self loadPlayUrls];
        return;
    }
    UIImage *image = nil;
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        // 暂停播放
        self.pausebuttonClick = YES;
        image = [UIImage imageNamed:@"res_ccVideo/player-playbutton"];
        [self.player pause];
        [self loadBigPauseButton];
        [self.playbackButton setImage:image forState:UIControlStateNormal];
    }
    if (cbId >= 0) {
        [self callback:cbId userEvent:nil doDelete:YES];
    }
}
//取消全屏
- (void)back:(NSDictionary *)paramDict{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    if (self.isFullscreen == YES) {
        [self SmallScreenFrameChanges];
        self.isFullscreen = NO;
    }
    if (cbId >= 0) {
        [self callback:cbId userEvent:nil doDelete:YES];
    }
}
//跳到指定位置播放
- (void)seekTo:(NSDictionary *)paramDict{
    NSInteger  position1 = [paramDict integerValueForKey:@"position" defaultValue:0];
    if(position1 >= 0 && position1/1000 <= self.player.duration){
        self.player.currentPlaybackTime = position1/1000;
        self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
        self.durationLabel.text = [DWTools formatSecondsToString:self.player.duration];
        self.durationSlider.value = self.player.currentPlaybackTime;
        self.historyPlaybackTime = self.player.currentPlaybackTime;
    }
}

- (void)getCurrentPosition:(NSDictionary *)paramDict{
     NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    [self callback:cbId userEvent:nil doDelete:YES];
}

//lbbniu
/*- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForegroundNotification) name:UIApplicationWillEnterForegroundNotification object:nil];
}
//生命周期函数
- (void)appWillEnterForegroundNotification{
    if (self.player.playbackState == MPMoviePlaybackStatePaused) {
        [self.player play];
    }
}
//生命周期函数
- (void)viewWillDisappear:(BOOL)animated
{
    //logdebug(@"stop movie");
    [self.player cancelRequestPlayInfo];
    [self saveNsUserDefaults];
    self.player.currentPlaybackTime = self.player.duration;
    [self.player stop];
    self.secondsCountDown = -1;
    self.player.contentURL = nil;
    self.player = nil;
    [self removeAllObserver];
    [self removeTimer];
    
    // 显示 状态栏
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    // 显示 navigationController
    [self.viewController.navigationController setNavigationBarHidden:NO animated:YES];
}
*/

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
                    [self callback:_cbId userEvent:nil doDelete:NO];
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
    
    //double minutesRemaining = floor(totalTime / 60.0);
    //double secondsRemaining = floor(fmod(totalTime, 60.0));
    //NSString *timeRmainingString = [NSString stringWithFormat:@"%02.0f:%02.0f", minutesRemaining, secondsRemaining];
    
    self.currentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@",timeElapsedString];
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

# pragma mark 处理网络状态改变

- (void)networkStateChange
{
    NetworkStatus status = [_internetReachability currentReachabilityStatus];
    switch (status) {
        case NotReachable:
            NSLog(@"没有网络");
            [self loadTipLabelview];
            self.tipLabel.text = @"当前无任何网络";
            self.tipHiddenSeconds = 2;
            break;
            
        case ReachableViaWiFi:
            NSLog(@"Wi-Fi");
            [self loadTipLabelview];
            self.tipLabel.text = @"切换到wi-fi网络";
            self.tipHiddenSeconds = 2;
            break;
            
        case ReachableViaWWAN:
            NSLog(@"运营商网络");
            [self.player pause];
            self.alert = [[UIAlertView alloc]initWithTitle:@"当前为移动网络，是否继续播放？" message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
            [self.alert show];
            break;
            
        default:
            break;
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
        //[self.viewController.navigationController popViewControllerAnimated:YES];
    }
    if (buttonIndex == 1) {
        [self.player play];
    }
}

- (void)timeFireMethod
{
    _timeLabel.text = [NSString stringWithFormat:@"%lds",(long)_secondsCountDown];
    _secondsCountDown--;
    if(_secondsCountDown==-1){
        [_countDownTimer invalidate];
        _countDownTimer = nil;
        self.player.contentURL = nil;
        //_adPlay = NO;
        [self loadPlayUrls];
        NSLog(@"计时器销毁");
        //[self.adView setHidden:YES];
        [self.overlayView setHidden:NO];
    }
}

# pragma mark - 加载播放器
- (void)loadPlayer{
    self.videoBackgroundView = [[UIView alloc] init];
    self.videoBackgroundView.backgroundColor = [UIColor blackColor];
    
    [self addSubview:self.videoBackgroundView fixedOn:viewName fixed:fixed];
}

# pragma mark - headerView
- (void)loadHeaderView
{
    self.headerView = [[UIView alloc]init];
    
    self.headerView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.2];
    
    [self.overlayView addSubview:self.headerView];
    logdebug(@"headerView frame: %@", NSStringFromCGRect(self.headerView.frame));
    
    // 返回按钮及视频标题
    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
}
-(void)handleRestviewTap:(UIGestureRecognizer*)gestureRecognizer{
    [self showBasicViews];
    [self.overlayView addGestureRecognizer:self.signelTap];
    
}

# pragma mark 返回按钮及视频标题
- (void)loadBackButton
{
    CGRect frame;
    frame.origin.x = 16;
    frame.origin.y = self.headerView.frame.origin.y + 4;
    frame.size.width = 100;
    frame.size.height = 30;
    self.backButton.frame = frame;
    
    self.backButton.backgroundColor = [UIColor clearColor];
    [self.backButton setTitle:title forState:UIControlStateNormal];
    [self.backButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.backButton setImage:[UIImage imageNamed:@"res_ccVideo/player-back-button"] forState:UIControlStateNormal];
    self.backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.backButton addTarget:self action:@selector(backButtonAction:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.backButton];
}

- (void)backButtonAction:(UIButton *)button
{
    if (self.isFullscreen == YES) {
        [self callback:_cbId userEvent:@"ON_QUIT_FULLSCREEN" doDelete:NO];
        [self SmallScreenFrameChanges];
        self.isFullscreen = NO;
    }else{
        //关闭视频
        [self.viewController.navigationController popViewControllerAnimated:YES];
    }
}

- (CGRect)getScreentSizeWithRefrenceFrame:(CGRect)frame andScaling:(float)scaling
{
    if (scaling == 1) {
        return frame;
    }
    
    NSInteger n = 1/(1 - scaling);
    frame.origin.x += roundf(frame.size.width/n/2);
    frame.origin.y += roundf(frame.size.height/n/2);
    frame.size.width -= roundf(frame.size.width/n);
    frame.size.height -= roundf(frame.size.height/n);
    
    return frame;
}
# pragma mark - footerView

- (void)loadFooterView
{
    self.footerView = [[UIView alloc]init];
    self.footerView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.2];
    [self.overlayView addSubview:self.footerView];
    logdebug(@"footerView: %@", NSStringFromCGRect(self.footerView.frame));
    
    // 播放按钮
    self.playbackButton = [UIButton buttonWithType:UIButtonTypeCustom];
    // 当前播放时间
    self.currentPlaybackTimeLabel = [[UILabel alloc] init];
    
    // 视频总时间
    self.durationLabel = [[UILabel alloc] init];
    
    // 时间滑动条
    self.durationSlider = [[UISlider alloc] init];
    [self durationSlidersetting];
    
    //切换屏幕按钮
    self.switchScrBtn = [UIButton buttonWithType:UIButtonTypeCustom];
}
# pragma mark 屏幕翻转
-(void)loadSwitchScrBtn
{
    CGRect frame;
    
    frame.origin.x = self.footerView.frame.size.width - 40;
    frame.origin.y = self.footerView.frame.origin.y;
    frame.size.width = 38;
    frame.size.height = 38;
    
    
    self.switchScrBtn.frame = frame;
    self.switchScrBtn.backgroundColor = [UIColor clearColor];
    self.switchScrBtn.showsTouchWhenHighlighted = YES;
    [self.switchScrBtn setImage:[UIImage imageNamed:@"res_ccVideo/fullscreen.png"] forState:UIControlStateNormal];
    [self.switchScrBtn setImage:[UIImage imageNamed:@"res_ccVideo/nonfullscreen.png"] forState:UIControlStateSelected];
    [self.switchScrBtn addTarget:self action:@selector(switchScreenAction:)
                forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.switchScrBtn];
    logdebug(@"self.switchScrBtn.frame: %@", NSStringFromCGRect(self.switchScrBtn.frame));
    
}

-(void)switchScreenAction:(UIButton *)button
{
    self.switchScrBtn.selected = !self.switchScrBtn.selected;
    
    if (self.switchScrBtn.selected == YES) {
        [self callback:_cbId userEvent:@"ON_ENTER_FULLSCREEN" doDelete:NO];
        [self FullScreenFrameChanges];
        //[[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationLandscapeLeft] forKey:@"orientation"];
        [self evalJs:@"api.setScreenOrientation({orientation: 'landscape_left'});"];
        self.isFullscreen = YES;
        NSLog(@"点击按钮 to Full");
    }
    else{
        [self callback:_cbId userEvent:@"ON_QUIT_FULLSCREEN" doDelete:NO];
        [self SmallScreenFrameChanges];
        self.isFullscreen = NO;
        NSLog(@"点击按钮 to Small");
    }
}

-(void)SmallScreenFrameChanges{
    if (self.isFullscreen == YES) {
        [self evalJs:@"api.setScreenOrientation({orientation: 'portrait_up'});"];
    }
    self.isFullscreen = NO;
    
    [self.videoBackgroundView removeFromSuperview];
    [self.overlayView removeFromSuperview];
    [self.player.view removeFromSuperview];
    [self.lockButton removeFromSuperview];
    [self.BigPauseButton removeFromSuperview];
    

    //self.viewController.view.transform = CGAffineTransformIdentity;
    self.overlayView.transform =CGAffineTransformIdentity;
    //[[UIDevice currentDevice] setValue:[NSNumber numberWithInteger:UIDeviceOrientationPortrait] forKey:@"orientation"];
    [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait animated:YES];
    
    self.overlayView.backgroundColor = [UIColor clearColor];
    self.overlayView.frame = CGRectMake(viewx, viewy, viewwidth, viewheight);
    
    
    self.videoBackgroundView.frame = CGRectMake(viewx, viewy, viewwidth, viewheight);
    self.videoBackgroundView.backgroundColor = [UIColor blackColor];
    [self addSubview:self.videoBackgroundView fixedOn:viewName fixed:fixed];
    
   
    
    self.player.scalingMode = MPMovieScalingModeAspectFit;
    self.player.controlStyle = MPMovieControlStyleNone;
    self.player.view.backgroundColor = [UIColor clearColor];
    self.player.view.frame = CGRectMake(0, 0, viewwidth, viewheight);
    [self.videoBackgroundView addSubview:self.player.view];

    
    [self addSubview:self.overlayView fixedOn:viewName fixed:fixed];
    
    self.headerView.frame = CGRectMake(0, 0, self.overlayView.frame.size.width, 38);
    self.footerView.frame = CGRectMake(0, self.overlayView.frame.size.height - 38, self.overlayView.frame.size.width, 38);
    self.switchScrBtn.selected = NO;
    [self headerViewframe];
    [self footerViewframe];
    [self loadVideoStatusLabel];
    if (_pausebuttonClick) {
        [self loadBigPauseButton];
    }
    [self showBasicViews];
    self.hiddenDelaySeconds = 10;
    self.timeIndicatorView.frame = CGRectMake(self.overlayView.frame.size.width/2 -60, self.overlayView.frame.size.height/2 - 60, kVideoTimeIndicatorViewSide, kVideoTimeIndicatorViewSide);
    self.brightnessIndicatorView.frame =CGRectMake(self.overlayView.frame.size.width/2 -60, self.overlayView.frame.size.height/2 - 60, kVideoTimeIndicatorViewSide, kVideoTimeIndicatorViewSide);
}

-(void)toFullScreenWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    [self FullScreenFrameChanges];
}

-(void)FullScreenFrameChanges{
    self.isFullscreen = YES;
    
    [self.videoBackgroundView removeFromSuperview];
    [self.overlayView removeFromSuperview];
    [self.player.view removeFromSuperview];
    [self.BigPauseButton removeFromSuperview];
    
    
    //self.uzWebView.transform = CGAffineTransformIdentity;
    //self.overlayView.transform = CGAffineTransformIdentity;
    
    CGFloat max = MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    CGFloat min = MIN([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    self.overlayView.backgroundColor = [UIColor clearColor];
    self.overlayView.frame = CGRectMake(0, 20, max, min-20);

    
    
    self.videoBackgroundView.backgroundColor = [UIColor blackColor];
    self.videoBackgroundView.frame = CGRectMake(0, 0, max, min);

    [self addSubview:self.videoBackgroundView fixedOn:nil fixed:YES];
    
    self.player.scalingMode = MPMovieScalingModeAspectFit;
    self.player.controlStyle = MPMovieControlStyleNone;
    self.player.view.backgroundColor = [UIColor clearColor];
    self.player.view.frame = CGRectMake(0, 0, max, min);
    [self.videoBackgroundView addSubview:self.player.view];
    
    
    
    self.headerView.frame = CGRectMake(0, 0, self.overlayView.frame.size.width, 38);
    //self.footerView.frame = CGRectMake(0, self.overlayView.frame.size.height - 60, self.overlayView.frame.size.width, 60);
    self.footerView.frame = CGRectMake(0, self.overlayView.frame.size.height - 38, self.overlayView.frame.size.width, 38);
    self.switchScrBtn.selected = YES;
    [self headerViewframe];
    [self footerViewframe];
    [self loadLockButton];
    [self loadVideoStatusLabel];
    if (_pausebuttonClick) {
        [self loadBigPauseButton];
    }
    
    [self addSubview:self.overlayView fixedOn:nil fixed:YES];
    
    [self showBasicViews];
    self.hiddenDelaySeconds = 10;
    
    self.timeIndicatorView.frame = CGRectMake(self.overlayView.frame.size.width/2 -60, self.overlayView.frame.size.height/2 - 60, kVideoTimeIndicatorViewSide, kVideoTimeIndicatorViewSide);
    self.brightnessIndicatorView.frame =CGRectMake(self.overlayView.frame.size.width/2 -60, self.overlayView.frame.size.height/2 - 60, kVideoTimeIndicatorViewSide, kVideoTimeIndicatorViewSide);
}
-(void)footerViewframe
{
    [self loadPlaybackButton];
    [self loadCurrentPlaybackTimeLabel];
    [self loadPlaybackSlider];
    [self loadDurationLabel];
    [self loadSwitchScrBtn];
    if (self.isFullscreen == YES) {

    }
}

-(void)headerViewframe
{
    [self loadBackButton];
}
//隐藏状态栏
- (BOOL)prefersStatusBarHidden{
    return YES;
}
/**
 *  旋转屏幕通知
 */

- (void)onDeviceOrientationChange{
    if (self.player==nil){
        return;
    }
    
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation interfaceOrientation = (UIInterfaceOrientation)orientation;
    switch (interfaceOrientation) {
        case UIInterfaceOrientationUnknown:{
            NSLog(@"旋转方向未知");
            [self SmallScreenFrameChanges];
        }
            break;
        case UIInterfaceOrientationPortrait:{
            NSLog(@"第0个旋转方向---电池栏在上");
            //if (self.isFullscreen == YES) {
                [self SmallScreenFrameChanges];
            //}
        }
            break;
        case UIInterfaceOrientationLandscapeLeft:{
            NSLog(@"第2个旋转方向---电池栏在左");
            if (self.isFullscreen == NO) {
                [self toFullScreenWithInterfaceOrientation:interfaceOrientation];
            }
        }
            break;
        case UIInterfaceOrientationLandscapeRight:{
            NSLog(@"第1个旋转方向---电池栏在右");
            if (self.isFullscreen == NO) {
                [self toFullScreenWithInterfaceOrientation:interfaceOrientation];
            }
        }
            break;
        default:
            //设备平躺条件下进入播放界面
            if (self.isFullscreen == NO) {
                [self SmallScreenFrameChanges];
            }
            break;
    }
}

# pragma mark 播放按钮
- (void)loadPlaybackButton
{
    CGRect frame = CGRectZero;
    frame.origin.x = self.footerView.frame.origin.x + 5;
    frame.origin.y = self.footerView.frame.origin.y + self.footerView.frame.size.height / 2 - 15;
    frame.size.width = 30;
    frame.size.height = 30;
    self.playbackButton.frame = frame;
    [self.playbackButton setImage:[UIImage imageNamed:@"res_ccVideo/player-pausebutton"] forState:UIControlStateNormal];
    [self.playbackButton addTarget:self action:@selector(playbackButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.playbackButton];
}

- (void)playbackButtonAction:(UIButton *)button
{
    self.hiddenDelaySeconds = 10;
    
    if (!self.playUrls || self.playUrls.count == 0) {
        [self loadPlayUrls];
        return;
    }
    
    UIImage *image = nil;
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        // 暂停播放
        self.pausebuttonClick = YES;
        image = [UIImage imageNamed:@"res_ccVideo/player-playbutton"];
        [self.player pause];
        [self loadBigPauseButton];
        [self callback:_cbId userEvent:@"ON_CLICK_PAUSE" doDelete:NO];
    } else {
        // 继续播放
        self.pausebuttonClick = NO;
        self.BigPauseButton.hidden = YES;
        image = [UIImage imageNamed:@"res_ccVideo/player-pausebutton"];
        [self.player play];
        [self.materialView setHidden:YES];
        [self callback:_cbId userEvent:@"ON_CLICK_RESUME" doDelete:NO];
    }
    [self.playbackButton setImage:image forState:UIControlStateNormal];
}

- (void)switchQuality:(NSInteger)index
{
    if(cc){
        self.switchTime = self.player.currentPlaybackTime;
        NSInteger currentQualityIndex =  [[self.playUrls objectForKey:@"qualities"] indexOfObject:self.currentPlayUrl];
        
        NSDictionary *currentUrl = [[self.playUrls objectForKey:@"qualities"] objectAtIndex:0];
        self.player.sourceURL = [NSURL URLWithString:[currentUrl objectForKey:@"playurl"]];
        
        logdebug(@"index: %ld %ld", (long)index, (long)currentQualityIndex);
        if (index == currentQualityIndex) {
            //不需要切换
            logdebug(@"current quality: %ld %@", (long)currentQualityIndex, self.currentPlayUrl);
            return;
        }
        loginfo(@"switch %@ -> %@", self.currentPlayUrl, [[self.playUrls objectForKey:@"qualities"] objectAtIndex:index]);
        
        self.currentPlayUrl = [[self.playUrls objectForKey:@"qualities"] objectAtIndex:index];
        self.player.contentURL = [NSURL URLWithString:[self.currentPlayUrl objectForKey:@"playurl"]];
        if(cc && self.videoLocalPath == nil)
            [self.player swith_quality];
    }else{
        self.player.contentURL = [NSURL URLWithString:self.videoId];;//[[NSURL alloc] initFileURLWithPath:self.videoLocalPath];
    }
    
    
    [self resetPlayer];
}

# pragma mark 当前播放时间
- (void)loadCurrentPlaybackTimeLabel
{//视频当前播放时间
    CGRect frame = CGRectZero;
    
    frame.origin.x = self.playbackButton.frame.origin.x + self.playbackButton.frame.size.width + 5;
    frame.origin.y = self.playbackButton.frame.origin.y + 5;
    frame.size.width = 40;
    frame.size.height = 20;
    
    self.currentPlaybackTimeLabel.frame = frame;
    self.currentPlaybackTimeLabel.text = @"00:00";
    self.currentPlaybackTimeLabel.textColor = [UIColor whiteColor];
    self.currentPlaybackTimeLabel.font = [UIFont systemFontOfSize:8];
    self.currentPlaybackTimeLabel.backgroundColor = [UIColor clearColor];
    [self.overlayView addSubview:self.currentPlaybackTimeLabel];
    //logdebug(@"currentPlaybackTimeLabel frame: %@", NSStringFromCGRect(self.currentPlaybackTimeLabel.frame));
}

# pragma mark 视频总时间
- (void)loadDurationLabel
{
    //视频总时间label
    CGRect frame = CGRectZero;
    frame.origin.x = self.durationSlider.frame.origin.x + self.durationSlider.frame.size.width + 5;
    frame.origin.y = self.playbackButton.frame.origin.y + 5;
    frame.size.width = 40;
    frame.size.height = 20;
    
    self.durationLabel.frame = frame;
    self.durationLabel.text = @"00:00";
    self.durationLabel.textColor = [UIColor whiteColor];
    self.durationLabel.backgroundColor = [UIColor clearColor];
    self.durationLabel.font = [UIFont systemFontOfSize:8];
    
    [self.overlayView addSubview:self.durationLabel];
}

# pragma mark 时间滑动条
- (void)loadPlaybackSlider
{
    CGRect frame = CGRectZero;
    frame.origin.x = self.currentPlaybackTimeLabel.frame.origin.x + self.currentPlaybackTimeLabel.frame.size.width ;
    frame.origin.y = self.playbackButton.frame.origin.y;
    frame.size.width = self.footerView.frame.size.width - 60 - 100;
    frame.size.height = 30;
    
    self.durationSlider.frame =frame;
    
    [self.overlayView addSubview:self.durationSlider];
    logdebug(@"self.durationSlider.frame: %@", NSStringFromCGRect(self.durationSlider.frame));
    
}
-(void)durationSlidersetting
{
    self.durationSlider.minimumValue = 0.0f;
    self.durationSlider.maximumValue = 1.0f;
    self.durationSlider.value = 0.0f;
    self.durationSlider.continuous = NO;
    [self.durationSlider setMaximumTrackImage:[UIImage imageNamed:@"res_ccVideo/player-slider-inactive"]
                                     forState:UIControlStateNormal];
    [self.durationSlider setMinimumTrackImage:[UIImage imageNamed:@"res_ccVideo/slider"]
                                     forState:UIControlStateNormal];
    [self.durationSlider setThumbImage:[UIImage imageNamed:@"res_ccVideo/player-slider-handle"]
                              forState:UIControlStateNormal];
    [self.durationSlider addTarget:self action:@selector(durationSliderMoving:) forControlEvents:UIControlEventValueChanged];
    [self.durationSlider addTarget:self action:@selector(durationSliderDone:) forControlEvents:UIControlEventTouchUpInside];
}
- (void)durationSliderMoving:(UISlider *)slider
{
    logdebug(@"self.durationSlider.value: %ld", (long)slider.value);
    
    self.player.seekStartTime = self.player.currentPlaybackTime;
    self.player.currentPlaybackTime = slider.value;
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
    self.historyPlaybackTime = self.player.currentPlaybackTime;
}
- (void)durationSliderDone:(UISlider *)slider
{
    logdebug(@"slider touch");
    
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
    self.historyPlaybackTime = self.player.currentPlaybackTime;
    
    if (self.player.playbackState == MPMoviePlaybackStatePaused) {
        self.player.playaction = @"unbuffereddrag";
    }
    else{
        self.player.playaction = @"buffereddrag";
    }
    
    if(cc && self.videoLocalPath == nil){
        [self.player drag_action];
        [self.player play_action];
    }
    
}
# pragma mark - 其它控件

# pragma mark 屏幕锁
-(void)loadLockButton
{
    if (!self.lockButton) {
        self.lockButton = [UIButton buttonWithType:UIButtonTypeCustom];
    }
    CGRect frame = CGRectZero;
    frame.origin.x = 20;
    frame.origin.y = self.overlayView.frame.size.height/2 - 20;
    frame.size.width = 40;
    frame.size.height = 40;
    
    self.lockButton.frame = frame;
    self.lockButton.backgroundColor = [UIColor clearColor];
    [self.lockButton setImage:[UIImage imageNamed:@"res_ccVideo/unlock_ic"] forState:UIControlStateNormal];
    [self.lockButton setImage:[UIImage imageNamed:@"res_ccVideo/lock_ic"] forState:UIControlStateSelected];
    [self.lockButton addTarget:self action:@selector(lockScreenAction:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.lockButton];
    
}
-(void)lockScreenAction:(UIButton *)button
{
    self.lockButton.selected = !self.lockButton.selected;
    
    if (self.lockButton.selected == YES) {
        self.isLock = YES;
        [self hiddenAllView];
        [self loadTipLabelview];
        self.tipLabel.text = @"屏幕已锁定";
        self.tipHiddenSeconds = 2;
    }
    else{
        [self showBasicViews];
        self.isLock = NO;
        [self loadTipLabelview];
        self.tipLabel.text = @"屏幕已解锁";
        self.tipHiddenSeconds = 2;
    }
}

# pragma mark 播放状态提示
- (void)loadVideoStatusLabel
{
    CGRect frame = CGRectZero;
    frame.size.height = 40;
    frame.size.width = 100;
    frame.origin.x = self.overlayView.frame.size.width/2 - frame.size.width/2;
    frame.origin.y = self.overlayView.frame.size.height/2 - frame.size.height/2;
    
    self.videoStatusLabel.frame = frame;
    if (self.pausebuttonClick) {
        self.videoStatusLabel.text = @"暂停";
    }else{
        self.videoStatusLabel.text = @"正在加载";
    }
    self.videoStatusLabel.textAlignment = UITextAlignmentCenter;
    self.videoStatusLabel.textColor = [UIColor whiteColor];
    self.videoStatusLabel.backgroundColor = [UIColor clearColor];
    self.videoStatusLabel.font = [UIFont systemFontOfSize:16];
    [self.overlayView addSubview:self.videoStatusLabel];
}
-(void)loadBigPauseButton
{
    CGRect frame = CGRectZero;
    frame.size.height =  80;
    frame.size.width = 80;
    frame.origin.x = self.overlayView.frame.size.width/2 - frame.size.width/2;
    frame.origin.y = self.overlayView.frame.size.height/2 - frame.size.height/2;
    if (!self.BigPauseButton) {
        self.BigPauseButton = [[UIButton alloc]init];
    }
    self.BigPauseButton.frame = frame;
    [self.BigPauseButton setImage:[UIImage imageNamed:@"res_ccVideo/big_stop_ic"] forState:UIControlStateNormal];
    [self.BigPauseButton addTarget:self action:@selector(playbackButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    self.BigPauseButton.hidden = NO;
    [self.overlayView addSubview:self.BigPauseButton];
}
-(void)loadTipLabelview
{
    CGRect frame = CGRectZero;
    frame.size.height = 40;
    frame.size.width = 100;
    frame.origin.x = self.overlayView.frame.size.width/2 - frame.size.width/2;
    frame.origin.y = self.overlayView.frame.size.height/2 - frame.size.height/2 + 30;
    
    self.tipLabel.frame = frame;
    self.tipLabel.textAlignment = UITextAlignmentCenter;
    self.tipLabel.adjustsFontSizeToFitWidth = YES;
    self.tipLabel.textColor = [UIColor whiteColor];
    self.tipLabel.backgroundColor = [UIColor clearColor];
    self.tipLabel.hidden = NO;
    [self.overlayView addSubview:self.tipLabel];
}
#pragma mark - 控件隐藏 & 显示
- (void)hiddenAllView
{
    if(self.isFullscreen){
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
    }
    self.backButton.hidden = YES;

    self.playbackButton.hidden = YES;
    self.currentPlaybackTimeLabel.hidden = YES;
    self.durationLabel.hidden = YES;
    self.durationSlider.hidden = YES;
    self.switchScrBtn.hidden = YES;
    self.headerView.hidden = YES;
    self.footerView.hidden = YES;
    self.hiddenAll = YES;
    if (!self.isLock) {
        self.lockButton.hidden = YES;
    }
}

- (void)showBasicViews
{
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    self.backButton.hidden = NO;
    self.playbackButton.hidden = NO;
    self.currentPlaybackTimeLabel.hidden = NO;
    self.durationLabel.hidden = NO;
    self.durationSlider.hidden = NO;
    self.switchScrBtn.hidden = NO;
    self.lockButton.hidden = NO;
    self.headerView.hidden = NO;
    self.footerView.hidden = NO;
    self.hiddenAll = NO;
    if (!self.isFullscreen) {
        self.lockButton.hidden = YES;
        self.headerView.hidden = YES;
        self.backButton.hidden = YES;
    }
    
    if (self.videoLocalPath) {

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
    if (!self.isLock) {
        if (self.hiddenAll) {
            [self showBasicViews];
            self.hiddenDelaySeconds = 10;
            
        } else {
            [self hiddenAllView];
            self.hiddenDelaySeconds = 0;
        }
    }
    else{
        if (self.lockButton.hidden) {
            self.lockButton.hidden = NO;
            self.hiddenDelaySeconds = 10;
        }
        else{
            self.lockButton.hidden = YES;
            self.hiddenDelaySeconds = 0;
        }
    }
}
-(void)handleDoubleTap:(UIGestureRecognizer *)gesture
{
    UIImage *image;
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        // 暂停播放
        self.pausebuttonClick = YES;
        image = [UIImage imageNamed:@"res_ccVideo/player-playbutton"];
        [self.player pause];
        [self loadBigPauseButton];
    } else {
        // 继续播放
        self.pausebuttonClick = NO;
        self.BigPauseButton.hidden = YES;
        image = [UIImage imageNamed:@"res_ccVideo/player-pausebutton"];
        [self.player play];
        [self.materialView setHidden:YES];
    }
    [self.playbackButton setImage:image forState:UIControlStateNormal];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (gestureRecognizer == self.signelTap) {
        if ([touch.view isKindOfClass:[UIButton class]]) {
            return NO;
        }
        //lbbniu
        /*if ([touch.view isKindOfClass:[DWTableView class]]) {
            return NO;
        }*/
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
# pragma mark - 播放视频
- (void)loadPlayUrls
{
    if(cc){
        self.player.videoId = self.videoId;
        self.player.timeoutSeconds = 10;
        
        __weak LbbCCVideo *blockSelf = self;
        self.player.failBlock = ^(NSError *error) {
            loginfo(@"error: %@", [error localizedDescription]);
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
    }else{
        //[self switchQuality:0];
        [self resetViewContent];
    }
}

# pragma mark - 根据播放url更新涉及的视图

- (void)resetViewContent
{
    if(cc){
        // 获取默认清晰度播放url
        NSNumber *defaultquality = [self.playUrls objectForKey:@"defaultquality"];
        
        for (NSDictionary *playurl in [self.playUrls objectForKey:@"qualities"]) {
            if (defaultquality == [playurl objectForKey:@"quality"]) {
                self.currentPlayUrl = playurl;
                break;
            }
        }
    }
    if (!self.currentPlayUrl) {
        self.currentPlayUrl = [[self.playUrls objectForKey:@"qualities"] objectAtIndex:0];
    }
    loginfo(@"currentPlayUrl: %@", self.currentPlayUrl);
    self.player.shouldAutoplay = NO;
    [self.player prepareToPlay];
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    if(autoPlay){
        [self.player play];
        
        self.player.shouldAutoplay = YES;
        loginfo(@"play url---------: %@", self.player.originalContentURL);
    }
    loginfo(@"play url=========: %@", self.player.originalContentURL);
}

- (void)resetPlayer
{
    self.videoStatusLabel.hidden = NO;
    self.videoStatusLabel.text = @"正在加载";
    [self.player prepareToPlay];
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    [self.player play];
    logdebug(@"play url: %@", self.player.originalContentURL);
}

# pragma mark - 播放本地文件
- (void)playLocalVideo
{
    self.playUrls = [NSDictionary dictionaryWithObject:self.videoLocalPath forKey:@"playurl"];
    self.player.contentURL = [[NSURL alloc] initFileURLWithPath:self.videoLocalPath];
    
    [self.player prepareToPlay];
    AVAudioSession *audioSession =[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    if(autoPlay){
        [self.player play];
    }
    logdebug(@"play url: %@", self.player.originalContentURL);
}

# pragma mark - MPMoviePlayController Notifications
- (void)addObserverForMPMoviePlayController
{
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // MPMovieDurationAvailableNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerDurationAvailable) name:MPMovieDurationAvailableNotification object:self.player];
    
    // MPMovieNaturalSizeAvailableNotification
    
    // MPMoviePlayerLoadStateDidChangeNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerLoadStateDidChange) name:MPMoviePlayerLoadStateDidChangeNotification object:self.player];
    
    // MPMoviePlayerPlaybackDidFinishNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerPlaybackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.player];
    
    // MPMoviePlayerPlaybackStateDidChangeNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerPlaybackStateDidChange) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
    
    // MPMoviePlayerReadyForDisplayDidChangeNotification
}

- (void)moviePlayerDurationAvailable
{
    self.durationLabel.text = [DWTools formatSecondsToString:self.player.duration];
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:0];
    self.durationSlider.minimumValue = 0.0;
    self.durationSlider.maximumValue = self.player.duration;
    loginfo(@"seconds %f maximumValue %f %@", self.player.duration, self.durationSlider.maximumValue, self.durationLabel.text);
}

- (void)moviePlayerLoadStateDidChange
{
    switch (self.player.loadState) {
        case MPMovieLoadStatePlayable:
            // 可播放
            logdebug(@"%@ playable", self.player.originalContentURL);
            self.videoStatusLabel.hidden = YES;
            if (_videoId) {
                if (self.player.playNum < 2) {
                    if(cc && self.videoLocalPath == nil)
                        [self.player first_load];
                    self.player.playNum ++;
                    [self readNSUserDefaults];
                }
            }
            break;
            
        case MPMovieLoadStatePlaythroughOK:
            // 状态为缓冲几乎完成，可以连续播放
            logdebug(@"%@ PlaythroughOK", self.player.originalContentURL);
            self.videoStatusLabel.hidden = YES;
            if (_videoId) {
                if (self.player.playNum < 2) {
                    if(cc && self.videoLocalPath == nil)
                        [self.player first_load];
                    self.player.playNum ++;
                    [self readNSUserDefaults];
                }
            }
            break;
            
        default:
            break;
    }
}

- (void)moviePlayerPlaybackDidFinish:(NSNotification *)notification
{
    logdebug(@"accessLog %@", self.player.accessLog);
    logdebug(@"errorLog %@", self.player.errorLog);
    NSNumber *n = [[notification userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    switch ([n intValue]) {
        case MPMovieFinishReasonPlaybackEnded:
        {
            logdebug(@"PlaybackEnded");
            self.videoStatusLabel.hidden = YES;
            
            //进度记忆清零
            if (self.videoId) {
                [[NSUserDefaults standardUserDefaults]removeObjectForKey:_videoId];
            }else if (self.videoLocalPath)
            {
                [[NSUserDefaults standardUserDefaults]removeObjectForKey:_videoLocalPath];
            }
            [[NSUserDefaults standardUserDefaults]synchronize];
            
            break;
        }
        case MPMovieFinishReasonPlaybackError:
            logdebug(@"PlaybackError");
            self.videoStatusLabel.hidden = NO;
            self.videoStatusLabel.text = @"加载失败";
            break;
        case MPMovieFinishReasonUserExited:
            logdebug(@"ReasonUserExited");
            break;
        default:
            break;
    }
}

- (void)moviePlayerPlaybackStateDidChange
{
    logdebug(@"playbackState: %ld", (long)self.player.playbackState);
    
    switch ([self.player playbackState]) {
        case MPMoviePlaybackStateStopped:
        {   logdebug(@"movie stopped");
            [self.playbackButton setImage:[UIImage imageNamed:@"res_ccVideo/player-playbutton"] forState:UIControlStateNormal];
            break;
        }
        case MPMoviePlaybackStatePlaying:
        {
            [self.playbackButton setImage:[UIImage imageNamed:@"res_ccVideo/player-pausebutton"] forState:UIControlStateNormal];
            logdebug(@"movie playing");
            self.videoStatusLabel.hidden = YES;
            [self.overlayView addGestureRecognizer:tapPan];
            self.player.playaction = @"buffereddrag";
            if (_videoId) {
                if (self.player.playNum >1 && self.player.isReplay == NO) {
                    if(cc && self.videoLocalPath == nil){
                        [self.player replay];
                    }
                }
            }
            break;
        }
        case MPMoviePlaybackStatePaused:
        {
            [self.playbackButton setImage:[UIImage imageNamed:@"res_ccVideo/player-playbutton"] forState:UIControlStateNormal];
            logdebug(@"movie paused");
            self.videoStatusLabel.hidden = NO;
            self.player.action++;
            self.player.playaction = @"unbuffereddrag";
            if (_videoId) {
                if (self.player.playableDuration < 5 && self.player.playNum >1 && self.player.sourceURL==nil) {
                    if(cc && self.videoLocalPath == nil){
                        [self.player playlog];
                    }
                    
                    
                    if (self.player.action == 1 || self.player.action == 3) {
                        if(cc && self.videoLocalPath == nil){
                            [self.player playlog_php];
                        }
                    }
                }
            }
            if (self.pausebuttonClick) {
                self.videoStatusLabel.hidden = YES;
            }
            else{
                self.videoStatusLabel.text = @"正在加载";
            }
            break;
        }
        case MPMoviePlaybackStateSeekingForward:
            logdebug(@"movie seekingForward");
            self.videoStatusLabel.hidden = YES;
            break;
            
        case MPMoviePlaybackStateSeekingBackward:
            logdebug(@"movie seekingBackward");
            self.videoStatusLabel.hidden = YES;
            break;
            
        default:
            break;
    }
}

# pragma mark - 记录播放位置

-(void)saveNsUserDefaults
{
    
    //记录退出时播放信息
    NSTimeInterval time = self.player.currentPlaybackTime;
    long long dTime = [[NSNumber numberWithDouble:time] longLongValue];
    NSString *curTime = [NSString stringWithFormat:@"%llu",dTime];
    self.playPosition = [NSDictionary dictionaryWithObjectsAndKeys:
                         curTime,@"playbackTime",
                         nil];
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
}
-(void)readNSUserDefaults
{
    if(position != nil){
        self.durationSlider.value = [position intValue]/1000;
        self.player.currentPlaybackTime = self.durationSlider.value;//[position intValue]/1000;
    }else{
        NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
        if (self.videoId) {
            NSDictionary *playPosition = [userDefaultes dictionaryForKey:_videoId];
            self.player.currentPlaybackTime = [[playPosition valueForKey:@"playbackTime"] floatValue];
            
        }else if (self.videoLocalPath){
            NSDictionary *playPosition = [userDefaultes dictionaryForKey:_videoLocalPath];
            self.player.currentPlaybackTime = [[playPosition valueForKey:@"playbackTime"] floatValue];
        }
    }
    loginfo("-currentPlaybackTime---------------------------- %f",self.player.currentPlaybackTime);
}

# pragma mark - timer
- (void)addTimer
{
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(timerHandler) userInfo:nil repeats:YES];
}

- (void)removeTimer
{
    if(self.timer){
        [self.timer invalidate];
    }
}

- (void)timerHandler
{
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
    self.durationLabel.text = [DWTools formatSecondsToString:self.player.duration];
    self.durationSlider.value = self.player.currentPlaybackTime;
    self.historyPlaybackTime = self.player.currentPlaybackTime;
    if (!self.tipLabel.hidden) {
        self.tipHiddenSeconds --;
        if (self.tipHiddenSeconds == 0) {
            self.tipLabel.hidden = YES;
        }
    }
    
    if (!self.hiddenAll) {
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
+ (NSString*)dictionaryToJson:(NSDictionary *)dic
{
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (void)saveDownloadItems
{

    //保存下载列表
    [DOWNLOADMANAGER.downloadingItems writeToPlistFile:DWDownloadingItemPlistFilename];

    //保存下载完成列表
    [DOWNLOADMANAGER.downloadFinishItems writeToPlistFile:DWDownloadFinishItemPlistFilename];

}

//启动下载服务
-(void)startDownloadSvr:(NSDictionary *)paramDict
{
    _downloadCbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    DOWNLOADMANAGER._downloadCbId = _downloadCbId;
    [self downloadAddTimer];
    
    if (_downloadCbId >= 0){
        NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [sendDict setObject:[NSNumber numberWithInteger:1] forKey:@"status"];
        [self sendResultEventWithCallbackId:_downloadCbId dataDict:sendDict errDict:nil doDelete:NO];
    }
}
//停止下载服务
-(void)stopDownloadSvr:(NSDictionary *)paramDict
{
    [self saveDownloadItems];
    [self downloadRemoveTimer];
    //todo：停止所有下载
}

//向队列中增加视频
-(void)addDownloadVideo:(NSDictionary *)paramDict
{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    NSString *videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];
    NSString *definition = [paramDict stringValueForKey:@"definition" defaultValue:nil];
    DWDownloadItem *item = nil;
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [sendDict setObject:[NSNumber numberWithInteger:0] forKey:@"status"];
    BOOL isDownloaded = NO;
    // 判断是否"下载完成"列表中
    for (item in DOWNLOADMANAGER.downloadFinishItems.items) {
        if (!definition) {
            if ([item.videoId isEqualToString:videoId] && !item.definition) {
                isDownloaded = YES;
            }
        } else {
            if ([item.videoId isEqualToString:videoId] && [item.definition isEqualToString:definition]) {
                isDownloaded = YES;
            }
        }
    }
    if(!isDownloaded){
        // 判断是否"正在下载"列表中
        for (item in DOWNLOADMANAGER.downloadingItems.items) {
            if (!definition) {
                if ([item.videoId isEqualToString:videoId] && !item.definition) {
                    isDownloaded = YES;
                }
            } else {
                if ([item.videoId isEqualToString:videoId] && [item.definition isEqualToString:definition]) {
                    isDownloaded = YES;
                }
            }
        }
    }
    
    if(!isDownloaded){
        [sendDict setObject:[NSNumber numberWithInteger:1] forKey:@"status"];
        item = [[DWDownloadItem alloc] init];
        item.videoId = videoId;
        item.videoDownloadStatus = DWDownloadStatusWait;
        
        if(definition) {
            item.definition = definition;
        }
        [DOWNLOADMANAGER.downloadingItems.items addObject:item];
        //回调下载列表 更新数据
        dispatch_async(dispatch_get_main_queue(), ^{
            [self callbackDownloadList:DOWNLOADMANAGER.downloadingItems action:@"lbb.downloading"];
            [self saveDownloadItems];
        });
    }
    if (cbId >= 0){
        [self sendResultEventWithCallbackId:cbId dataDict:sendDict errDict:nil doDelete:YES];
    }
}

//点击视频列表中的视频  lbbniu
-(void)downloadVideo:(NSDictionary *)paramDict
{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    NSString *videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [sendDict setObject:[NSNumber numberWithInteger:1] forKey:@"status"];
    DWDownloadItem *item = nil;
    for (item in DOWNLOADMANAGER.downloadingItems.items) {
        if ([item.videoId isEqualToString:videoId]) {
            switch (item.videoDownloadStatus) {
                case DWDownloadStatusWait:
                    // 状态转为 开始下载
                    [self videoDownloadStartWithItem:item];
                    break;
                    
                case DWDownloadStatusStart:
                    // 状态转为 暂停下载
                    [self videoDownloadPauseWithItem:item];
                    break;
                    
                case DWDownloadStatusDownloading:
                    // 状态转为 暂停下载
                    [self videoDownloadPauseWithItem:item];
                    break;
                    
                case DWDownloadStatusPause:
                    // 状态转为 开始下载
                    [self videoDownloadResumeWithItem:item];
                    break;
                    
                case DWDownloadStatusFail:
                    // 状态转为 重新开始
                    [self videoDownloadStartWithItem:item];
                    break;
                case DWDownloadStatusFinish:
                    // 播放本地视频
                    break;
                    
                default:
                    break;
            }
            break;
        }
    }
    
    if (cbId >= 0){
        [self sendResultEventWithCallbackId:cbId dataDict:sendDict errDict:nil doDelete:YES];
    }
}

//删除视频
-(void)removeDownloadVideo:(NSDictionary *)paramDict
{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    NSString *videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];
    DWDownloadItem *item = nil;
    NSInteger index = 0;
    // 判断是否"下载完成"列表中
    for (item in DOWNLOADMANAGER.downloadFinishItems.items) {
        if ([item.videoId isEqualToString:videoId]) {
            logdebug(@"deleted item---: %@", item);
            [DOWNLOADMANAGER.downloadFinishItems removeObjectAtIndex:index];
            //lbbniu 刷新UI
            dispatch_async(dispatch_get_main_queue(), ^{
                [self rmFile:videoId];
                [self callbackDownloadList:DOWNLOADMANAGER.downloadFinishItems action:@"lbb.downloaded"];
                [self saveDownloadItems];
            });
            break;
        }
        index++;
    }

    // 判断是否"正在下载"列表中
    index = 0;
    for (item in DOWNLOADMANAGER.downloadingItems.items) {
        if ([item.videoId isEqualToString:videoId]) {
            [self videoDownloadPauseWithItem:item];
            loginfo(@"deleted item===: %@", item);
            [DOWNLOADMANAGER.downloadingItems removeObjectAtIndex:index];
            //lbbniu 刷新UI
            dispatch_async(dispatch_get_main_queue(), ^{
                [self rmFile:videoId];
                [self callbackDownloadList:DOWNLOADMANAGER.downloadingItems action:@"lbb.downloading"];
                [self saveDownloadItems];
            });
            break;
        }
        index++;
    }
    
    if (cbId >= 0){
        NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [sendDict setObject:[NSNumber numberWithInteger:1] forKey:@"status"];
        [self sendResultEventWithCallbackId:cbId dataDict:sendDict errDict:nil doDelete:YES];
    }
}
- (void)rmFile:(NSString *)videoId{
    if (!videoId) {
        return;
    }
    //caches目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSString *videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, videoId];
    NSError *err;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    BOOL bRet = [fileMgr fileExistsAtPath:videoPath];
    if (bRet) {
        [fileMgr removeItemAtPath:videoPath error:&err];
    }
}
//获取下载中的视频列表
-(void)getDownloadingList:(NSDictionary *)paramDict
{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self callbackDownloadList:DOWNLOADMANAGER.downloadingItems  callbackCbId:cbId action:nil];
    });
}

//获取下载完成的视频列表
-(void)getDownloadedList:(NSDictionary *)paramDict
{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self callbackDownloadList:DOWNLOADMANAGER.downloadFinishItems callbackCbId:cbId action:nil];
    });
}

-(void)callbackDownloadList:(DWDownloadItems *)downloadItems callbackCbId:(NSInteger)cbId action:(NSString *)action {
    DWDownloadItem *item = nil;
    NSInteger index = 0;
    NSMutableArray *callBackArr = [NSMutableArray array];
    // 判断是否"下载完成"列表中
    for (item in downloadItems.items) {
        NSMutableDictionary * ttt =[NSMutableDictionary dictionaryWithCapacity:3];
        [ttt setObject:[NSNumber numberWithInteger:++index] forKey:@"id"];
        [ttt setObject:item.videoId forKey:@"title"];
        [ttt setObject:item.videoId forKey:@"videoId"];
        [ttt setObject:[NSNumber numberWithInteger:item.videoDownloadProgress*100] forKey:@"progress"];
        float downloadedSizeMB = [item videoDownloadedSize]/1024.0/1024.0;
        float fileSizeMB = [item videoFileSize]/1024.0/1024.0;
        [ttt setObject:[NSString stringWithFormat:@"%0.1fM", downloadedSizeMB] forKey:@"downloadSize"];
        [ttt setObject:[NSString stringWithFormat:@"%0.1fM", fileSizeMB] forKey:@"fileSize"];
        [ttt setObject:[NSNumber numberWithInteger:item.videoDownloadStatus] forKey:@"status"];
        float secondSizeKB = [item secondSize]/1024.0;
        item.secondSize = 0;
        switch (item.videoDownloadStatus) {
            case DWDownloadStatusWait:
                // 状态转为 开始下载
                [ttt setObject:@"等待中" forKey:@"statusInfo"];
                break;
                
            case DWDownloadStatusStart:
                // 状态转为 暂停下载
                [ttt setObject:@"下载中" forKey:@"statusInfo"];
                break;
                
            case DWDownloadStatusDownloading:
                // 状态转为 暂停下载
                [ttt setObject:@"下载中" forKey:@"statusInfo"];
                break;
                
            case DWDownloadStatusPause:
                // 状态转为 开始下载
                [ttt setObject:@"暂停中" forKey:@"statusInfo"];
                break;
                
            case DWDownloadStatusFail:
                // 状态转为 重新开始
                [ttt setObject:@"暂停中" forKey:@"statusInfo"];
                break;
                
            case DWDownloadStatusFinish:
                // 播放本地视频
                [ttt setObject:@"已下载"  forKey:@"statusInfo"];
                break;
                
            default:
                break;
        }
        [ttt setObject:[NSString stringWithFormat:@"已下载%0.1fM / 共%0.1fM 占比%0.1f 下载速度%0.1fkb/s", downloadedSizeMB, fileSizeMB , item.videoDownloadProgress*100, secondSizeKB] forKey:@"progressText"];
        
        [callBackArr addObject:ttt];
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [sendDict setObject:[NSNumber numberWithInteger:1] forKey:@"status"];
    if(action != nil){
        [sendDict setObject:action forKey:@"action"];
    }
    [sendDict setObject:callBackArr forKey:@"data"];
    if (DOWNLOADMANAGER._downloadCbId >= 0){
        //loginfo(@"sendDict item: %@", sendDict);
        [self sendResultEventWithCallbackId:cbId dataDict:sendDict errDict:nil doDelete:NO];
    }
}


-(void)callbackDownloadList:(DWDownloadItems *)downloadItems action:(NSString *)action {
    [self callbackDownloadList:downloadItems callbackCbId:DOWNLOADMANAGER._downloadCbId action:action];
}

- (void)videoDownloadStartWithItem:(DWDownloadItem *)item
{
    //判断任务个数
    if(DOWNLOADMANAGER.count>=2){
        return;
    }
    // 更新下载状态
    item.videoDownloadStatus  = DWDownloadStatusStart;
    // 开始下载
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    
    // DEMO_REPLACE_CODE_OFFLINE_EXTENSION_{
    /* 注意：
     若你所下载的 videoId 未启用视频加密功能，则保存的文件扩展名[必须]是 mp4，否则无法播放。
     若你所下载的 videoId 启用了视频加密功能，则保存的文件扩展名[必须]是 pcm，否则无法播放。
     */
    
    NSString *videoPath;
    
    if (!item.definition) {
        videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, item.videoId];
    } else {
        videoPath = [NSString stringWithFormat:@"%@/%@-%@.mp4", documentDirectory, item.videoId, item.definition];
    }
    
    item.videoPath = videoPath;
    DWDownloader *downloader = [[DWDownloader alloc] initWithUserId:userId
                                                         andVideoId:item.videoId
                                                                key:apiKey
                                                    destinationPath:item.videoPath];
    item.downloader = downloader;
    item.videoDownloadStatus  = DWDownloadStatusDownloading;
    downloader.timeoutSeconds = 20;
    
    [self setDownloaderBlocksWithItem:item];
    
    //if (self.playUrl) {
    //   [downloader startWithUrlString:self.playUrl];
    //} else {
        [downloader start];
    //}
    DOWNLOADMANAGER.count++;
}
- (void)videoDownloadResumeWithItem:(DWDownloadItem *)item
{
    //判断任务个数
    if (item.downloader) {
        
        item.videoDownloadStatus = DWDownloadStatusDownloading;
        //[cell updateDownloadStatus:item];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self callbackDownloadList:DOWNLOADMANAGER.downloadingItems action:@"lbb.downloading"];
        });
        [item.downloader resume];
        DOWNLOADMANAGER.count++;
    } else {
        [self videoDownloadStartWithItem:item];
    }
}
- (void)videoDownloadPauseWithItem:(DWDownloadItem *)item
{
    if (!item.downloader) {
        return;
    }
    if(item.videoDownloadStatus == DWDownloadStatusDownloading || item.videoDownloadStatus == DWDownloadStatusStart){
         DOWNLOADMANAGER.count--;
    }
    [item.downloader pause];
    item.videoDownloadStatus = DWDownloadStatusPause;
    
    //[cell updateDownloadStatus:item];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self callbackDownloadList:DOWNLOADMANAGER.downloadingItems action:@"lbb.downloading"];
    });
}


- (void)setDownloaderBlocksWithItem:(DWDownloadItem *)item
{
    DWDownloader *downloader = item.downloader;
    
    downloader.progressBlock = ^(float progress, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite) {
        // NSLog(@"totalBytesWritten==%ld,totalBytesExpectedToWrite==%ld",(long)totalBytesWritten,(long)totalBytesExpectedToWrite);
        if(item.downloader.remoteFileSize < 2000){
            [self rmFile:item.videoId];
            
            item.videoDownloadedSize = 0;
            item.videoDownloadProgress = 0;
            return;
        }
        if(item.videoDownloadedSize > 0){
            item.secondSize = item.secondSize + totalBytesWritten - item.videoDownloadedSize;
        }
        
        item.videoDownloadedSize = totalBytesWritten;
        item.videoFileSize = totalBytesExpectedToWrite;
        
        
        item.videoDownloadProgress = (float)item.videoDownloadedSize/item.videoFileSize;
        logdebug(@"download progressBlock %@", item);
        
        //[cell updateCellProgress:item];
        dispatch_async(dispatch_get_main_queue(), ^{
            //[self callbackDownloadList:DOWNLOADMANAGER.downloadingItems action:@"lbb.downloading"];
        });
    };
    
    downloader.failBlock = ^(NSError *error) {
        if(item.downloader.remoteFileSize < 2000){
            item.videoDownloadedSize = 0;
            item.videoDownloadProgress = 0;
            [self rmFile:item.videoId];
        }
        item.videoDownloadStatus = DWDownloadStatusFail;
        logerror(@"download fail %@", [error localizedDescription]);
        logerror(@"download fail %@", item);
        //[cell updateDownloadStatus:item];
        DOWNLOADMANAGER.count--;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self callbackDownloadList:DOWNLOADMANAGER.downloadingItems action:@"lbb.downloading"];
        });
    };
    
    downloader.finishBlock = ^() {
        //下载个数减一
        DOWNLOADMANAGER.count--;
        logdebug(@"download finish %@", item);
        item.videoDownloadStatus = DWDownloadStatusFinish;
        [DOWNLOADMANAGER.downloadingItems.items removeObject:item];
        [DOWNLOADMANAGER.downloadFinishItems.items insertObject:item atIndex:0];
        //[cell updateDownloadStatus:item];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self callbackDownloadList:DOWNLOADMANAGER.downloadingItems action:@"lbb.downloading"];
            [self callbackDownloadList:DOWNLOADMANAGER.downloadFinishItems action:@"lbb.downloaded"];
            [self saveDownloadItems];
        });
        
    };
}


# pragma mark - timer

- (void)downloadAddTimer
{
    if (!self.downloadTimer) {
        self.downloadTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(downloadTimerHandler) userInfo:nil repeats:YES];
    }
}

- (void)downloadRemoveTimer
{
    [self.downloadTimer invalidate];
}

- (void)downloadTimerHandler
{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if(count%10 == 0){
            [self saveDownloadItems];
        }
        if(DOWNLOADMANAGER.downloadingItems.items.count>0){
            [self callbackDownloadList:DOWNLOADMANAGER.downloadingItems action:@"lbb.downloading"];
        }
        count++;
    });
    //loginfo(@"downloadTimerHandler itemcount===: %ld", DOWNLOADMANAGER.count);
    if(DOWNLOADMANAGER.count>2){
        return;
    }
    DWDownloadItem *item = nil;
    DOWNLOADMANAGER.isDownloaded = NO;
    NSInteger index = 0;
    for (item in DOWNLOADMANAGER.downloadingItems.items) {
        if (item.videoDownloadStatus == DWDownloadStatusWait) {
            DOWNLOADMANAGER.isDownloaded = YES;
            break;
        }else if(item.videoDownloadStatus == DWDownloadStatusStart && item.downloader == nil){
            DOWNLOADMANAGER.isDownloaded = YES;
            break;
        } else if(item.videoDownloadStatus == DWDownloadStatusDownloading && item.downloader == nil){
            DOWNLOADMANAGER.isDownloaded = YES;
            break;
        }
        index++;
    }
    if (!item || DOWNLOADMANAGER.isDownloaded == NO) {
        return;
    }
    // 开始下载
    logdebug(@"download start item: %@", item);
    [self videoDownloadStartWithItem:item];
}
@end
