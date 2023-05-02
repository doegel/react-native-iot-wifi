import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-iot-wifi' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const IotWifi = NativeModules.IotWifi
  ? NativeModules.IotWifi
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function requestPermission(): Promise<boolean | undefined> {
  return IotWifi.requestPermission();
}

export function hasPermission(): Promise<boolean> {
  return IotWifi.hasPermission();
}

export function isApiAvailable(): Promise<boolean> {
  return IotWifi.isApiAvailable();
}

export function getSSID(): Promise<string> {
  return IotWifi.getSSID();
}

export function connect(ssid: string, passphrase: string = ''): Promise<void> {
  return IotWifi.connect(ssid, passphrase);
}

export function disconnect(ssid: string): Promise<void> {
  return IotWifi.removeSSID(ssid);
}
