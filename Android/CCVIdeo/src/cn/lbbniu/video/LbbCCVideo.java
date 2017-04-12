package cn.lbbniu.video;

import java.io.File;
import java.util.Timer;
import java.util.TimerTask;

import org.json.JSONException;
import org.json.JSONObject;

import android.annotation.SuppressLint;
import android.app.AlertDialog;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.content.pm.ActivityInfo;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.RelativeLayout;


import cn.lbbniu.video.download.DownloadService;
import cn.lbbniu.video.util.ConfigUtil;
import cn.lbbniu.video.util.MediaUtil;
import cn.lbbniu.video.util.ParamsUtil;

import com.bokecc.sdk.mobile.download.Downloader;
import com.bokecc.sdk.mobile.exception.ErrorCode;
import com.squareup.picasso.Picasso;
import com.uzmap.pkg.uzcore.UZWebView;
import com.uzmap.pkg.uzcore.annotation.UzJavascriptMethod;
import com.uzmap.pkg.uzcore.uzmodule.UZModule;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;

import fm.jiecao.jcvideoplayer_lib.JCMediaManager;
import fm.jiecao.jcvideoplayer_lib.JCUserAction;
import fm.jiecao.jcvideoplayer_lib.JCUserActionStandard;
import fm.jiecao.jcvideoplayer_lib.JCUtils;
public class LbbCCVideo extends UZModule {
	private static final String ACTION_NAME = "aaaa";
	private UZModuleContext mJsCallback;
	private UZModuleContext mJsCallbackDownload;
	
	
	public LbbCCVideo(UZWebView webView) {
		super(webView);
		LBBVideoPlayerStandard.FULLSCREEN_ORIENTATION = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE;
		LBBVideoPlayerStandard.NORMAL_ORIENTATION = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT;
		JCMediaManager.USERID = super.getFeatureValue("lbbVideo", "UserId");
		JCMediaManager.API_KEY = super.getFeatureValue("lbbVideo", "apiKey");
		JCMediaManager.MCONTEXT = getContext();
		LBBVideoPlayerStandard.setJcUserAction(new MyUserActionStandard());
	}
	
