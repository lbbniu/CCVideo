#import <UIKit/UIKit.h>
#import "DWTools.h"
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import "FMDB.h"

@interface DWTools ()

//创建的数据库
@property (nonatomic, strong)FMDatabase *db;

@end

@implementation DWTools

static DWTools *fmdbTools =nil;

+ (NSInteger)getFileSizeWithPath:(NSString *)filePath Error:(NSError **)error
{
    NSFileManager *fileManager = nil;
    NSDictionary *fileAttr = nil;
    NSInteger fileSize;
    
    fileManager = [NSFileManager defaultManager];
    
    fileAttr = [fileManager attributesOfItemAtPath:filePath error:error];
    if (error && *error) {
        return -1;
    }
    
    fileSize = (NSInteger)[[fileAttr objectForKey:NSFileSize] longLongValue];
    
    return fileSize;
}

+ (UIImage *)getImage:(NSString *)videoPath atTime:(NSTimeInterval)time Error:(NSError **)error
{
    if (!videoPath) {
        return nil;
    }
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[[NSURL alloc] initFileURLWithPath:videoPath] options:nil];
    AVAssetImageGenerator *assetImageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetImageGenerator.appliesPreferredTrackTransform = YES;
    assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    
    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = time;
    thumbnailImageRef = [assetImageGenerator copyCGImageAtTime:CMTimeMake(thumbnailImageTime, 60)
                                                    actualTime:NULL error:error];
    
    //logdebug(@"thumbnailImageRef: %p %@", thumbnailImageRef, thumbnailImageRef);
    if (!thumbnailImageRef) {
        return nil;
    }
    
    UIImage *thumbnailImage = [[UIImage alloc] initWithCGImage:thumbnailImageRef];
    //logdebug(@"thumbnailImage: %p", thumbnailImage);
    
    CFRelease(thumbnailImageRef);
    
    return thumbnailImage;
}

+ (BOOL)saveVideoThumbnailWithVideoPath:(NSString *)vieoPath toFile:(NSString *)ThumbnailPath Error:(NSError **)error
{
    NSError *er;
    UIImage *image = [DWTools getImage:vieoPath atTime:1 Error:&er];
    if (er) {
        //logerror(@"get video thumbnail failed: %@", [er localizedDescription]);
        if (error) {
            *error = er;
        }
        return NO;
    }
    
    [UIImagePNGRepresentation(image) writeToFile:ThumbnailPath atomically:YES];
    
    //logdebug(@"image: %@", image);
    
    return YES;
    
}

+ (NSString *)formatSecondsToString:(NSInteger)seconds
{
    NSString *hhmmss = nil;
    if (seconds < 0) {
        //return @"00:00:00";
        return @"00:00";
    }
    
    //int h = (int)round((seconds%86400)/3600);
    int m = (int)round(seconds/60);
    int s = (int)round(seconds%60);
    
    //hhmmss = [NSString stringWithFormat:@"%02d:%02d:%02d", h, m, s];
    if(m>99){
        hhmmss = [NSString stringWithFormat:@"%03d:%02d", m, s];
    }else{
        hhmmss = [NSString stringWithFormat:@"%02d:%02d", m, s];
    }
    
    return hhmmss;
}
+ (UIImage *)imageCompressForSize:(UIImage *)sourceImage targetSize:(CGSize)size{
    
    UIImage *newImage = nil;
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    CGFloat targetWidth = size.width;
    CGFloat targetHeight = size.height;
    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    CGPoint thumbnailPoint = CGPointMake(0.0, 0.0);
    
    if(CGSizeEqualToSize(imageSize, size) == NO){
        
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
        
        if(widthFactor > heightFactor){
            scaleFactor = heightFactor;
            
        }
        else{
            scaleFactor = widthFactor;
        }
        scaledWidth = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        
        if(widthFactor > heightFactor){
            thumbnailPoint.x = (targetWidth - scaledWidth)/2;
            
        }else if(widthFactor < heightFactor){
            thumbnailPoint.y = (targetHeight - scaledHeight)/2;
            
        }
    }
    
    UIGraphicsBeginImageContext(size);
    
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width = scaledWidth;
    thumbnailRect.size.height = scaledHeight;
    
    [sourceImage drawInRect:thumbnailRect];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    if(newImage == nil){
        NSLog(@"scale image fail");
    }
    
    UIGraphicsEndImageContext();
    return newImage;
}


