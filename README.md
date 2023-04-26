# react-native-iot-wifi

Connect to WiFi with React Native on Android and iOS.
This library was written to config iot devices. With iOS 11 Apple introduced NEHotspotConfiguration class for wifi configuration. Library supports same functionality on ios and android.

## Changelog

⚠️ This is a complete rewrite from v1 based on the great work of (tadasr/react-native-iot-wifi)[https://github.com/tadasr/react-native-iot-wifi], if you are looking for the old version [look here.](https://github.com/doegel/react-native-iot-wifi/tree/v1)

### 2.0.0
* Modernizing code and build configuration
* Android is using the newer (WifiNetworkSpecifier API)[https://developer.android.com/reference/android/net/wifi/WifiNetworkSpecifier]

## Installation

```sh
npm install react-native-iot-wifi
```

### iOS
> Important
> IoTWifi uses NEHotspotConfigurationManager. To use the NEHotspotConfigurationManager class, you must enable the Hotspot Configuration capability in [Xcode](http://help.apple.com/xcode/mac/current/#/dev88ff319e7).

1. [Enable](http://help.apple.com/xcode/mac/current/#/dev88ff319e7) `Hotspot Configuration`
2. For iOS 12 [Enable](http://help.apple.com/xcode/mac/current/#/dev88ff319e7) `Access WiFi Information`

## Usage

```js
import Wifi from "react-native-iot-wifi";

// On some platforms location permission is required to setup wifi.
await Wifi.requestPermission();
let allowed = await Wifi.hasPermission();

// You may check if the API is available.
let available = await Wifi.isApiAvailable();

let ssid = await Wifi.getSSID();

try {
  await Wifi.connect("wifi-ssid");
} catch (error) {
  console.log('error: ' + error);
}

try {
  await Wifi.connectSecure("wifi-ssid", "passphrase");
} catch (error) {
  console.log('error: ' + error);
}

try {
  await Wifi.disconnect("wifi-ssid");
} catch (error) {
  console.log('error: ' + error);
}
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

See the [LICENSE](LICENSE) file for license rights and limitations (MIT).
