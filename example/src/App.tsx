import * as React from 'react';

import { StyleSheet, View, Text, Button, TextInput } from 'react-native';
import {
  hasPermission,
  requestPermission,
  isApiAvailable,
  getSSID,
  connect,
  disconnect,
} from '@doegel/react-native-iot-wifi';

export default function App() {
  const [available, setAvailable] = React.useState<boolean>(false);
  const [permission, setPermission] = React.useState<boolean>(false);
  const [network, setNetwork] = React.useState<string>('');
  const [loading, setLoading] = React.useState<boolean>(false);
  const [error, setError] = React.useState<string>('');
  const [ssid, setSsid] = React.useState<string>('PR0100100110');
  const [passphrase, setPassphrase] = React.useState<string>('Hq1ZIpHF');

  const tryWebsocket = async () => {
    const ws = new WebSocket('ws://192.168.0.10:8090/');
    ws.onopen = () => console.warn('open');
    ws.onclose = () => console.warn('close');
    ws.onerror = (e) => console.warn(e.message);
  };

  const getInfo = async () => {
    try {
      setLoading(true);
      const isAvailable = await isApiAvailable();
      setAvailable(isAvailable);

      const getPermission = await requestPermission();
      setPermission(getPermission || false);

      const isPermitted = await hasPermission();
      setPermission(isPermitted);

      const currentSsid = await getSSID();
      setNetwork(currentSsid);

      setError('');
    } catch (err: any) {
      console.warn(err);
    } finally {
      setLoading(false);
    }
  };

  const connectNetwork = async () => {
    try {
      setLoading(true);
      await connect(ssid, passphrase);
      getInfo();
      tryWebsocket();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const disconnectNetwork = async () => {
    try {
      setLoading(true);
      await disconnect(ssid);
      getInfo();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  React.useEffect(() => {
    getInfo();
  }, []);

  return (
    <View style={styles.container}>
      <Text style={styles.text}>API available: {available ? 'YES' : 'NO'}</Text>
      <Text style={styles.text}>Is permitted: {permission ? 'YES' : 'NO'}</Text>
      <TextInput
        style={styles.text}
        placeholder="SSID"
        defaultValue={ssid}
        onChangeText={setSsid}
      />
      <TextInput
        style={styles.text}
        placeholder="Passphrase"
        defaultValue={passphrase}
        onChangeText={setPassphrase}
      />
      <Button title="Connect" onPress={connectNetwork} />
      <Button title="Disconnect" onPress={disconnectNetwork} />
      <Text style={styles.text}>SSID: {network}</Text>
      {loading && <Text style={styles.text}>Busy...</Text>}
      {error && <Text style={styles.text}>Error: {error}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  text: {
    width: '100%',
    color: 'white',
    padding: 20,
  },
});