//记录页码的单例类
+(instancetype)shareInstance
{
    if (!fmdbTools) {
        
        fmdbTools = [[DWTools alloc]init];
    }
    return fmdbTools;
}


#pragma mark----------视频下载表--------------
- (void)creatDownloadTable{
    
    //获取文件存储路径
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *fileName = [path stringByAppendingPathComponent:@"downloadProgress.sqlite"];
    
    NSLog(@"-------pathhhhhh----=%@",fileName);
    //创建数据库
    self.db = [FMDatabase databaseWithPath:fileName];
    
    if ([self.db open]) {
        
        //创建表
        BOOL result = [self.db executeUpdate:@"CREATE TABLE IF NOT EXISTS DOWNLOAD_TABLE (USERID TEXT,COURSEID TEXT,VIDEOID TEXT,STATE TEXT,PROGTRESS TEXT,EXPIRATIONTIME TEXT,PATH TEXT,DOWNLOADTIME TEXT,ISBUY TEXT,ISLOCK TEXT,ACTIVESTATE TEXT,MODIFYTIME TEXT,PLAYTIME TEXT,TASKINDEX TEXT);"];
        if (result) {
            NSLog(@"creatTable  success!");
        }else{
            NSLog(@"creatTable  fault!");
        }
    }
}

//管理数据库downLoadTable表

- (void)managerDownlodTableWithUserid:(NSString *)userId courseId:(NSString *)courseId videoId:(NSString *)videoId state:(NSString *)state progress:(NSString *)progress expitationTime:(NSString *)expitationTime path:(NSString *)path downloadTime:(NSString *)downloadTime isBuy:(NSString *)isBuy
                               isLock:(NSString *)isLock activeState:(NSString *)activeState modifyTime:(NSString *)modifyTime playTime:(NSString *)playTime taskIndex:(NSString *)taskIndex{
    
    if ([self isExistDownloadTableWithVideoID:videoId :userId]==false) {//默认是假的，需要更新表新值
        
        [self insertDownloadTableWithUserid:userId courseId:courseId videoId:videoId state:state progress:progress expitationTime:expitationTime path:path downloadTime:downloadTime isBuy:isBuy isLock:isLock activeState:activeState modifyTime:modifyTime playTime:playTime taskIndex:taskIndex];
        
    }else{
        
        return;
    }
}

//是否已经存在OffLineTable表中是否存在对应的ldid数据
- (BOOL)isExistDownloadingTask:(NSString*)state :(NSString *)userId{
    
    BOOL isExist = false;
    FMResultSet *queryResult = [self.db executeQuery:@"SELECT * FROM DOWNLOAD_TABLE"];
    while ([queryResult next]) {
        
        NSString* temp_userId = [queryResult stringForColumn:@"USERID"];
        NSString* temp_state= [queryResult stringForColumn:@"STATE"];
        
        if ([temp_userId isEqualToString:userId]&&[state isEqualToString:temp_state]) {//如果已经存在该数据，那就进行更新
            return isExist = true;
        }
    }
    return isExist;
}

//是否已经存在OffLineTable表中是否存在对应的ldid数据
- (BOOL)isExistDownloadTableWithVideoID:(NSString*)videoId :(NSString *)userId{
    
    BOOL isExist = false;
    FMResultSet *queryResult = [self.db executeQuery:@"SELECT * FROM DOWNLOAD_TABLE"];
    while ([queryResult next]) {
        
        NSString* temp_userId = [queryResult stringForColumn:@"USERID"];
        NSString* temp_videoId = [queryResult stringForColumn:@"VIDEOID"];
        
        if ([temp_userId isEqualToString:userId]&&[videoId isEqualToString:temp_videoId]) {//如果已经存在该数据，那就进行更新
            return isExist = true;
        }
    }
    return isExist;
}

//插入exaHistory数据
- (void)insertDownloadTableWithUserid:(NSString *)userId courseId:(NSString *)courseId videoId:(NSString *)videoId state:(NSString *)state progress:(NSString *)progress expitationTime:(NSString *)expitationTime path:(NSString *)path downloadTime:(NSString *)downloadTime isBuy:(NSString *)isBuy
                               isLock:(NSString *)isLock activeState:(NSString *)activeState modifyTime:(NSString *)modifyTime playTime:(NSString *)playTime taskIndex:(NSString *)taskIndex{
    
    BOOL result =  [self.db executeUpdate:@"INSERT INTO DOWNLOAD_TABLE (USERID,COURSEID,VIDEOID,STATE,PROGTRESS,EXPIRATIONTIME,PATH,DOWNLOADTIME,ISBUY,ISLOCK,ACTIVESTATE,MODIFYTIME,PLAYTIME,TASKINDEX) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",userId,courseId,videoId,state,progress,expitationTime,path,downloadTime,isBuy,isLock,activeState,modifyTime,playTime,taskIndex];
    
    if (result) {
        NSLog(@"insert DOWNLOAD_TABLE success!");
    }else{
        NSLog(@"insert DOWNLOAD_TABLE fault!");
    }
}

