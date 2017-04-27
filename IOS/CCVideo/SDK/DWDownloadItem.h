#import <Foundation/Foundation.h>
#import "DWDownloader.h"
enum {
    DWDownloadStatusWait = 100,
    DWDownloadStatusStart = 200,
    DWDownloadStatusDownloading =250,
    DWDownloadStatusPause = 300,
    DWDownloadStatusFinish = 400,
    DWDownloadStatusFail = 150
};

typedef NSInteger DWDownloadStatus;
@interface DWDownloadItem : NSObject
@property (strong, nonatomic)NSString *videoId;
@property (strong, nonatomic)DWDownloader *downloader;
@property (assign, nonatomic)DWDownloadStatus videoDownloadStatus;
@property (assign, nonatomic)NSTimeInterval time;
@property (assign, nonatomic)int count;


@property (strong, nonatomic)NSString *definition;
@property (strong, nonatomic)NSString *videoPath;
@property (assign, nonatomic)NSInteger videoFileSize;
@property (assign, nonatomic)NSInteger videoDownloadedSize;
@property (assign, nonatomic)float videoDownloadProgress;




- (id)initWithVideoId:(NSString *)videoId;
- (NSDictionary *)getItemDictionary;


- (NSInteger)getFileSizeWithPath:(NSString *)filePath Error:(NSError **)error;
- (id)initWithItem:(NSDictionary *)item;

- (NSDictionary *)getItemDictionary;
- (NSString*)description;

@end

@interface DWDownloadItems : NSObject

@property (strong, nonatomic)NSMutableArray *items;
@property (assign, atomic)BOOL isBusy;

- (id)initWithPath:(NSString *)path;

- (void)removeObjectAtIndex:(NSUInteger)index;

- (BOOL)writeToPlistFile:(NSString*)filename;

@end