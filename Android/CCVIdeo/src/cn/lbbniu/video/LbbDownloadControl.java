package cn.lbbniu.video;


import cn.lbbniu.video.download.DownloadService.DownloadBinder;
import cn.lbbniu.video.util.ConfigUtil;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.IBinder;
import android.util.Log;


public class LbbDownloadControl {

	private Context mContext;
	private DownloadedReceiver receiver;
	private DownloadBinder binder;
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
	public LbbDownloadControl(Context context) {
		this.mContext = context;
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
}
