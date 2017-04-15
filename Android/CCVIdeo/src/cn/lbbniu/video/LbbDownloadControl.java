package cn.lbbniu.video;

import java.io.File;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONStringer;

import com.bokecc.sdk.mobile.download.Downloader;
import com.bokecc.sdk.mobile.exception.ErrorCode;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;
import cn.lbbniu.video.download.DownloadInfo;
import cn.lbbniu.video.download.DownloadService;
import cn.lbbniu.video.download.DownloadService.DownloadBinder;
import cn.lbbniu.video.download.DownloadingInfo;
import cn.lbbniu.video.util.ConfigUtil;
import cn.lbbniu.video.util.DataSet;
import cn.lbbniu.video.util.MediaUtil;
import cn.lbbniu.video.util.ParamsUtil;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.util.Log;
import android.widget.Toast;


public class LbbDownloadControl {
	//定义hashmap存储downloader信息
	public static HashMap<String, Downloader> downloaderHashMap = new HashMap<String, Downloader>();
		
	private Context mContext;
	private UZModuleContext mJsmoduleContext;
	
	private Timer timter = new Timer();
	private Intent service;
	private DownloadBinder binder;
	private DownloadedReceiver receiver;
	
	//已经下载的视频列表
	private List<DownloadInfo> downloadedInfos;
	//下载中的视频列表信息
	private List<DownloadInfo> downloadingInfos;
	
	private Downloader downloader;
	
	private ServiceConnection serviceConnection;
	private Handler handler = new Handler() {
		private Map<String, Integer>  currentProgress = new HashMap<String, Integer>();
		@Override
		public void handleMessage(Message msg) {
			String title = (String) msg.obj;
			if (title == null || downloadingInfos.isEmpty()) {
				return;
			}
			int currentPosition = resetHandlingTitle(title);
			int progress = binder.getProgress(title);
			Log.d("lbbniu", "handleMessage_____title="+title+",progress="+progress);
			if (progress > 0 && currentPosition != ParamsUtil.INVALID) {
				if(currentProgress.containsKey(title) && currentProgress.get(title) == progress){
					return ;
				}
				currentProgress.put(title, progress);
				DownloadInfo downloadInfo = downloadingInfos.remove(currentPosition);
				DownloadingInfo downloadingInfo = binder.getDownloadingInfo(title);
				if(downloadingInfo != null){
					Log.d("lbbniu", "setProgressText="+downloadingInfo.getProgressText());
					downloadInfo.setProgress(downloadingInfo.getProgress());
					downloadInfo.setDownloadSize(downloadingInfo.getStart());
					downloadInfo.setFileSize(downloadingInfo.getEnd());
					downloadInfo.setProgressText(downloadingInfo.getProgressText());
				}
				DataSet.updateDownloadInfo(downloadInfo);		
				downloadingInfos.add(currentPosition, downloadInfo);
				//回调给js 刷新UI界面
				JSONObject json = new JSONObject();
				try {
					json.put("status", 1);
					json.put("action", ConfigUtil.ACTION_DOWNLOADING);
					json.put("data", createJSONArray(downloadingInfos));
				} catch (JSONException e) {
					e.printStackTrace();
				}
				jscallback(mJsmoduleContext,json,false);
			}

			super.handleMessage(msg);
		}
		
		private int resetHandlingTitle(String title){
			int currentPosition = ParamsUtil.INVALID;
			for(DownloadInfo d : downloadingInfos){
				if (d.getTitle().equals(title)) {
					currentPosition = downloadingInfos.indexOf(d);
					break;
				}
			}
			return currentPosition;
		}

	};
	/**
	 * 构造函数
	 */
	public LbbDownloadControl(Context mContext) {
		this.mContext = mContext;
		
	}
	/**
	 * 构造函数
	 */
	public LbbDownloadControl(Context mContext,UZModuleContext moduleContext) {
		this.mContext = mContext;
		this.mJsmoduleContext = moduleContext;
		timter.schedule(timerTask, 0, 1000);
		Log.d("lbbniu","---------LbbDownloadControl--------------");
		registerReceiver();//注册广播
		bindServer();//绑定服务
	}
	
