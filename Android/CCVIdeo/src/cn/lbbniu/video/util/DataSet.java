package cn.lbbniu.video.util;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.bokecc.sdk.mobile.download.Downloader;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;



import cn.lbbniu.video.download.DownloadInfo;
public class DataSet {
	private final static String DOWNLOADINFO = "downloadinfo";
	private final static String VIDEOPOSITION = "videoposition";
	private static Map<String, DownloadInfo> downloadInfoMap;
	//定义hashmap存储downloader信息
	public static LinkedHashMap<String, Downloader> downloaderHashMap = new LinkedHashMap<String, Downloader>();
	
	private static SQLiteOpenHelper sqLiteOpenHelper;
	
	public static void init(Context context){
		sqLiteOpenHelper = new SQLiteOpenHelper(context, "smallfly", null, 1) {
			@Override
			public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
			}
			
			@Override
			public void onCreate(SQLiteDatabase db) {
				String sql = "CREATE TABLE IF NOT EXISTS downloadinfo(" +
						"id INTEGER PRIMARY KEY AUTOINCREMENT, " +
						"videoId VERCHAR, " +
						"title VERCHAR, " +
						"progress INTEGER, " +
						"progressText VERCHAR, " +
						"downloadSize INTEGER, " +
						"fileSize INTEGER, " +
						"status INTEGER, " +
						"createTime DATETIME, " +
						"definition INTEGER)";
				
				String videoPositionSql = "CREATE TABLE IF NOT EXISTS videoposition(id INTEGER PRIMARY KEY AUTOINCREMENT, " +
						"videoId VERCHAR, " +
						"position INTEGER)";			
				db.execSQL(sql);
				db.execSQL(videoPositionSql);
			}
		};
		downloadInfoMap = new LinkedHashMap<String, DownloadInfo>();
		reloadData();
	}
	
	private static void reloadData(){
		SQLiteDatabase db = sqLiteOpenHelper.getReadableDatabase();
		Cursor cursor = null; 
		try {
			// 重载下载信息
			synchronized (downloadInfoMap) {
				cursor = db.rawQuery("SELECT * FROM ".concat(DOWNLOADINFO), null);
				for (cursor.moveToFirst(); !cursor.isAfterLast(); cursor.moveToNext()) {
					try {
						DownloadInfo downloadInfo = buildDownloadInfo(cursor);
						downloadInfoMap.put(downloadInfo.getTitle(), downloadInfo);
						
					} catch (ParseException e) {
						Log.e("Parse date error", e.getMessage());
					}
				}
			}
		} catch (Exception e) {
			Log.e("cursor error", e.getMessage());
		} finally{
			if (cursor != null) {
				cursor.close();
			}
		}
	}
	/**
	 * 保存下载信息到数据库中
	 */
	public static void saveData(){
		SQLiteDatabase db = sqLiteOpenHelper.getReadableDatabase();
		db.beginTransaction();
		try {
			//清除当前数据
			db.delete(DOWNLOADINFO, null, null);
			for(DownloadInfo downloadInfo : downloadInfoMap.values()){
				ContentValues values = new ContentValues();
				values.put("videoId", downloadInfo.getVideoId());
				values.put("title", downloadInfo.getTitle());
				values.put("progress", downloadInfo.getProgress());
				values.put("progressText", downloadInfo.getProgressText());
				values.put("status", downloadInfo.getStatus());
				values.put("definition", downloadInfo.getDefinition());
				values.put("downloadSize", downloadInfo.getDownloadSize());
				values.put("fileSize", downloadInfo.getFileSize());
				SimpleDateFormat formater = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
				values.put("createTime", formater.format(downloadInfo.getCreateTime()));
				db.insert(DOWNLOADINFO, null, values);
			}
			db.setTransactionSuccessful();
		} catch (Exception e) {
			Log.e("db error", e.getMessage());
		} finally {
			db.endTransaction();
		}
		db.close();
	}
	
	/**
	 * 获取所有下载信息
	 * @return
	 */
	public static List<DownloadInfo> getDownloadInfos(){
		return new ArrayList<DownloadInfo>(downloadInfoMap.values());
	}
	
	/**
	 * 判断下载信息是否存在
	 * @param Title
	 * @return
	 */
	public static boolean hasDownloadInfo(String Title){
		return downloadInfoMap.containsKey(Title);
	}
	
	/**
	 * 获取下载信息
	 * @param Title
	 * @return
	 */
	public static DownloadInfo getDownloadInfo(String Title){
		return downloadInfoMap.get(Title);
	}
	
	/**
	 * 增加下载信息
	 * @param downloadInfo
	 */
	public static void addDownloadInfo(DownloadInfo downloadInfo){
		synchronized (downloadInfoMap) {
			if (downloadInfoMap.containsKey(downloadInfo.getTitle())) {
				return ;
			}
			
			downloadInfoMap.put(downloadInfo.getTitle(), downloadInfo);
		}
	}
	
	/**
	 * 删除下载信息
	 * @param title
	 */
	public static void removeDownloadInfo(String title){
		synchronized (downloadInfoMap) {
			downloadInfoMap.remove(title);
		}
	}
	
	/**
	 * 更新下载信息
	 * @param downloadInfo
	 */
	public static void updateDownloadInfo(DownloadInfo downloadInfo){
		synchronized (downloadInfoMap) {
			if(downloadInfo.getStatus() == Downloader.FINISH && downloadInfo.getProgress() != 100){
				downloadInfo.setProgress(100);
				downloadInfo.setProgressText("");
			}
			downloadInfoMap.put(downloadInfo.getTitle(), downloadInfo);
		}
	}
	/**
	 * build 下载信息
	 * @param cursor
	 * @return
	 * @throws ParseException
	 */
	private static DownloadInfo buildDownloadInfo(Cursor cursor) throws ParseException{
		SimpleDateFormat formater = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
		Date createTime = formater.parse(cursor.getString(cursor.getColumnIndex("createTime")));
		DownloadInfo downloadInfo = new DownloadInfo(cursor.getString(cursor.getColumnIndex("videoId")), 
				cursor.getString(cursor.getColumnIndex("title")),
				cursor.getInt(cursor.getColumnIndex("progress")), 
				cursor.getInt(cursor.getColumnIndex("downloadSize")), 
				cursor.getInt(cursor.getColumnIndex("fileSize")), 
				cursor.getString(cursor.getColumnIndex("progressText")), 
				cursor.getInt(cursor.getColumnIndex("status")), 
				createTime,
				cursor.getInt(cursor.getColumnIndex("definition")));
		downloadInfo.setId(cursor.getInt(cursor.getColumnIndex("id")));
		return downloadInfo;
	}
	/**
	 * 插入播放进度
	 * @param videoId
	 * @param position
	 */
	public static void insertVideoPosition(String videoId, int position) {
		
		SQLiteDatabase database = sqLiteOpenHelper.getWritableDatabase();
		if (database.isOpen()) {
			ContentValues values = new ContentValues();
			values.put("videoId", videoId);
			values.put("position", position);
			database.insert(VIDEOPOSITION, null, values);
			database.close();
		}
	}
	
	/**
	 * 获取播放进度
	 * @param videoId
	 * @return
	 */
	public static int getVideoPosition(String videoId) {
		int position = 0;
		SQLiteDatabase database = sqLiteOpenHelper.getReadableDatabase();
		if (database.isOpen()) {
			Cursor cursor = database.query(VIDEOPOSITION, new String[]{"position"}, "videoId=?", new String[]{videoId}, null, null, null);
			if (cursor.moveToFirst()) {
				position = cursor.getInt(cursor.getColumnIndex("position"));
			}
			cursor.close();
			database.close();
		}
		return position;
	}
	/**
	 * 更新播放进度
	 * @param videoId
	 * @param position
	 */
	public static void updateVideoPosition(String videoId, int position) {
		SQLiteDatabase database = sqLiteOpenHelper.getWritableDatabase();
		if (database.isOpen()) {
			ContentValues values = new ContentValues();
			values.put("position", position);
			database.update(VIDEOPOSITION, values, "videoId=?", new String[]{videoId});
			database.close();
		}
	}
}