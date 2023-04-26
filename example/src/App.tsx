import * as React from 'react';

import { StyleSheet, View, Text } from 'react-native';
import { isApiAvailable } from 'react-native-iot-wifi';

export default function App() {
  const [result, setResult] = React.useState<boolean | undefined>();

  const test = async () => {
    const api = await isApiAvailable();
    setResult(api);
  };

  React.useEffect(() => {
    test();
  }, []);

  return (
    <View style={styles.container}>
      <Text>Api available?: {result ? 'YES' : 'NO'}</Text>
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
});
