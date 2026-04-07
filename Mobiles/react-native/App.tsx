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

import { O11yErrorBoundary } from './src/core/o11y/o11yReactNative';

import { initFaro } from './src/bootstrap';
import { AppNavigator } from './src/navigation/AppNavigator';
import { useAdminStore } from './src/features/admin/domain/adminStore';
import { useAuthStore } from './src/features/auth/domain/authStore';

function App() {
  const isDarkMode = useColorScheme() === 'dark';
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const setup = async () => {
      initFaro();
      await Promise.all([
        useAuthStore.getState().restoreSession(),
        useAdminStore.getState().restoreSession(),
      ]);
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
    <O11yErrorBoundary
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
    </O11yErrorBoundary>
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