	LBBVideoPlayerStandard mJcVideoPlayerStandard;
	/**
	 * 打开视频界面
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_open(final UZModuleContext moduleContext){	
		mJsCallback = moduleContext;
		if(null == mJcVideoPlayerStandard){			
			mJcVideoPlayerStandard = new LBBVideoPlayerStandard(getContext());
		}else{
			mJcVideoPlayerStandard.release();
		}
		if(null == mJcVideoPlayerStandard.getParent()){
			int x = moduleContext.optInt("x");
			int y = moduleContext.optInt("y");
			int w = moduleContext.optInt("w");
			int h = moduleContext.optInt("h");
			if(w == 0){
				w = ViewGroup.LayoutParams.MATCH_PARENT;
			}
			if(h == 0){
				h = ViewGroup.LayoutParams.MATCH_PARENT;
			}
			RelativeLayout.LayoutParams lp = new RelativeLayout.LayoutParams(w, h);
			lp.leftMargin = x;
			lp.topMargin = y;
			String fixedOn = moduleContext.optString("fixedOn");
			boolean fixed = moduleContext.optBoolean("fixed", true);
			if(fixedOn != ""){
				insertViewToCurWindow(mJcVideoPlayerStandard, lp, fixedOn, fixed, true);
			}else{
				insertViewToCurWindow(mJcVideoPlayerStandard, lp);
			}	
		}
		
		JCMediaManager.USERID = moduleContext.optString("UserId");
		JCMediaManager.API_KEY = moduleContext.optString("apiKey");
		mJcVideoPlayerStandard.setUp(mJsCallback.optString("videoId") , LBBVideoPlayerStandard.SCREEN_LAYOUT_NORMAL, mJsCallback.optString("title"));
		
		//视频缩略图
		String thumbImageUrl = moduleContext.optString("thumbImageUrl");	
		if(thumbImageUrl!=null){
			Picasso.with(mContext)
	         .load(thumbImageUrl)
	         .into(mJcVideoPlayerStandard.thumbImageView);
		}
		//到指定位置播放
		int position = moduleContext.optInt("position", 0);
		if(position >= 0){
			mJcVideoPlayerStandard.seekToInAdvance = position;
		}
		//是否自动播放
		if(moduleContext.optBoolean("autoPlay", false)){
			mJcVideoPlayerStandard.startButton.performClick();
		}
		
		//是否全屏播放
		if(moduleContext.optBoolean("fullscreen", false)){
			mJcVideoPlayerStandard.onEvent(JCUserAction.ON_ENTER_FULLSCREEN);
			mJcVideoPlayerStandard.startWindowFullscreen();
		}
		
		JSONObject ret = new JSONObject();
		try {
			ret.put("status", 1);
		} catch (JSONException e) {
			e.printStackTrace();
		}
		moduleContext.success(ret, false);
	}
	
	/**
	 * 关闭视频界面
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_close(final UZModuleContext moduleContext){
		if(mJcVideoPlayerStandard != null){
			JSONObject ret = getPostion();
			try {
				ret.put("status", 1);
			} catch (JSONException e) {
				e.printStackTrace();
			}
			moduleContext.success(ret, true);
			mJcVideoPlayerStandard.release();
			removeViewFromCurWindow(mJcVideoPlayerStandard);		
			mJcVideoPlayerStandard = null;
			mJsCallback = null;	
		}
	}
	@UzJavascriptMethod
	public void jsmethod_back(final UZModuleContext moduleContext){
		if(mJcVideoPlayerStandard != null){
			LBBVideoPlayerStandard.backPress();
			JSONObject ret = getPostion();
			try {
				ret.put("status", 1);
			} catch (JSONException e) {
				e.printStackTrace();
			}
			moduleContext.success(ret, true);
		}
	}
	
	
	/**
	 * 开始播放
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_start(final UZModuleContext moduleContext){	
		if(mJcVideoPlayerStandard != null){
			int  currentState = mJcVideoPlayerStandard.currentState;
			if (currentState == LBBVideoPlayerStandard.CURRENT_STATE_NORMAL || currentState == LBBVideoPlayerStandard.CURRENT_STATE_ERROR) {
                if (!mJcVideoPlayerStandard.url.startsWith("file") && !JCUtils.isWifiConnected(getContext()) && !LBBVideoPlayerStandard.WIFI_TIP_DIALOG_SHOWED) {
                		mJcVideoPlayerStandard.showWifiDialog();
                    return;
                }
                mJcVideoPlayerStandard.prepareMediaPlayer();
                mJcVideoPlayerStandard.onEvent(currentState != LBBVideoPlayerStandard.CURRENT_STATE_ERROR ? JCUserAction.ON_CLICK_START_ICON : JCUserAction.ON_CLICK_START_ERROR);
            } else if (currentState == LBBVideoPlayerStandard.CURRENT_STATE_PAUSE) {
            		mJcVideoPlayerStandard.onEvent(JCUserAction.ON_CLICK_RESUME);
                JCMediaManager.instance().mediaPlayer.start();
                mJcVideoPlayerStandard.setUiWitStateAndScreen(LBBVideoPlayerStandard.CURRENT_STATE_PLAYING);
            } else if (currentState == LBBVideoPlayerStandard.CURRENT_STATE_AUTO_COMPLETE) {
            		mJcVideoPlayerStandard.onEvent(JCUserAction.ON_CLICK_START_AUTO_COMPLETE);
            		mJcVideoPlayerStandard.prepareMediaPlayer();
            }
			JSONObject ret = getPostion();
			try {
				ret.put("status", 1);
			} catch (JSONException e) {
				e.printStackTrace();
			}
			moduleContext.success(ret, true);
		}
	}
	
	
	/**
	 * 暂停播放
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_stop(final UZModuleContext moduleContext){	
		if(mJcVideoPlayerStandard != null){
			int  currentState = mJcVideoPlayerStandard.currentState;
			if (currentState == LBBVideoPlayerStandard.CURRENT_STATE_PLAYING) {
            		mJcVideoPlayerStandard.onEvent(JCUserAction.ON_CLICK_PAUSE);
                JCMediaManager.instance().mediaPlayer.pause();
                mJcVideoPlayerStandard.setUiWitStateAndScreen(LBBVideoPlayerStandard.CURRENT_STATE_PAUSE);
            }
			JSONObject ret = getPostion();
			try {
				ret.put("status", 1);
			} catch (JSONException e) {
				e.printStackTrace();
			}
			moduleContext.success(ret, true);
		}
	}
	
	/**
	 * 到指定位置播放
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_seekTo(final UZModuleContext moduleContext){	
		if(mJcVideoPlayerStandard != null){
			int position = moduleContext.optInt("position", 0);
			if(position>=0 && position <= mJcVideoPlayerStandard.getDuration()){
				mJcVideoPlayerStandard.seekTo(position);
			}else if(position>=0){
				mJcVideoPlayerStandard.seekToInAdvance = position;
			}
		}
	}
	/**
	 * 获取当前播放进度
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_getCurrentPosition(final UZModuleContext moduleContext){	
		if(mJcVideoPlayerStandard != null){
			JSONObject ret = getPostion();
			try {
				ret.put("status", 1);
			} catch (JSONException e) {
				e.printStackTrace();
			}
			moduleContext.success(ret, true);
		}
	}
	
	
	public JSONObject getPostion(){
		JSONObject ret = new JSONObject();
		try {
			if(mJcVideoPlayerStandard != null){
				int currentPosition = mJcVideoPlayerStandard.getCurrentPositionWhenPlaying();
				int duration = mJcVideoPlayerStandard.getDuration();
				ret.put("currentPosition", currentPosition);
				ret.put("duration", duration);
			}else{
				ret.put("currentPosition", 0);
				ret.put("duration", 0);
			}
		} catch (JSONException e) {
			e.printStackTrace();
		}
		return ret;
	}
	
	
	class MyUserActionStandard implements JCUserActionStandard {
        @Override
        public void onEvent(int type, String url, int screen, Object... objects) {
        	JSONObject ret = getPostion();
        	try {
        		ret.put("status", 1);
	            switch (type) {
	                case JCUserAction.ON_CLICK_START_ICON:
	                    Log.i("USER_EVENT", "ON_CLICK_START_ICON" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
						ret.put("USER_EVENT", "ON_CLICK_START_ICON");
	                    break;
	                case JCUserAction.ON_CLICK_START_ERROR:
	                    Log.i("USER_EVENT", "ON_CLICK_START_ERROR" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    ret.put("USER_EVENT", "ON_CLICK_START_ERROR");
	                    break;
	                case JCUserAction.ON_CLICK_START_AUTO_COMPLETE:
	                    Log.i("USER_EVENT", "ON_CLICK_START_AUTO_COMPLETE" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    ret.put("USER_EVENT", "ON_CLICK_START_AUTO_COMPLETE");
	                    break;
	                case JCUserAction.ON_CLICK_PAUSE:
	                    Log.i("USER_EVENT", "ON_CLICK_PAUSE" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    ret.put("USER_EVENT", "ON_CLICK_PAUSE");
	                    break;
	                case JCUserAction.ON_CLICK_RESUME:
	                	ret.put("USER_EVENT", "ON_CLICK_RESUME");
	                	Log.i("USER_EVENT", "ON_CLICK_RESUME" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    break;
	                case JCUserAction.ON_SEEK_POSITION:
	                    Log.i("USER_EVENT", "ON_SEEK_POSITION" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    ret.put("USER_EVENT", "ON_SEEK_POSITION");
	                    break;
	                case JCUserAction.ON_AUTO_COMPLETE:
	                    Log.i("USER_EVENT", "ON_AUTO_COMPLETE" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    ret.put("USER_EVENT", "ON_AUTO_COMPLETE");
	                    break;
	                case JCUserAction.ON_ENTER_FULLSCREEN:
	                	Log.i("USER_EVENT", "ON_ENTER_FULLSCREEN" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                	ret.put("USER_EVENT", "ON_ENTER_FULLSCREEN");
	                	break;
	                case JCUserAction.ON_QUIT_FULLSCREEN:
	                    Log.i("USER_EVENT", "ON_QUIT_FULLSCREEN" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    ret.put("USER_EVENT", "ON_QUIT_FULLSCREEN");
	                    break;
	                case JCUserAction.ON_ENTER_TINYSCREEN:
	                    Log.i("USER_EVENT", "ON_ENTER_TINYSCREEN" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    ret.put("USER_EVENT", "ON_ENTER_TINYSCREEN");
	                    break;
	                case JCUserAction.ON_QUIT_TINYSCREEN:
	                    Log.i("USER_EVENT", "ON_QUIT_TINYSCREEN" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    ret.put("USER_EVENT", "ON_QUIT_TINYSCREEN");
	                    break;
	                case JCUserAction.ON_TOUCH_SCREEN_SEEK_VOLUME:
	                    Log.i("USER_EVENT", "ON_TOUCH_SCREEN_SEEK_VOLUME" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    ret.put("USER_EVENT", "ON_TOUCH_SCREEN_SEEK_VOLUME");
	                    break;
	                case JCUserAction.ON_TOUCH_SCREEN_SEEK_POSITION:
	                    Log.i("USER_EVENT", "ON_TOUCH_SCREEN_SEEK_POSITION" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    ret.put("USER_EVENT", "ON_TOUCH_SCREEN_SEEK_POSITION");
	                    break;
	
	                case JCUserActionStandard.ON_CLICK_START_THUMB:
	                	ret.put("USER_EVENT", "ON_CLICK_START_THUMB");
	                	Log.i("USER_EVENT", "ON_CLICK_START_THUMB" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    break;
	                case JCUserActionStandard.ON_CLICK_BLANK:
	                	ret.put("USER_EVENT", "ON_CLICK_BLANK");
	                	Log.i("USER_EVENT", "ON_CLICK_BLANK" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
	                    break;
	                default:
	                    Log.i("USER_EVENT", "unknow");
	                    ret.put("USER_EVENT", "unknow");
	                    break;
	            }
        	} catch (JSONException e) {
				e.printStackTrace();
			}
        	mJsCallback.success(ret, false);
        }
    }
	
	
	
	private ServiceConnection serviceConnection;
    private boolean isBind;
    private DownloadService.DownloadBinder binder;
	private Intent service;
	private BroadcastReceiver mBroadcastReceiver;
    private void bindServer() {
		service = new Intent(mContext, DownloadService.class);
		serviceConnection = new ServiceConnection() {
			@Override
			public void onServiceDisconnected(ComponentName name) {
				//Log.i("service disconnected", name + "");
			}

			@Override
			public void onServiceConnected(ComponentName name, IBinder service) {
				binder = (DownloadService.DownloadBinder) service;
				//Log.i("OO", "回调：===========binder = (DownloadBinder) service;======");
			}
		};
		mContext.bindService(service, serviceConnection,
				Context.BIND_AUTO_CREATE);
		//Log.i("OO", "回调：===========bindServer======");
	}
    public void registerBoradcastReceiver(){  
        IntentFilter myIntentFilter = new IntentFilter();  
        myIntentFilter.addAction(ACTION_NAME);  
        //myIntentFilter.addAction(BROCAST_CALLBACK);
        //注册广播        
        getContext().registerReceiver(mBroadcastReceiver, myIntentFilter);  
    } 

    private BroadcastReceiver mDownloadBroadcastReceiver = new BroadcastReceiver(){  
        private Object currentDownloadTitle;

		@Override  
        public void onReceive(Context context, Intent intent) {  
            String action = intent.getAction();  
            //Log.i("OO", "回调：=====================lbbniu====="+action);
            try {
	            JSONObject ret = new JSONObject();
	            if(action.equals(ConfigUtil.ACTION_DOWNLOADED)){//下载完成广播
	
	            }else if(action.equals(ConfigUtil.ACTION_DOWNLOADING)){//下载中广播          	
	            	if (isBind) {
	    				bindServer();
	    			}
	    			if (intent.getStringExtra("title") != null) {
	    				currentDownloadTitle = intent.getStringExtra("title");
	    			}
	    			int downloadStatus = intent.getIntExtra("status", ParamsUtil.INVALID);
	    			
    				ret.put("status",downloadStatus);
    				ret.put("progress", binder.getProgress());
	    			// 若当前状态为下载中，则重置view的标记位置
	    			if (downloadStatus == Downloader.DOWNLOAD || downloadStatus ==Downloader.WAIT) {
	    				 //Log.i("OO", "回调：=========llllllll============Downloader.DOWNLOAD====="+downloadStatus);
	    				//currentDownloadTitle = null;
	    				 return ;
	    			}
	    			if (downloadStatus == Downloader.PAUSE) {
	    				//currentDownloadTitle = null;
	    				 if(mJsCallbackDownload != null){
	    					 	//Log.i("OO", "回调：=========llllllll============Downloader.PAUSE====="+downloadStatus);
	    	        			mJsCallbackDownload.success(ret, false);
    	        		 }
	    				 return ;
	    			}   			   			
	    			// 若当前状态为下载完成，且下载队列不为空，则启动service下载其他视频
	    			if (downloadStatus == Downloader.FINISH) {	    			
    	        		ret.put("videoId", currentDownloadTitle);
    	        		ret.put("status", 1);
    	        		ret.put("progress", 100);
    	        		ret.put("finish", "YES");
    	        		 AlertDialog.Builder builder = new AlertDialog.Builder(mContext);
    	        		 AlertDialog.OnClickListener onClickListener = new AlertDialog.OnClickListener() {
    	        				@Override
    	        				public void onClick(DialogInterface dialog, int which) {
    	        					//finish();
    	        				}

    	        			};
    	 				//builder.setTitle("提示").setPositiveButton("OK", onClickListener).setMessage(currentDownloadTitle).setCancelable(false).show();
    	        		if(mJsCallbackDownload != null){
    	        			//Log.i("OO", "回调：========="+currentDownloadTitle+"============Downloader.FINISH====="+downloadStatus);
    	        			mJsCallbackDownload.success(ret, true);
    	        		}
	    				return ;
	    			}
	    			
	    			// 若下载出现异常，提示用户处理
        			int errorCode = intent.getIntExtra("errorCode", ParamsUtil.INVALID);
        			ret.put("errorCode",errorCode);
        			ret.put("videoId",currentDownloadTitle);
        			ret.put("finish", "NO");
        			if (errorCode == ErrorCode.NETWORK_ERROR.Value()) {
        				//Toast.makeText(context, "网络异常，请检查", Toast.LENGTH_SHORT).show();
        				ret.put("status", 0);
        			} else if (errorCode == ErrorCode.PROCESS_FAIL.Value()) {
        				//Toast.makeText(context, "下载失败，请重试", Toast.LENGTH_SHORT).show();
        				ret.put("status", 0);
        			} else if (errorCode == ErrorCode.INVALID_REQUEST.Value()) {
        				//Toast.makeText(context, "下载失败，请检查帐户信息", Toast.LENGTH_SHORT).show();
        				ret.put("status", 0);
        			}
	        		if(mJsCallbackDownload != null){
	        			ret.put("status", 0);
	        			//Log.i("OO", "回调：=========INVALID_REQUEST============Downloader.FINISH====="+downloadStatus);
	        			mJsCallbackDownload.success(ret, false);
	        		}
	            } 
            } catch (JSONException e) {
				e.printStackTrace();
			}
        }  
          
    };
    private Timer timter = new Timer();
	private String currentDownloadTitle;
    @UzJavascriptMethod
	public void jsmethod_initDownload(final UZModuleContext moduleContext){
    	timter.schedule(timerTask, 0, 1000);
    	IntentFilter myIntentFilter = new IntentFilter();  
        //myIntentFilter.addAction(BROCAST_CALLBACK);
        myIntentFilter.addAction(ConfigUtil.ACTION_DOWNLOADED);
        myIntentFilter.addAction(ConfigUtil.ACTION_DOWNLOADING);
       //注册广播        
        mContext.registerReceiver(mDownloadBroadcastReceiver, myIntentFilter);  
        bindServer();
    }
    
    @UzJavascriptMethod
	public void jsmethod_download(final UZModuleContext moduleContext){
    	String videoId = moduleContext.optString("videoId");
    	String userId = moduleContext.optString("UserId");
    	String apiKey = moduleContext.optString("apiKey");
    	int isEncryption = moduleContext.optInt("isEncryption",0);
    	//启动服务进行下载
    	if(isBind){
    		bindServer();
    	}
    	if(binder == null || binder.isStop()){
    		Intent service = new Intent(getContext(), DownloadService.class);
			service.putExtra("title",videoId);
			service.putExtra("userId",userId);
			service.putExtra("apiKey",apiKey);
			service.putExtra("isEncryption",isEncryption);
			getContext().startService(service);
			currentDownloadTitle = videoId;
    	}else if(videoId.equals(currentDownloadTitle)){
    		switch (binder.getDownloadStatus()) {
			case Downloader.PAUSE:
				binder.download();
				break;
			case Downloader.WAIT:
				binder.download();
				break;
			}
    	}else{//取消下载，开始新的下载
    		binder.cancel();
    		Intent service = new Intent(mContext, DownloadService.class);
			service.putExtra("title",videoId);
			service.putExtra("userId",userId);
			service.putExtra("apiKey",apiKey);
			service.putExtra("isEncryption",isEncryption);
			mContext.startService(service);
			currentDownloadTitle = videoId;
    	}   	
    	mJsCallbackDownload = moduleContext;  	
	}
    public void jsmethod_downloadStop(final UZModuleContext moduleContext){    
    	//Log.i("OO", "回调：=＝＝＝＝＝＝＝＝jsmethod_downloadStop＝＝＝＝＝＝＝＝＝＝＝");
    	JSONObject ret = new JSONObject();
    	try {
    		if(!binder.isStop() && currentDownloadTitle != null){
        		binder.pause();
        	}
    		ret.put("status", 1);
			moduleContext.success(ret, true);
		} catch (JSONException e) {
			e.printStackTrace();
		}
	}
    public void jsmethod_downloadStart(final UZModuleContext moduleContext){
    	//Log.i("OO", "回调：=＝＝＝＝＝＝＝＝jsmethod_downloadStart＝＝＝＝＝＝＝＝＝＝＝");
    	JSONObject ret = new JSONObject();
    	try {
    		if(binder.isStop() && currentDownloadTitle != null){
        		binder.download();
        	}
    		ret.put("status", 1);
			moduleContext.success(ret, true);
		} catch (JSONException e) {
			e.printStackTrace();
		}
	}
    private int currentProgress = 0;	
    @SuppressLint("HandlerLeak") 
    private Handler handler = new Handler() {	
		@Override
		public void handleMessage(Message msg) {
			String title = (String) msg.obj;
			
			if (title == null) {
				return;
			}		
			int progress = binder.getProgress();
			if (progress > 0) {
				
				if (currentProgress == progress || binder.getDownloadStatus() == Downloader.FINISH) {
					return;
				}
				
				currentProgress = progress;
				if(mJsCallbackDownload!=null){
					JSONObject ret = new JSONObject();
	            	try {
						ret.put("videoId", currentDownloadTitle);
						ret.put("progress", progress);
						ret.put("finish", "NO");
						ret.put("status", 1);	
						if(binder.getDownloadStatus() == Downloader.DOWNLOAD){
							//Log.i("OO", "回调：=＝＝＝＝＝＝＝＝"+currentDownloadTitle+"＝＝＝＝＝＝＝＝＝＝＝"+progress);
							mJsCallbackDownload.success(ret, false);
						}
					} catch (JSONException e) {
						e.printStackTrace();
					}
				}
			}
			super.handleMessage(msg);
		}
	};
    // 通过定时器和Handler来更新进度条
 	private TimerTask timerTask = new TimerTask() {

		@Override
 		public void run() {
 			//Log.i("OO", "回调：=＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝＝");
 			if (binder == null || binder.isStop()) {
 				return;
 			}
 			// 判断是否存在正在下载的视频
 			if (currentDownloadTitle == null) {
 				currentDownloadTitle = binder.getTitle();
 			}
 			
			if (currentDownloadTitle == null) {
 				return;
 			}
 			
 			Message msg = new Message();
 			msg.obj = currentDownloadTitle;

 			handler.sendMessage(msg);
 		}
 	};
	public void jsmethod_rmVideo(final UZModuleContext moduleContext){
		String videoId = moduleContext.optString("videoId");
		File file = MediaUtil.createFile(videoId);
    	if(file!=null&&file.exists()){
    		file.delete();
    	}
		moduleContext.interrupt();
	}
	
	
	
	@Override
	protected void onClean() {
		//timerTask.cancel();
		//isBind=false;
		//mContext.unregisterReceiver(mDownloadBroadcastReceiver);
		LBBVideoPlayerStandard.releaseAllVideos();
	}
}
