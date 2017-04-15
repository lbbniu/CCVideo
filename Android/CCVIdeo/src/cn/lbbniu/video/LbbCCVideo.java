package cn.lbbniu.video;

import java.io.File;

import org.json.JSONException;
import org.json.JSONObject;

import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.os.Environment;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.RelativeLayout;
import cn.lbbniu.jcvideoplayer_lib.JCMediaManager;
import cn.lbbniu.jcvideoplayer_lib.JCUserAction;
import cn.lbbniu.jcvideoplayer_lib.JCUserActionStandard;
import cn.lbbniu.jcvideoplayer_lib.JCUtils;
import cn.lbbniu.video.download.DownloadService;
import cn.lbbniu.video.util.ConfigUtil;
import cn.lbbniu.video.util.DataSet;

import com.squareup.picasso.Picasso;
import com.uzmap.pkg.uzcore.UZWebView;
import com.uzmap.pkg.uzcore.annotation.UzJavascriptMethod;
import com.uzmap.pkg.uzcore.uzmodule.UZModule;
import com.uzmap.pkg.uzcore.uzmodule.UZModuleContext;

public class LbbCCVideo extends UZModule {
	private UZModuleContext mJsCallback;
	private UZModuleContext mJsCallbackDownload;
	private LbbVideoPlayerStandard mJcVideoPlayerStandard;
	private LbbDownloadControl lbbDownloadControl;
	private String userId;
	private String apiKey;

	public LbbCCVideo(UZWebView webView) {
		super(webView);
		LbbVideoPlayerStandard.FULLSCREEN_ORIENTATION = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE;
		LbbVideoPlayerStandard.NORMAL_ORIENTATION = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT;
		JCMediaManager.MCONTEXT = getContext();
		LbbVideoPlayerStandard.setJcUserAction(new MyUserActionStandard());
		userId = super.getFeatureValue("lbbVideo", "userId");
		apiKey = super.getFeatureValue("lbbVideo", "apiKey");
	}

