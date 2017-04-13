package cn.lbbniu.video.download;

import java.util.HashMap;
import java.util.List;
import com.bokecc.sdk.mobile.download.Downloader;

public class LbbDownload {
	//定义hashmap存储downloader信息
	public static HashMap<String, Downloader> downloaderHashMap = new HashMap<String, Downloader>();
	
	
	//下载中的列表
	public static List<DownloadInfo> downloadingInfos = null;
}
