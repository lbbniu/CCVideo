CC视频播放和下载
--
# open
```
var video = api.require('ccVideo');
video.open({

},function(ret,err){

});
```

# close
关闭视频

# start
开始播放

# stop
暂停播放

# back
返回小视频

# seekTo
跳转到指定视频节点播放

# getCurrentPosition
获取视频播放进度

# startDownloadSvr
开始下载服务

# stopDownloadSvr
停止下载服务

# addDownloadVideo
向队列中增加视频

# downloadVideo
点击视频列表中的视频

# removeDownloadVideo
删除视频

# getDownloadingList
获取下载中的视频列表

```
var video = api.require('ccVideo');
video.getDownloadingList(function(ret,err){

});
```

# getDownloadedList
获取下载完成的视频列表

```
var video = api.require('ccVideo');
video.getDownloadedList(function(ret,err){

});
```