	/**
	 * 打开视频界面
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_open(final UZModuleContext moduleContext) {
		mJsCallback = moduleContext;
		if (null == mJcVideoPlayerStandard) {
			mJcVideoPlayerStandard = new LbbVideoPlayerStandard(getContext());
		} else {
			mJcVideoPlayerStandard.release();
		}
		if (null == mJcVideoPlayerStandard.getParent()) {
			int x = moduleContext.optInt("x",0);
			int y = moduleContext.optInt("y",0);
			int w = moduleContext.optInt("w",0);
			int h = moduleContext.optInt("h",0);
			if (w == 0) {
				w = ViewGroup.LayoutParams.MATCH_PARENT;
			}
			if (h == 0) {
				h = ViewGroup.LayoutParams.MATCH_PARENT;
			}
			RelativeLayout.LayoutParams lp = new RelativeLayout.LayoutParams(w,
					h);
			lp.leftMargin = x;
			lp.topMargin = y;
			String fixedOn = moduleContext.optString("fixedOn");
			boolean fixed = moduleContext.optBoolean("fixed", true);
			if (fixedOn != "") {
				insertViewToCurWindow(mJcVideoPlayerStandard, lp, fixedOn,
						fixed, true);
			} else {
				insertViewToCurWindow(mJcVideoPlayerStandard, lp);
			}
		}
		JCMediaManager.isLocalPlay = moduleContext.optBoolean("isLocalPlay", false);
		JCMediaManager.USERID = moduleContext.optString("userId", userId);
		JCMediaManager.API_KEY = moduleContext.optString("apiKey", apiKey);
		String videoId = mJsCallback.optString("videoId");
		if(JCMediaManager.isLocalPlay){
			if (android.os.Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState())) {
				String path = Environment.getExternalStorageDirectory() + "/".concat(ConfigUtil.DOWNLOAD_DIR).concat("/").concat(videoId).concat(".mp4");
				if (new File(path).exists()) {
					videoId = path;
				} else {
					JCMediaManager.isLocalPlay = false;
				}
			}
		}
	
		
		mJcVideoPlayerStandard.setUp(videoId,
				LbbVideoPlayerStandard.SCREEN_LAYOUT_NORMAL,
				mJsCallback.optString("title"));
		// 视频缩略图
		String thumbImageUrl = moduleContext.optString("thumbImageUrl");
		if (thumbImageUrl != null) {
			Picasso.with(mContext).load(thumbImageUrl)
					.into(mJcVideoPlayerStandard.thumbImageView);
		}
		// 到指定位置播放
		int position = moduleContext.optInt("position", 0);
		if (position >= 0) {
			mJcVideoPlayerStandard.seekToInAdvance = position;
		}
		// 是否自动播放
		if (moduleContext.optBoolean("autoPlay", false)) {
			mJcVideoPlayerStandard.startButton.performClick();
		}

		// 是否全屏播放
		if (moduleContext.optBoolean("fullscreen", false)) {
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
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_close(final UZModuleContext moduleContext) {
		if (mJcVideoPlayerStandard != null) {
			JSONObject ret = getPostion();
			try {
				ret.put("status", 1);
				mJcVideoPlayerStandard.release();
				removeViewFromCurWindow(mJcVideoPlayerStandard);
				mJcVideoPlayerStandard = null;
				mJsCallback = null;
			} catch (JSONException e) {
				e.printStackTrace();
			}
			moduleContext.success(ret, true);	
		}
	}

	@UzJavascriptMethod
	public void jsmethod_back(final UZModuleContext moduleContext) {
		if (mJcVideoPlayerStandard != null) {
			LbbVideoPlayerStandard.backPress();
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
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_start(final UZModuleContext moduleContext) {
		if (mJcVideoPlayerStandard != null) {
			int currentState = mJcVideoPlayerStandard.currentState;
			if (currentState == LbbVideoPlayerStandard.CURRENT_STATE_NORMAL
					|| currentState == LbbVideoPlayerStandard.CURRENT_STATE_ERROR) {
				if (!mJcVideoPlayerStandard.url.startsWith("file")
						&& !JCUtils.isWifiConnected(getContext())
						&& !LbbVideoPlayerStandard.WIFI_TIP_DIALOG_SHOWED) {
					mJcVideoPlayerStandard.showWifiDialog();
					return;
				}
				mJcVideoPlayerStandard.prepareMediaPlayer();
				mJcVideoPlayerStandard
						.onEvent(currentState != LbbVideoPlayerStandard.CURRENT_STATE_ERROR ? JCUserAction.ON_CLICK_START_ICON
								: JCUserAction.ON_CLICK_START_ERROR);
			} else if (currentState == LbbVideoPlayerStandard.CURRENT_STATE_PAUSE) {
				mJcVideoPlayerStandard.onEvent(JCUserAction.ON_CLICK_RESUME);
				JCMediaManager.instance().mediaPlayer.start();
				mJcVideoPlayerStandard
						.setUiWitStateAndScreen(LbbVideoPlayerStandard.CURRENT_STATE_PLAYING);
			} else if (currentState == LbbVideoPlayerStandard.CURRENT_STATE_AUTO_COMPLETE) {
				mJcVideoPlayerStandard
						.onEvent(JCUserAction.ON_CLICK_START_AUTO_COMPLETE);
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
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_stop(final UZModuleContext moduleContext) {
		if (mJcVideoPlayerStandard != null) {
			int currentState = mJcVideoPlayerStandard.currentState;
			if (currentState == LbbVideoPlayerStandard.CURRENT_STATE_PLAYING) {
				mJcVideoPlayerStandard.onEvent(JCUserAction.ON_CLICK_PAUSE);
				JCMediaManager.instance().mediaPlayer.pause();
				mJcVideoPlayerStandard
						.setUiWitStateAndScreen(LbbVideoPlayerStandard.CURRENT_STATE_PAUSE);
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
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_seekTo(final UZModuleContext moduleContext) {
		if (mJcVideoPlayerStandard != null) {
			int position = moduleContext.optInt("position", 0);
			if (position >= 0
					&& position <= mJcVideoPlayerStandard.getDuration()) {
				mJcVideoPlayerStandard.seekTo(position);
			} else if (position >= 0) {
				mJcVideoPlayerStandard.seekToInAdvance = position;
			}
		}
	}

	/**
	 * 获取当前播放进度
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_getCurrentPosition(final UZModuleContext moduleContext) {
		if (mJcVideoPlayerStandard != null) {
			JSONObject ret = getPostion();
			try {
				ret.put("status", 1);
			} catch (JSONException e) {
				e.printStackTrace();
			}
			moduleContext.success(ret, true);
		}
	}

	public JSONObject getPostion() {
		JSONObject ret = new JSONObject();
		try {
			if (mJcVideoPlayerStandard != null) {
				int currentPosition = mJcVideoPlayerStandard
						.getCurrentPositionWhenPlaying();
				int duration = mJcVideoPlayerStandard.getDuration();
				ret.put("currentPosition", currentPosition);
				ret.put("duration", duration);
			} else {
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
					Log.i("USER_EVENT", "ON_CLICK_START_ICON" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_CLICK_START_ICON");
					break;
				case JCUserAction.ON_CLICK_START_ERROR:
					Log.i("USER_EVENT", "ON_CLICK_START_ERROR" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_CLICK_START_ERROR");
					break;
				case JCUserAction.ON_CLICK_START_AUTO_COMPLETE:
					Log.i("USER_EVENT", "ON_CLICK_START_AUTO_COMPLETE"
							+ " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_CLICK_START_AUTO_COMPLETE");
					break;
				case JCUserAction.ON_CLICK_PAUSE:
					Log.i("USER_EVENT", "ON_CLICK_PAUSE" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_CLICK_PAUSE");
					break;
				case JCUserAction.ON_CLICK_RESUME:
					ret.put("USER_EVENT", "ON_CLICK_RESUME");
					Log.i("USER_EVENT", "ON_CLICK_RESUME" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					break;
				case JCUserAction.ON_SEEK_POSITION:
					Log.i("USER_EVENT", "ON_SEEK_POSITION" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_SEEK_POSITION");
					break;
				case JCUserAction.ON_AUTO_COMPLETE:
					Log.i("USER_EVENT", "ON_AUTO_COMPLETE" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_AUTO_COMPLETE");
					break;
				case JCUserAction.ON_ENTER_FULLSCREEN:
					Log.i("USER_EVENT", "ON_ENTER_FULLSCREEN" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_ENTER_FULLSCREEN");
					break;
				case JCUserAction.ON_QUIT_FULLSCREEN:
					Log.i("USER_EVENT", "ON_QUIT_FULLSCREEN" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_QUIT_FULLSCREEN");
					break;
				case JCUserAction.ON_ENTER_TINYSCREEN:
					Log.i("USER_EVENT", "ON_ENTER_TINYSCREEN" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_ENTER_TINYSCREEN");
					break;
				case JCUserAction.ON_QUIT_TINYSCREEN:
					Log.i("USER_EVENT", "ON_QUIT_TINYSCREEN" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_QUIT_TINYSCREEN");
					break;
				case JCUserAction.ON_TOUCH_SCREEN_SEEK_VOLUME:
					Log.i("USER_EVENT", "ON_TOUCH_SCREEN_SEEK_VOLUME"
							+ " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_TOUCH_SCREEN_SEEK_VOLUME");
					break;
				case JCUserAction.ON_TOUCH_SCREEN_SEEK_POSITION:
					Log.i("USER_EVENT", "ON_TOUCH_SCREEN_SEEK_POSITION"
							+ " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					ret.put("USER_EVENT", "ON_TOUCH_SCREEN_SEEK_POSITION");
					break;

				case JCUserActionStandard.ON_CLICK_START_THUMB:
					ret.put("USER_EVENT", "ON_CLICK_START_THUMB");
					Log.i("USER_EVENT", "ON_CLICK_START_THUMB" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
					break;
				case JCUserActionStandard.ON_CLICK_BLANK:
					ret.put("USER_EVENT", "ON_CLICK_BLANK");
					Log.i("USER_EVENT", "ON_CLICK_BLANK" + " title is : "
							+ (objects.length == 0 ? "" : objects[0])
							+ " url is : " + url + " screen is : " + screen);
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

	/**
	 * 开启下载服务
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_startDownloadSvr(final UZModuleContext moduleContext) {
		if (lbbDownloadControl == null) {
			mJsCallbackDownload = moduleContext;
			lbbDownloadControl = new LbbDownloadControl(mContext, moduleContext);
			jscallback(moduleContext, 1, "服务启动成功", false);
		} else {
			jscallback(moduleContext, 0, "服务已经启动", true);
		}
	}

	/**
	 * 停止下载服务
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_stopDownloadSvr(final UZModuleContext moduleContext) {
		if (lbbDownloadControl != null) {
			lbbDownloadControl.onDestroy();
			lbbDownloadControl = null;
		}
		moduleContext.interrupt();
	}

	/**
	 * 添加下载视频
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_addDownloadVideo(final UZModuleContext moduleContext) {
		if (lbbDownloadControl != null) {
			ConfigUtil.USERID = moduleContext.optString("userId", userId);
			ConfigUtil.API_KEY = moduleContext.optString("apiKey", apiKey);
			lbbDownloadControl.addDownloadVideo(moduleContext
					.optString("videoId"));
			jscallback(moduleContext, 1, "成功", true);
		} else {
			jscallback(moduleContext, 0, "服务没有启动", true);
		}
	}

	/**
	 * 开始下载视频/暂停下载视频
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_downloadVideo(final UZModuleContext moduleContext) {
		if (lbbDownloadControl != null) {
			lbbDownloadControl.downloadVideo(moduleContext
					.optString("videoId"));
			jscallback(moduleContext, 1, "成功", true);
		} else {
			jscallback(moduleContext, 0, "服务没有启动", true);
		}
	}

	/**
	 * 删除指定视频
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_removeDownloadVideo(final UZModuleContext moduleContext) {
		if (lbbDownloadControl != null) {
			lbbDownloadControl.removeDownlowndVideo(moduleContext
					.optString("videoId"));
			jscallback(moduleContext, 1, "删除成功", true);
		} else {
			jscallback(moduleContext, 0, "服务没有启动", true);
		}
	}

	/**
	 * 获取下载中视频列表
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_getDownloadingList(final UZModuleContext moduleContext) {
		JSONObject json = new JSONObject();
		try {
			json.put("status", 1);
			json.put("data",
					new LbbDownloadControl(mContext).getDownloadingList());
		} catch (JSONException e) {
			e.printStackTrace();
		}
		moduleContext.success(json, true);
	}

	/**
	 * 获取下载完成视频列表
	 * 
	 * @param moduleContext
	 */
	@UzJavascriptMethod
	public void jsmethod_getDownloadedList(final UZModuleContext moduleContext) {
		JSONObject json = new JSONObject();
		try {
			json.put("status", 1);
			json.put("data",
					new LbbDownloadControl(mContext).getDownloadedList());
		} catch (JSONException e) {
			e.printStackTrace();
		}
		moduleContext.success(json, true);
	}

	private void jscallback(UZModuleContext moduleContext, int status,
			String msg, boolean del) {
		JSONObject json = new JSONObject();
		try {
			json.put("status", status);
			json.put("msg", msg);
		} catch (JSONException e) {
			e.printStackTrace();
		}
		moduleContext.success(json, del);
	}

	@Override
	protected void onClean() {
		if(mJcVideoPlayerStandard != null){
			mJcVideoPlayerStandard.release();
		}
		if (lbbDownloadControl != null) {
			lbbDownloadControl.onDestroy();
		}
		DataSet.saveData();
	}
}
