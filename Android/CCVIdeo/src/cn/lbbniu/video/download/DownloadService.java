package cn.lbbniu.video.download;

import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;
import android.app.Service;
import android.content.Intent;
import android.os.Binder;
import android.os.IBinder;
import android.util.Log;
import cn.lbbniu.video.util.ConfigUtil;
import cn.lbbniu.video.util.DataSet;
import cn.lbbniu.video.util.MediaUtil;
import cn.lbbniu.video.util.ParamsUtil;
import com.bokecc.sdk.mobile.download.DownloadListener;
import com.bokecc.sdk.mobile.download.Downloader;
import com.bokecc.sdk.mobile.exception.DreamwinException;

/**
 * DownloadService，用于支持后台下载
 * 
 * @author CC视频
 * 
 */
public class DownloadService extends Service {

	private final String TAG = "cn.lbbniu.video.download";
	private Map<String, Downloader> downloadMap = null;
	private final int MAX_COUNT = 2; // 最大并行下载量
	private Downloader downloader;
	private File file;
	private String title;
	private String videoId;
	private int progress;
	private String progressText;

	private boolean stop = true;
	private DownloadBinder binder = new DownloadBinder();

	private Timer timer = new Timer();
	private TimerTask timerTask;

	public class DownloadBinder extends Binder {

		public String getTitle() {
			return title;
		}

		public int getProgress() {
			return progress;
		}

		public String getProgressText() {
			return progressText;
		}

		public boolean isStop() {
			return stop;
		}

		public void pause() {
			if (downloader == null) {
				return;
			}
			downloader.pause();
		}

		public void download() {
			if (downloader == null) {
				return;
			}

			if (downloader.getStatus() == Downloader.WAIT) {
				downloader.start();
			}

			if (downloader.getStatus() == Downloader.PAUSE) {
				downloader.resume();
			}
		}

		public void cancel() {

			if (downloader == null) {
				return;
			}

			downloader.cancel();
		}

		public int getDownloadStatus() {
			if (downloader == null) {
				return Downloader.WAIT;
			}

			return downloader.getStatus();
		}
	}

	@Override
	public IBinder onBind(Intent intent) {
		return binder;
	}

	@Override
	public void onCreate() {
		super.onCreate();
		downloadMap = new HashMap<String, Downloader>();
	}

	private String getVideoId(String title) {
		if (title == null) {
			return null;
		}

		int charIndex = title.indexOf('-');

		if (-1 == charIndex) {
			return title;
		} else {
			return title.substring(0, charIndex);
		}
	}

	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {

		if (intent == null) {
			Log.i(TAG, "intent is null.");
			return android.app.Service.START_STICKY;
		}

		if (downloader != null) {
			Log.i(TAG, "downloader exists.");
			return android.app.Service.START_STICKY;
		}

		title = intent.getStringExtra("title");
		if (title == null) {
			Log.i(TAG, "title is null");
			return android.app.Service.START_STICKY;
		}

		videoId = getVideoId(title);
		if (videoId == null) {
			Log.i(TAG, "videoId is null");
			return android.app.Service.START_STICKY;
		}

		downloader = DataSet.downloaderHashMap.get(title);
		if (downloader == null) {
			file = MediaUtil.createFile(title);
			if (file == null) {
				Log.i(TAG, "File is null");
				return android.app.Service.START_STICKY;
			}
			downloader = new Downloader(file, videoId, ConfigUtil.USERID,
					ConfigUtil.API_KEY);
			DataSet.downloaderHashMap.put(title, downloader);
		}

		downloader.setDownloadListener(downloadListener);
		downloader.start();

		Intent notifyIntent = new Intent(ConfigUtil.ACTION_DOWNLOADING);
		notifyIntent.putExtra("status", Downloader.WAIT);
		notifyIntent.putExtra("title", title);
		sendBroadcast(notifyIntent);

		setUpNotification();
		stop = false;

		Log.i(TAG, "Start download service");
		return super.onStartCommand(intent, flags, startId);
	}

	@Override
	public void onTaskRemoved(Intent rootIntent) {

		if (downloader != null) {
			downloader.cancel();
			resetDownloadService();
		}
		super.onTaskRemoved(rootIntent);
	}

	private DownloadListener downloadListener = new DownloadListener() {
		@Override
		public void handleStatus(String videoId, int status) {
			Intent intent = new Intent(ConfigUtil.ACTION_DOWNLOADING);
			intent.putExtra("status", status);
			intent.putExtra("title", title);

			updateDownloadInfoByStatus(status);

			switch (status) {
			case Downloader.PAUSE:
				sendBroadcast(intent);

				Log.i(TAG, "pause");
				break;
			case Downloader.DOWNLOAD:
				sendBroadcast(intent);

				Log.i(TAG, "download");
				break;
			case Downloader.FINISH:
				// 下载完毕后变换通知形式
				// 通知更新
				// 停掉服务自身
				stopSelf();
				// 重置下载服务
				resetDownloadService();
				// 通知已下载队列
				sendBroadcast(new Intent(ConfigUtil.ACTION_DOWNLOADED));
				// 通知下载中队列
				sendBroadcast(intent);
				// 移除完成的downloader
				DataSet.downloaderHashMap.remove(title);
				Log.i(TAG, "download finished.");
				break;
			}
		}

		@Override
		public void handleProcess(long start, long end, String videoId) {
			if (stop) {
				return;
			}

			progress = (int) ((double) start / end * 100);
			if (progress <= 100) {
				progressText = ParamsUtil.byteToM(start).concat(" M / ")
						.concat(ParamsUtil.byteToM(end).concat(" M"));
			}
		}

		@Override
		public void handleException(DreamwinException exception, int status) {
			Log.i("Download exception", exception.getErrorCode().Value()
					+ " : " + title);
			// 停掉服务自身
			stopSelf();

			updateDownloadInfoByStatus(status);

			Intent intent = new Intent(ConfigUtil.ACTION_DOWNLOADING);
			intent.putExtra("errorCode", exception.getErrorCode().Value());
			intent.putExtra("title", title);
			sendBroadcast(intent);
		}

		@Override
		public void handleCancel(String videoId) {
			Log.i(TAG, "cancel download, title: " + title + ", videoId: "
					+ videoId);

			stopSelf();

			resetDownloadService();
		}
	};

	private void notifyProgress() {
		// 通知更新

	}

	private void setUpNotification() {
		// 指定个性化视图

		// 放置在"正在运行"栏目中

		if (timerTask != null) {
			timerTask.cancel();
		}
		timerTask = new TimerTask() {
			@Override
			public void run() {
				notifyProgress();
			}
		};
		timer.schedule(timerTask, 0, 1000);
	}

	private void resetDownloadService() {
		if (timerTask != null) {
			timerTask.cancel();
			timerTask = null;
		}
		progress = 0;
		progressText = null;
		downloader = null;
		stop = true;
	}

	private void updateDownloadInfoByStatus(int status) {
		DownloadInfo downloadInfo = DataSet.getDownloadInfo(title);
		if (downloadInfo == null) {
			return;
		}
		downloadInfo.setStatus(status);

		if (progress > 0) {
			downloadInfo.setProgress(progress);
		}

		if (progressText != null) {
			downloadInfo.setProgressText(progressText);
		}

		DataSet.updateDownloadInfo(downloadInfo);
	}

}
