package de.doegel.iotwifi;

import androidx.annotation.NonNull;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkInfo;
import android.net.NetworkRequest;
import android.net.wifi.WifiConfiguration;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.net.wifi.WifiNetworkSpecifier;
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

import java.util.List;

@ReactModule(name = IotWifiModule.NAME)
public class IotWifiModule extends ReactContextBaseJavaModule implements PermissionListener {
  public static final String NAME = "IotWifi";

  private int mRequestCode = 0;
  private ConnectivityManager.NetworkCallback mCallback;
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
    String permission = getPermissionIdentifier();

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

      activity.requestPermissions(new String[]{permission}, mRequestCode, this);
      mRequestCode++;
    } catch (IllegalStateException e) {
      promise.reject("invalid_activity", e);
    }
  }

  @ReactMethod
  public void hasPermission(Promise promise) {
    Context context = getReactApplicationContext().getBaseContext();
    String permission = getPermissionIdentifier();

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      promise.resolve(
        context.checkPermission(permission, Process.myPid(), Process.myUid())
          == PackageManager.PERMISSION_GRANTED);
      return;
    }

    promise.resolve(context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED);
  }

  @ReactMethod
  public void isApiAvailable(Promise promise) {
    promise.resolve(true);
  }

  @ReactMethod
  public void getSSID(Promise promise) {
    String ssid = getCurrentSSID();
    if (ssid == null || ssid.equalsIgnoreCase("<unknown ssid>")) {
      promise.reject("not_available", "Cannot detect SSID");
    } else {
      promise.resolve(ssid);
    }
  }

  @ReactMethod
  public void connect(
    String ssid, String passphrase, Promise promise) {
    NetworkRequest networkRequest;
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      // API using Android Q+
      // Build configuration
      WifiNetworkSpecifier.Builder builder = new WifiNetworkSpecifier.Builder()
        .setSsid(ssid);

      if (!passphrase.equals("")) {
        builder.setWpa2Passphrase(passphrase);
      }

      // Add configuration, connect and check
      networkRequest = new NetworkRequest.Builder()
        .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
        .setNetworkSpecifier(builder.build())
        .build();

    } else {
      // Legacy API
      // Build configuration
      WifiConfiguration configuration = new WifiConfiguration();
      configuration.SSID = String.format("\"%s\"", ssid);

      if (passphrase.equals("")) {
        configuration.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE);
      } else { // WPA/WPA2
        configuration.preSharedKey = String.format("\"%s\"", passphrase);
      }

      // Add configuration
      int networkId = wifiManager.addNetwork(configuration);
      if (networkId == -1) {
        promise.reject("not_configured", "Configuration for network failed");
        return;
      }

      // Connect
      wifiManager.disconnect();
      boolean success = wifiManager.enableNetwork(networkId, true);
      if (!success) {
        promise.reject("not_configured", "Could not enable network");
        return;
      }
      wifiManager.reconnect();

      // Check
      networkRequest = new NetworkRequest.Builder()
        .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
        .build();
    }
    waitForNetwork(ssid, promise);
    connectivityManager.requestNetwork(networkRequest, mCallback);
  }

  @ReactMethod
  public void disconnect(String ssid, Promise promise) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      // No need to remove the network in Android Q+
    } else {
      // Legacy API
      List<WifiConfiguration> networks = wifiManager.getConfiguredNetworks();
      String comparableSSID = String.format("\"%s\"", ssid);

      if (networks != null) {
        for (WifiConfiguration configuration : networks) {
          if (configuration.SSID.equals(comparableSSID) && configuration.networkId != -1) {
            // Remove the existing configuration for this network
            wifiManager.removeNetwork(configuration.networkId);
            wifiManager.saveConfiguration();
          }
        }
      }

      // TODO: reject if not found?
    }

    bindProcessToNetwork(null);
    promise.resolve(null);
  }

  /**
   * Method called by the activity with the result of the permission request.
   */
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

  private String getPermissionIdentifier() {
    String permission;
    if (false /* Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU */) {
      // NOTE: Be aware of new permission introduced in Tiramisu (33)
      // @link https://developer.android.com/guide/topics/connectivity/wifi-permissions
      permission = Manifest.permission.NEARBY_WIFI_DEVICES;
    } else {
      permission = Manifest.permission.ACCESS_FINE_LOCATION;
    }
    return permission;
  }

  private void bindProcessToNetwork(final Network network) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      connectivityManager.bindProcessToNetwork(network);
    } else {
      ConnectivityManager.setProcessDefaultNetwork(network);
    }
  }

  private void waitForNetwork(String ssid, Promise promise) {
    if (mCallback != null) {
      connectivityManager.unregisterNetworkCallback(mCallback);
    }

    mCallback = new ConnectivityManager.NetworkCallback() {
      @Override
      public void onAvailable(Network network) {
        String currentSSID = getCurrentSSID();
        if (ssid.equals(currentSSID)) {
          bindProcessToNetwork(network);
          promise.resolve(null);
        }
      }

      @Override
      public void onUnavailable() {
        bindProcessToNetwork(null);
        promise.reject("not_configured", "Cannot connect to network");
      }
    };
  }

  private String getCurrentSSID() {
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
      return ssid;
    }

    return null;
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
