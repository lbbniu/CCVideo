package cn.lbbniu.video;

import android.content.pm.ActivityInfo;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.RelativeLayout;

import com.squareup.picasso.Picasso;
import com.uzmap.pkg.uzcore.UZWebView;
import com.uzmap.pkg.uzcore.annotation.UzJavascriptMethod;
import com.uzmap.pkg.uzcore.uzmodule.UZModule;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;

import fm.jiecao.jcvideoplayer_lib.JCMediaManager;
import fm.jiecao.jcvideoplayer_lib.JCUserAction;
import fm.jiecao.jcvideoplayer_lib.JCUserActionStandard;
import fm.jiecao.jcvideoplayer_lib.JCVideoPlayer;
import fm.jiecao.jcvideoplayer_lib.JCVideoPlayerStandard;
public class LbbCCVideo extends UZModule {
	private UZModuleContext mJsCallback;
	
	
	public LbbCCVideo(UZWebView webView) {
		super(webView);
		JCVideoPlayer.FULLSCREEN_ORIENTATION = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE;
		JCMediaManager.USERID = super.getFeatureValue("lbbVideo", "UserId");
		JCMediaManager.API_KEY = super.getFeatureValue("lbbVideo", "apiKey");
		JCMediaManager.MCONTEXT = getContext();
		JCVideoPlayer.setJcUserAction(new MyUserActionStandard());
	}
	
	JCVideoPlayerStandard mJcVideoPlayerStandard;
	/**
	 * 打开视频界面
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_open(final UZModuleContext moduleContext){	
		mJsCallback = moduleContext;
		if(null == mJcVideoPlayerStandard){			
			mJcVideoPlayerStandard = new JCVideoPlayerStandard(getContext());
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
		mJcVideoPlayerStandard.setUp(mJsCallback.optString("videoId") , JCVideoPlayerStandard.SCREEN_LAYOUT_NORMAL, mJsCallback.optString("title"));
		Picasso.with(mContext)
         .load("http://img4.jiecaojingxuan.com/2016/11/23/00b026e7-b830-4994-bc87-38f4033806a6.jpg@!640_360")
         .into(mJcVideoPlayerStandard.thumbImageView);
	}
	
	/**
	 * 关闭视频界面
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_close(final UZModuleContext moduleContext){
		if(mJcVideoPlayerStandard != null){
			mJcVideoPlayerStandard.releaseAllVideos();
			removeViewFromCurWindow(mJcVideoPlayerStandard);		
			mJcVideoPlayerStandard = null;
			mJsCallback = null;	
		}
	}
	
	/**
	 * 开始播放
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_start(final UZModuleContext moduleContext){	
		
	}
	
	
	/**
	 * 暂停播放
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_stop(final UZModuleContext moduleContext){	
		
	}
	
	/**
	 * 到指定位置播放
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_seekTo(final UZModuleContext moduleContext){	
		
	}
	
	
	class MyUserActionStandard implements JCUserActionStandard {
        @Override
        public void onEvent(int type, String url, int screen, Object... objects) {
            switch (type) {
                case JCUserAction.ON_CLICK_START_ICON:
                    Log.i("USER_EVENT", "ON_CLICK_START_ICON" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_CLICK_START_ERROR:
                    Log.i("USER_EVENT", "ON_CLICK_START_ERROR" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_CLICK_START_AUTO_COMPLETE:
                    Log.i("USER_EVENT", "ON_CLICK_START_AUTO_COMPLETE" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_CLICK_PAUSE:
                    Log.i("USER_EVENT", "ON_CLICK_PAUSE" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_CLICK_RESUME:
                    Log.i("USER_EVENT", "ON_CLICK_RESUME" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_SEEK_POSITION:
                    Log.i("USER_EVENT", "ON_SEEK_POSITION" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_AUTO_COMPLETE:
                    Log.i("USER_EVENT", "ON_AUTO_COMPLETE" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_ENTER_FULLSCREEN:
                    Log.i("USER_EVENT", "ON_ENTER_FULLSCREEN" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_QUIT_FULLSCREEN:
                    Log.i("USER_EVENT", "ON_QUIT_FULLSCREEN" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_ENTER_TINYSCREEN:
                    Log.i("USER_EVENT", "ON_ENTER_TINYSCREEN" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_QUIT_TINYSCREEN:
                    Log.i("USER_EVENT", "ON_QUIT_TINYSCREEN" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_TOUCH_SCREEN_SEEK_VOLUME:
                    Log.i("USER_EVENT", "ON_TOUCH_SCREEN_SEEK_VOLUME" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserAction.ON_TOUCH_SCREEN_SEEK_POSITION:
                    Log.i("USER_EVENT", "ON_TOUCH_SCREEN_SEEK_POSITION" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;

                case JCUserActionStandard.ON_CLICK_START_THUMB:
                    Log.i("USER_EVENT", "ON_CLICK_START_THUMB" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                case JCUserActionStandard.ON_CLICK_BLANK:
                    Log.i("USER_EVENT", "ON_CLICK_BLANK" + " title is : " + (objects.length == 0 ? "" : objects[0]) + " url is : " + url + " screen is : " + screen);
                    break;
                default:
                    Log.i("USER_EVENT", "unknow");
                    break;
            }
        }
    }
	
	@Override
	protected void onClean() {
		//timerTask.cancel();
		//isBind=false;
		//mContext.unregisterReceiver(mDownloadBroadcastReceiver);
	}
}
