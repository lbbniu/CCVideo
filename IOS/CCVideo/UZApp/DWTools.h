#import <Foundation/Foundation.h>

@interface DWTools : NSObject

+ (NSInteger)getFileSizeWithPath:(NSString *)filePath Error:(NSError **)error;

+ (UIImage *)getImage:(NSString *)videoPath atTime:(NSTimeInterval)time Error:(NSError **)error;

+ (BOOL)saveVideoThumbnailWithVideoPath:(NSString *)vieoPath toFile:(NSString *)ThumbnailPath Error:(NSError **)error;

+ (NSString *)formatSecondsToString:(NSInteger)seconds;

//数据库


+(instancetype)shareInstance;

//------------------下载表-----------------
-(void)creatDownloadTable;
- (BOOL)isExistDownloadingTask:(NSString*)state :(NSString *)userId;
- (void)managerDownlodTableWithUserid:(NSString *)userid courseId:(NSString *)courseId videoId:(NSString *)videoId state:(NSString *)state progress:(NSString *)progress expitationTime:(NSString *)expitationTime path:(NSString *)path downloadTime:(NSString *)downloadTime isBuy:(NSString *)isBuy
                               isLock:(NSString *)isLock activeState:(NSString *)activeState modifyTime:(NSString *)modifyTime playTime:(NSString *)playTime taskIndex:(NSString *)taskIndex;

- (void)updateDownloadTableWithUserid:(NSString *)userId andVideoId:(NSString *)videoId andState:(NSString *)state andProgress:(NSString *)progress andModifyTime:(NSString *)modifyTime;

-(void)updateCourseState:(NSString *)userId andVideoId:(NSString *)videoId andState:(NSString *)state andModifyTime:(NSString *)modifyTime;
-(void)updatePlayTimeWithUserID:(NSString *)userId andVideoId:(NSString *)videoId andPlayTime:(NSString *)playTime;
-(NSString *)getTaskData:(NSString *)userId andTime:(NSString *)passTime;
-(NSMutableDictionary *)getProgressStateWithVideoId:(NSString *)videoId andUserId:(NSString *)userId;
-(NSMutableArray *)getAllCourseVideoId:(NSString *)userId;
-(void)deleteCourseTaskWithUserId:(NSString *)userId andVideoId:(NSString *)videoId;


//---------------视频播放时间表-------------
-(void)creatVideoCourseJsonTable;

- (void)managerCourseJsonTableWithUserId:(NSString *)userId andCourseId:(NSString *)courseId andCourseJson:(NSString *)courseJson;

-(NSMutableArray *)getAllCourseJson:(NSString *)userId;

-(NSMutableArray *)getCourseJsonWithCourseId:(NSString *)courseId andUserId:(NSString *)userId;

@end
