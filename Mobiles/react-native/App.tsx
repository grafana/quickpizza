/**
 * QuickPizza React Native Demo App
 * Demonstrates Grafana Faro SDK for mobile observability
 */

import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { FaroErrorBoundary } from '@grafana/faro-react-native';

import { initFaro } from './src/bootstrap';
import { AppNavigator } from './src/navigation/AppNavigator';
import { useAuthStore } from './src/features/auth/domain/authStore';

function App() {
  const isDarkMode = useColorScheme() === 'dark';
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const setup = async () => {
      initFaro();
      await useAuthStore.getState().restoreSession();
      setReady(true);
    };
    setup();
  }, []);

  if (!ready) {
    return (
      <View style={styles.loading}>
        <ActivityIndicator size="large" color="#F15B2A" />
        <Text style={styles.loadingText}>Loading...</Text>
      </View>
    );
  }

  return (
    <FaroErrorBoundary
      fallback={
        <View style={styles.error}>
          <Text style={styles.errorText}>Something went wrong</Text>
        </View>
      }
    >
      <SafeAreaProvider>
        <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
        <AppNavigator />
      </SafeAreaProvider>
    </FaroErrorBoundary>
  );
}

const styles = StyleSheet.create({
  loading: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#FFF5F0',
  },
  loadingText: {
    marginTop: 12,
    fontSize: 16,
    color: '#757575',
  },
  error: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#FFF5F0',
  },
  errorText: {
    fontSize: 16,
    color: '#D32F2F',
  },
});

export default App;
