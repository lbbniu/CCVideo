package cn.lbbniu.video;




import java.util.List;
import java.util.Timer;

import org.json.JSONException;
import org.json.JSONObject;


import com.bokecc.sdk.mobile.download.Downloader;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;

import cn.lbbniu.video.download.DownloadInfo;
import cn.lbbniu.video.download.DownloadService;
import cn.lbbniu.video.download.DownloadService.DownloadBinder;
import cn.lbbniu.video.util.ConfigUtil;
import cn.lbbniu.video.util.DataSet;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.os.IBinder;
import android.util.Log;


public class LbbDownloadControl {

	private Context mContext;
	private UZModuleContext mJsmoduleContext;
	
	private Timer timter = new Timer();
	private Intent service;
	private DownloadBinder binder;
	
	private DownloadedReceiver receiver;
	
	
	private String videoId;
	private String title;
	private Downloader downloader;
	
	private ServiceConnection serviceConnection = new ServiceConnection() {
		@Override
		public void onServiceDisconnected(ComponentName name) {
			Log.i("service disconnected", name + "");
		}

		@Override
		public void onServiceConnected(ComponentName name, IBinder service) {
			binder = (DownloadBinder) service;
		}
	};
	
	
	
	/**
	 * 构造函数
	 */
	public LbbDownloadControl(Context mContext,UZModuleContext moduleContext) {
		this.mContext = mContext;
		this.mJsmoduleContext = moduleContext;
		
		//注册广播接收者
		IntentFilter intentFilter = new IntentFilter();
		//下载完成广播消息
		intentFilter.addAction(ConfigUtil.ACTION_DOWNLOADED);
		//下载中广播消息
		intentFilter.addAction(ConfigUtil.ACTION_DOWNLOADING);
		receiver = new DownloadedReceiver();
		mContext.registerReceiver(receiver, intentFilter);
		
		//绑定服务
		service = new Intent(mContext, DownloadService.class);
		mContext.bindService(service, serviceConnection,
				Context.BIND_AUTO_CREATE);
	}

	/**
	 * 
	 */
	private void getFinishList(){
		List<DownloadInfo> downloadInfos = DataSet.getDownloadInfos();
		//pairs = new ArrayList<Pair<String,Integer>>();
		for (DownloadInfo downloadInfo : downloadInfos) {
			if (downloadInfo.getStatus() != Downloader.FINISH) {
				continue;
			}
			//Pair<String, Integer> pair = new Pair<String, Integer>(downloadInfo.getTitle(), R.drawable.play);
			//pairs.add(pair);
		}
	}















	private class DownloadedReceiver extends BroadcastReceiver{

		@Override
		public void onReceive(Context context, Intent intent) {
			String action = intent.getAction();
			switch(action){
			case ConfigUtil.ACTION_DOWNLOADED://下载完成广播消息
				
				
				break;
			case ConfigUtil.ACTION_DOWNLOADING://下载中广播消息
				
				
				
				break;	
			}
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
}