	/**
	 * 注册广播
	 */
	private void registerReceiver(){
		//注册广播接收者
		IntentFilter intentFilter = new IntentFilter();
		//下载完成广播消息
		intentFilter.addAction(ConfigUtil.ACTION_DOWNLOADED);
		//下载中广播消息
		intentFilter.addAction(ConfigUtil.ACTION_DOWNLOADING);
		receiver = new DownloadedReceiver();
		mContext.registerReceiver(receiver, intentFilter);
	}
	
	/**
	 * 绑定服务
	 */
	public void bindServer() {
		service = new Intent(mContext, DownloadService.class);
		serviceConnection = new ServiceConnection() {
			@Override
			public void onServiceDisconnected(ComponentName name) {
				Log.i("service disconnected", name + "");
			}

			@Override
			public void onServiceConnected(ComponentName name, IBinder service) {
				binder = (DownloadBinder) service;
			}
		};
		mContext.bindService(service, serviceConnection,
				Context.BIND_AUTO_CREATE);
		Log.d("lbbniu","---------bindServer--------------");
	}
	
	
	/**
	 * 获取已经下载完成的列表
	 * @return
	 */
	public JSONArray getDownloadedList(){
		List<DownloadInfo> downloadInfos = DataSet.getDownloadInfos();
		downloadedInfos = new ArrayList<DownloadInfo>();
		for (DownloadInfo downloadInfo : downloadInfos) {
			if (downloadInfo.getStatus() != Downloader.FINISH) {
				continue;
			}
			downloadedInfos.add(downloadInfo);
		}
		return createJSONArray(downloadedInfos);
	}
	
	/**
	 * 获取下载列表
	 * @return
	 */
	public JSONArray getDownloadingList(){
		List<DownloadInfo> downloadInfos = DataSet.getDownloadInfos();
		downloadingInfos = new ArrayList<DownloadInfo>();
		for (DownloadInfo downloadInfo : downloadInfos) {
			if (downloadInfo.getStatus() == Downloader.FINISH) {
				continue;
			}
			if ((downloadInfo.getStatus() == Downloader.DOWNLOAD) && (binder == null || (binder.isFree()&&!binder.exists(downloadInfo.getVideoId())))) {
				Intent service = new Intent(mContext, DownloadService.class);
				service.putExtra("title", downloadInfo.getTitle());
				mContext.startService(service);
			}
			downloadingInfos.add(downloadInfo);
		}
		return createJSONArray(downloadingInfos);
	}
	/**
	 * 添加下载视频到队列中
	 */
	public void addDownloadVideo(String videoId){
		addDownloadVideo(videoId, ConfigUtil.USERID, ConfigUtil.API_KEY, -1);
	}
	public void addDownloadVideo(String videoId, String userId, String apiKey){
		addDownloadVideo(videoId, videoId, userId, -1);
	}
	/**
	 * 添加下载视频到队列中
	 * @param videoId
	 * @param userId
	 * @param apiKey
	 * @param definition
	 */
	public void addDownloadVideo(String videoId, String userId, String apiKey, int definition){
		String title = videoId;
		if (DataSet.hasDownloadInfo(title)) {
			Toast.makeText(mContext, "文件已存在", Toast.LENGTH_SHORT).show();
			return;
		}
		
		File file = MediaUtil.createFile(title);
		if (file == null ){
			Toast.makeText(mContext, "创建文件失败", Toast.LENGTH_LONG).show();
			return;
		}
		downloader = new Downloader(file, videoId, userId, apiKey);
		if(definition == -1){
			DataSet.addDownloadInfo(new DownloadInfo(videoId, title, 0, null, Downloader.WAIT, new Date()));
		} else {
			downloader.setDownloadDefinition(definition);
			DataSet.addDownloadInfo(new DownloadInfo(videoId, title, 0, 0 , 0,null, Downloader.WAIT, new Date(), definition));
		}
		
		downloaderHashMap.put(title, downloader);
		
		if (binder == null || binder.isFree()) {
			Intent service = new Intent(mContext, DownloadService.class);
			service.putExtra("title", title);
			mContext.startService(service);
			Log.d("lbbniu", "DownloadService--------startService");
		} else{
			Log.d("lbbniu", "DownloadService--------sendBroadcast");
			Intent intent = new Intent(ConfigUtil.ACTION_DOWNLOADING);
			mContext.sendBroadcast(intent);
		}
		Toast.makeText(mContext, "文件已加入下载队列", Toast.LENGTH_SHORT).show();
	}
	