- (void)updateDownloadTableWithUserid:(NSString *)userId andVideoId:(NSString *)videoId andState:(NSString *)state andProgress:(NSString *)progress andModifyTime:(NSString *)modifyTime{
    
    BOOL result = [self.db executeUpdate:@"UPDATE DOWNLOAD_TABLE SET STATE =? , PROGTRESS = ? , MODIFYTIME = ? WHERE VIDEOID =? and USERID =?",state,progress,modifyTime,videoId,userId];
    
    if (result) {
        
        NSLog(@"update DOWNLOAD_TABLE success!");
        
    }else{
        
        NSLog(@"update DOWNLOAD_TABLE fault!");
    }
}

-(void)updateCourseState:(NSString *)userId andVideoId:(NSString *)videoId andState:(NSString *)state andModifyTime:(NSString *)modifyTime
{
    BOOL result = [self.db executeUpdate:@"UPDATE DOWNLOAD_TABLE SET STATE =? , MODIFYTIME = ? WHERE VIDEOID =? and USERID =?",state,modifyTime,videoId,userId];
    
    if (result) {
        
        NSLog(@"update DOWNLOAD_TABLE success!");
        
    }else{
        
        NSLog(@"update DOWNLOAD_TABLE fault!");
    }
}

-(void)updatePlayTimeWithUserID:(NSString *)userId andVideoId:(NSString *)videoId andPlayTime:(NSString *)playTime
{
    BOOL result = [self.db executeUpdate:@"UPDATE DOWNLOAD_TABLE SET PLAYTIME =? WHERE VIDEOID =? and USERID =?",playTime,videoId,userId];
    
    if (result) {
        
        NSLog(@"update DOWNLOAD_TABLE success!");
        
    }else{
        
        NSLog(@"update DOWNLOAD_TABLE fault!");
    }
    
}

-(NSMutableArray *)getAllCourseVideoId:(NSString *)userId
{
    NSMutableArray *tempArray = [[NSMutableArray alloc]init];
    FMResultSet *queryResult = [self.db executeQuery:@"SELECT * FROM DOWNLOAD_TABLE WHERE USERID =?",userId];
    while ([queryResult next]){
        
        NSString *videoId = [queryResult stringForColumn:@"VIDEOID"];
        
        [tempArray addObject:videoId];
    }
    
    return tempArray;
}

-(NSString *)getTaskData:(NSString *)userId andTime:(NSString *)passTime
{
    NSDate *tempTime = [NSDate date];
    NSString *timeStr = [NSString stringWithFormat:@"%ld", (long)[tempTime timeIntervalSince1970]];
    FMResultSet *queryResult = [self.db executeQuery:@"SELECT * FROM DOWNLOAD_TABLE WHERE USERID =?",userId];
    
    NSString *courseStr = [NSString stringWithFormat:@"%@%@%@",@"{\"readTime\":",timeStr,@",\"data\":["];
    int count = 1;
    while ([queryResult next]){
        
        if ([timeStr intValue] > [passTime intValue]) {
            
            NSString *state = [queryResult stringForColumn:@"STATE"];
            NSString *progress = [queryResult stringForColumn:@"PROGTRESS"];
            NSString *creatTime = [queryResult stringForColumn:@"DOWNLOADTIME"];
            NSString *playTime = [queryResult stringForColumn:@"PLAYTIME"];
            NSString *path = [queryResult stringForColumn:@"PATH"];
            
            NSString *tempStr = nil;
            if(count==1)
            {
                tempStr =@"{";
                
                
            }else
            {
                tempStr = @",{";
            }
            
            NSString *stateStr = [NSString stringWithFormat:@"%@%@%@",@"\"state\":",state,@","];
            NSString *progressStr = [NSString stringWithFormat:@"%@%@%@",@"\"progress\":",progress,@","];
            NSString *creatTimeStr = [NSString stringWithFormat:@"%@%@%@",@"\"creatTime\":",creatTime,@","];
            NSString *playTimeStr = [NSString stringWithFormat:@"%@%@%@",@"\"playTime\":",playTime,@","];
            NSString *pathStr = [NSString stringWithFormat:@"%@%@%@",@"\"path\":",path,@"}"];
            courseStr = [NSString stringWithFormat:@"%@%@%@%@%@%@%@",courseStr,tempStr,stateStr,progressStr,creatTimeStr,playTimeStr,pathStr];
            
            count ++;
        }
        
    }
    NSString *tempStr = @"]}";
    
    courseStr = [NSString stringWithFormat:@"%@%@",courseStr,tempStr];
    return courseStr ;
}

