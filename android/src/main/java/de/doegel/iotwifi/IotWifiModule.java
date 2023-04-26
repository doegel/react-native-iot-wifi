package de.doegel.iotwifi;

import androidx.annotation.NonNull;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Process;
import android.util.Log;
import android.util.SparseArray;

import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.modules.core.PermissionAwareActivity;
import com.facebook.react.modules.core.PermissionListener;

@ReactModule(name = IotWifiModule.NAME)
public class IotWifiModule extends ReactContextBaseJavaModule implements PermissionListener {
  public static final String NAME = "IotWifi";

  private int mRequestCode = 0;
  private final SparseArray<Callback> mCallbacks;

  private WifiManager wifiManager;
  private ConnectivityManager connectivityManager;

  public IotWifiModule(ReactApplicationContext reactContext) {
    super(reactContext);
    mCallbacks = new SparseArray<Callback>();
    wifiManager = (WifiManager) getReactApplicationContext()
            .getApplicationContext()
            .getSystemService(Context.WIFI_SERVICE);
    connectivityManager = (ConnectivityManager) getReactApplicationContext()
            .getApplicationContext()
            .getSystemService(Context.CONNECTIVITY_SERVICE);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }

  @ReactMethod
  public void requestPermission(Promise promise) {
    Context context = getReactApplicationContext().getBaseContext();
    String permission = Manifest.permission.ACCESS_FINE_LOCATION;

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      promise.resolve(
          context.checkPermission(permission, Process.myPid(), Process.myUid())
                  == PackageManager.PERMISSION_GRANTED);
      return;
    }

    if (context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
      promise.resolve(true);
      return;
    }

    try {
      PermissionAwareActivity activity = getPermissionAwareActivity();

      mCallbacks.put(
          mRequestCode,
          new Callback() {
            @Override
            public void invoke(Object... args) {
              int[] results = (int[]) args[0];
              if (results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED) {
                promise.resolve(true);
              } else {
                PermissionAwareActivity activity = (PermissionAwareActivity) args[1];
                if (activity.shouldShowRequestPermissionRationale(permission)) {
                  promise.resolve(false);
                } else {
                  promise.resolve(null);
                }
              }
            }
          });

      activity.requestPermissions(new String[] {permission}, mRequestCode, this);
      mRequestCode++;
    } catch (IllegalStateException e) {
      promise.reject("invalid_activity", e);
    }
  }

  @ReactMethod
  public void hasPermission(Promise promise) {
    Context context = getReactApplicationContext().getBaseContext();
    String permission = Manifest.permission.ACCESS_FINE_LOCATION;

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      promise.resolve(
          context.checkPermission(permission, Process.myPid(), Process.myUid())
              == PackageManager.PERMISSION_GRANTED);
      return;
    }

    // NOTE: Be aware of new permission introduced in Tiramisu (33)
    // @link https://developer.android.com/guide/topics/connectivity/wifi-permissions

    promise.resolve(context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED);
  }

  @ReactMethod
  public void isApiAvailable(Promise promise) {
    promise.resolve(true);
  }

  @ReactMethod
  public void getSSID(Promise promise) {
      WifiInfo wifiInfo = wifiManager.getConnectionInfo();
      String ssid = wifiInfo.getSSID();

      if (ssid == null || ssid.equalsIgnoreCase("<unknown ssid>")) {
          NetworkInfo networkInfo = connectivityManager.getActiveNetworkInfo();
          if (networkInfo != null && networkInfo.isConnected()) {
              ssid = networkInfo.getExtraInfo();
          }
      }

      if (ssid != null && ssid.startsWith("\"") && ssid.endsWith("\"")) {
          ssid = ssid.substring(1, ssid.length() - 1);
      }

      if (ssid != null && !ssid.isEmpty()) {
          promise.resolve(ssid);
          return;
      }

      promise.reject("not_available", "Cannot detect SSID");
  }

  @ReactMethod
  public void connect(
      String ssid, String passphrase, Boolean rememberNetwork, Boolean isWEP, Promise promise) {
      new Thread(new Runnable() {
          public void run() {
              // TODO implement from here
              connectToWifi(ssid, passphrase, rememberNetwork, isWEP, promise);
          }
      }).start();
  }

  /** Method called by the activity with the result of the permission request. */
  @Override
  public boolean onRequestPermissionsResult(
    int requestCode, String[] permissions, int[] grantResults) {
    try {
      mCallbacks.get(requestCode).invoke(grantResults, getPermissionAwareActivity());
      mCallbacks.remove(requestCode);
      return mCallbacks.size() == 0;
    } catch (IllegalStateException e) {
      Log.e(
        "PermissionsModule",
        "Unexpected invocation of `onRequestPermissionsResult` with invalid current activity",
        e);
      return false;
    }
  }

  private PermissionAwareActivity getPermissionAwareActivity() {
    Activity activity = getCurrentActivity();

    if (activity == null) {
      throw new IllegalStateException(
        "Tried to use permissions API while not attached to an " + "Activity.");
    } else if (!(activity instanceof PermissionAwareActivity)) {
      throw new IllegalStateException(
        "Tried to use permissions API but the host Activity doesn't"
          + " implement PermissionAwareActivity.");
    }

    return (PermissionAwareActivity) activity;
  }
}