	/**
	 * 删除下载的视频
	 */
	public boolean removeDownlowndVideo(String videoId){
		// 删除数据库记录
		DataSet.removeDownloadInfo(videoId);
		File file = MediaUtil.createFile(videoId);
		if(file!=null && file.exists()){
			file.delete();
		}
		// 通知service取消下载
		if (binder!=null && binder.exists(videoId)) {
			binder.cancel(videoId);
			startWaitStatusDownload();
		}
		//TODO: 回调给js 下载列表数据 刷新UI 下载完成和下载中
		JSONObject json = new JSONObject();
		try {
			json.put("status", 1);
			json.put("action", ConfigUtil.ACTION_DOWNLOADED);
			json.put("data", getDownloadedList());
		} catch (JSONException e) {
			e.printStackTrace();
		}
		jscallback(mJsmoduleContext,json,false);
		json = new JSONObject();
		try {
			json.put("status", 1);
			json.put("action", ConfigUtil.ACTION_DOWNLOADING);
			json.put("data", getDownloadingList());
		} catch (JSONException e) {
			e.printStackTrace();
		}
		jscallback(mJsmoduleContext,json,false);
		return true;
	}
	
	/**
	 * 下载列表中视频的点击后调用
	 * @param videoId
	 */
	public void downloadVideo(String videoId){
		if (binder.exists(videoId)) {
			switch (binder.getDownloadStatus(videoId)) {
			case Downloader.PAUSE:
				binder.download(videoId);
				break;
			case Downloader.DOWNLOAD:
				binder.pause(videoId);
				break;
			}
		} else if (binder.isFree()) {
			//若下载任务已停止，则下载新数据	
			Intent service = new Intent(mContext, DownloadService.class);
			service.putExtra("title", videoId);
			mContext.startService(service);					
		}
	}
	
	
	/**
	 * app 启动的时候只调用一次
	 */
	public static void initDownloaderHashMap(){
		//初始化DownloaderHashMap
		List<DownloadInfo> downloadInfoList = DataSet.getDownloadInfos();
		int length = downloadInfoList.size();
		for(int i = 0; i<length; i++){
			DownloadInfo downloadInfo = downloadInfoList.get(i);
			if (downloadInfo.getStatus() == Downloader.FINISH) {
				continue;
			}
			
			String title = downloadInfo.getTitle();
			File file = MediaUtil.createFile(title);
			if (file == null ){
				continue;
			}
			
			String videoId = downloadInfo.getVideoId();
			Downloader downloader = new Downloader(file, videoId, ConfigUtil.USERID, ConfigUtil.API_KEY);
			
			int downloadInfoDefinition = downloadInfo.getDefinition();
			if (downloadInfoDefinition != -1){
				downloader.setDownloadDefinition(downloadInfoDefinition);
			}
			LbbDownloadControl.downloaderHashMap.put(title, downloader);
		}
	}
	
	// 通过定时器和Handler来更新进度条
	private TimerTask timerTask = new TimerTask() {
		@Override
		public void run() {
			
			if (binder == null || binder.isStop()) {
				return;
			}
			// 判断是否存在正在下载的视频
			String[] videos = binder.getTitles();
			for(int i = videos.length-1;i>=0;i--){
				Message msg = new Message();
				msg.obj = videos[i];
				handler.sendMessage(msg);
			}
		}
	};
	private class DownloadedReceiver extends BroadcastReceiver{