-(void)deleteCourseTaskWithUserId:(NSString *)userId andVideoId:(NSString *)videoId
{
    BOOL result = [self.db executeUpdate:@"DELETE FROM DOWNLOAD_TABLE WHERE VIDEOID =? and USERID =?",videoId,userId];
    if (result) {
        NSLog(@"delete DOWNLOAD_TABLE success!");
    }else{
        NSLog(@"delete DOWNLOAD_TABLE fault!");
    }
    
}

#pragma mark----------课程详情json表--------------

-(void)creatVideoCourseJsonTable
{
    if ([self.db open]) {
        
        //创建表
        BOOL result = [self.db executeUpdate:@"CREATE TABLE IF NOT EXISTS COURSEJSON_TABLE (USERID TEXT,COURSEID TEXT,COURSEJSON TEXT);"];
        if (result) {
            NSLog(@"creatTable COURSEJSON_TABLE success!");
        }else{
            NSLog(@"creatTable COURSEJSON_TABLE fault!");
        }
    }
}

/**
 *  管理数据库OffLineTable表
 */
- (void)managerCourseJsonTableWithUserId:(NSString *)userId andCourseId:(NSString *)courseId andCourseJson:(NSString *)courseJson{
    
    if ([self isExistLastPlayTimeTableWithCourseID:courseId]==false) {//默认是假的，需要更新表新值
        
        [self insertCourseJsonWithUserid:userId andCourseId:courseId andCourseJson:courseJson];
        
    }else{
        
        return;
    }
}

//是否已经存在OffLineTable表中是否存在对应的ldid数据
- (BOOL)isExistLastPlayTimeTableWithCourseID:(NSString*)courseId{
    
    BOOL isExist = false;
    FMResultSet *queryResult = [self.db executeQuery:@"SELECT * FROM COURSEJSON_TABLE"];
    while ([queryResult next]) {
        NSString* temp_courseId = [queryResult stringForColumn:@"COURSEID"];
        if ([courseId isEqualToString:temp_courseId]) {//如果已经存在该数据，那就进行更新
            return isExist = true;
        }
    }
    return isExist;
}

//插入exaHistory数据
- (void)insertCourseJsonWithUserid:(NSString *)userid andCourseId:(NSString *)courseId andCourseJson:(NSString *)courseJson{
    
    BOOL result =  [self.db executeUpdate:@"INSERT INTO COURSEJSON_TABLE (USERID, COURSEID, COURSEJSON,) VALUES (?, ?, ?);",userid,courseId,courseJson];
    
    if (result) {
        NSLog(@"insert COURSEJSON_TABLE success!");
    }else{
        NSLog(@"insert COURSEJSON_TABLE fault!");
    }
}


-(NSMutableArray *)getAllCourseJson:(NSString *)userId
{
    NSMutableArray *jsonArray = [[NSMutableArray alloc]init];
    FMResultSet *queryResult =  [self.db executeQuery:@"SELECT * FROM COURSEJSON_TABLE WHERE USERID =?",userId];
    
    while ([queryResult next]) {
        
        NSString *courseJson = [queryResult stringForColumn:@"COURSEJSON"];
        
        [jsonArray addObject:courseJson];
    }
    return jsonArray ;
}

-(NSMutableArray *)getCourseJsonWithCourseId:(NSString *)courseId andUserId:(NSString *)userId
{
    
    FMResultSet *queryResult =  [self.db executeQuery:@"SELECT * FROM COURSEJSON_TABLE WHERE USERID =? and COURSEID =?",userId,courseId];
    
    NSMutableArray *jsonArray = [[NSMutableArray alloc]init];
    
    while ([queryResult next]) {
        
        NSString *courseJson = [queryResult stringForColumn:@"COURSEJSON"];
        
        [jsonArray addObject:courseJson];
    }
    return jsonArray ;
}


@end
