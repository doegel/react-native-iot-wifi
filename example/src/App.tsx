import * as React from 'react';

import { StyleSheet, View, Text } from 'react-native';
import {
  hasPermission,
  requestPermission,
} from '@doegel/react-native-iot-wifi';

export default function App() {
  const [reqP, setReqP] = React.useState<boolean | undefined>();
  const [hasP, setHasP] = React.useState<boolean | undefined>();

  const get = async () => {
    try {
      const hasPer = await hasPermission();
      setHasP(hasPer);
      const reqPer = await requestPermission();
      setReqP(reqPer);
    } catch (err: any) {
      console.warn(err);
    }
  };

  React.useEffect(() => {
    get();
  }, []);

  return (
    <View style={styles.container}>
      <Text style={styles.text}>HasPer: {hasP ? 'YES' : 'NO'}</Text>
      <Text style={styles.text}>ReqPer: {reqP ? 'YES' : 'NO'}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
  text: {
    color: 'white',
  },
});