		@Override
		public void onReceive(Context context, Intent intent) {
			JSONObject json = new JSONObject();
			try {
				String action = intent.getAction();
				json.put("action",action);
				json.put("status",1);
				switch(action){
				case ConfigUtil.ACTION_DOWNLOADED://下载完成广播消息
					//回调给js 来更新已下载列表
					json.put("data", getDownloadedList());
					Log.d("lbbniu", "ACTION_DOWNLOADED_____下载完成");
					break;
				case ConfigUtil.ACTION_DOWNLOADING://下载中广播消息
					int downloadStatus = intent.getIntExtra("status", ParamsUtil.INVALID);
					//回调给js 下载列表数据 更新UI
					json.put("data", getDownloadingList());
					Log.d("lbbniu", "ACTION_DOWNLOADING_____下载中__"+downloadStatus);
					// 若当前状态为下载完成，且下载队列不为空，则启动service下载其他视频
					if (downloadStatus == Downloader.FINISH) {
						//TODO: 更新视频状态数据 
						//String title  = intent.getStringExtra("title");
						if (!downloadingInfos.isEmpty()) {
							startWaitStatusDownload();
						}
					}else if(downloadStatus == Downloader.PAUSE){
						if (!downloadingInfos.isEmpty()) {
							startWaitStatusDownload();
						}
					}
					// 若下载出现异常，提示用户处理
					int errorCode = intent.getIntExtra("errorCode", ParamsUtil.INVALID);
					if (errorCode == ErrorCode.NETWORK_ERROR.Value()) {
						Toast.makeText(context, "网络异常，请检查", Toast.LENGTH_SHORT).show();
					} else if (errorCode == ErrorCode.PROCESS_FAIL.Value()) {
						Toast.makeText(context, "下载失败，请重试", Toast.LENGTH_SHORT).show();
					} else if (errorCode == ErrorCode.INVALID_REQUEST.Value()) {
						Toast.makeText(context, "下载失败，请检查帐户信息", Toast.LENGTH_SHORT).show();
					}
					if(errorCode != ParamsUtil.INVALID){
						jscallback(mJsmoduleContext, "{status:0,errorCode:"+errorCode+"}", false);
					}
					break;	
				}
			} catch (JSONException e) {
				e.printStackTrace();
			}
			jscallback(mJsmoduleContext,json,false);
		}
	}
	/**
	 * 开始等待中视频开始下载
	 */
	private void startWaitStatusDownload() {
		for (DownloadInfo downloadInfo: downloadingInfos) {
			if (downloadInfo.getStatus() == Downloader.WAIT) {
				String currentDownloadTitle = downloadInfo.getTitle();
				Intent service = new Intent(mContext, DownloadService.class);
				service.putExtra("title", currentDownloadTitle);
				mContext.startService(service);
				break;
			}
		}
	}
	public void onDestroy() {
		if(receiver!=null){
			mContext.unregisterReceiver(receiver);
		}
		if(serviceConnection!=null){
			mContext.unbindService(serviceConnection);
		}
	}
	
	public void jscallback(UZModuleContext moduleContext,String json,boolean del){
		if(moduleContext != null){
			try {
				JSONObject obj = new JSONObject(json);
				moduleContext.success(obj, del);
			} catch (JSONException e) {
				e.printStackTrace();
			}
		}
	}
	public void jscallback(UZModuleContext moduleContext,JSONObject obj,boolean del){
		if(moduleContext != null){
			moduleContext.success(obj, del);
		}
	}
	private JSONArray createJSONArray(List<DownloadInfo> list){
		JSONArray array = new JSONArray();
		int length = list.size();
		DownloadInfo downloadInfo;
		try {
			for(int i=0; i<length; i++){
				JSONObject obj = new JSONObject();
				downloadInfo = list.get(i);
				obj.put("id", downloadInfo.getId());
				obj.put("title", downloadInfo.getTitle());
				obj.put("videoId", downloadInfo.getVideoId());
				obj.put("status", downloadInfo.getStatus());
				obj.put("progress", downloadInfo.getProgress());
				obj.put("downloadSize", ParamsUtil.byteToM(downloadInfo.getDownloadSize()));
				obj.put("fileSize", ParamsUtil.byteToM(downloadInfo.getFileSize()));
				obj.put("progressText", downloadInfo.getProgressText());
				obj.put("definition", downloadInfo.getDefinition());
				obj.put("statusInfo", downloadInfo.getStatusInfo());
				//obj.put("createTime", downloadInfo.getCreateTime());
				array.put(obj);
			}
		} catch (JSONException e) {
			e.printStackTrace();
		}
		return array;
	}
}
