import React, { useEffect } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { withFaroUserAction } from '@grafana/faro-react-native';

import { trackEvent } from '../../../core/o11y/o11yEvents';
import { AppColors } from '../../../core/theme/appColors';
import { useAuthStore } from '../domain/authStore';

const LoginButton = withFaroUserAction(Pressable, 'user-login');

interface LoginScreenProps {
  onBack: () => void;
  onSuccess: () => void;
}

export function LoginScreen({ onBack, onSuccess }: LoginScreenProps) {
  const { login, isLoading, errorMessage, isLoggedIn } = useAuthStore();

  useEffect(() => {
    trackEvent('login_screen_opened');
  }, []);

  useEffect(() => {
    if (isLoggedIn) {
      onSuccess();
    }
  }, [isLoggedIn, onSuccess]);

  const [username, setUsername] = React.useState('default');
  const [password, setPassword] = React.useState('12345678');

  const handleLogin = async () => {
    const success = await login(username, password);
    if (success) {
      onSuccess();
    }
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <Pressable onPress={onBack} style={styles.backButton}>
          <Text style={styles.backText}>← Back</Text>
        </Pressable>
        <Text style={styles.title}>Login</Text>
      </View>

      <ScrollView
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.avatarContainer}>
          <Text style={styles.avatarIcon}>👤</Text>
        </View>
        <Text style={styles.welcome}>Welcome to QuickPizza</Text>
        <Text style={styles.hint}>Sign in to save your favorite pizzas</Text>

        <View style={styles.form}>
          <Text style={styles.label}>Username</Text>
          <TextInput
            style={styles.input}
            value={username}
            onChangeText={setUsername}
            placeholder="Username"
            autoCapitalize="none"
            autoCorrect={false}
          />
          <Text style={styles.label}>Password</Text>
          <TextInput
            style={styles.input}
            value={password}
            onChangeText={setPassword}
            placeholder="Password"
            secureTextEntry
          />
          {errorMessage != null && (
            <View style={styles.error}>
              <Text style={styles.errorIcon}>⚠️</Text>
              <Text style={styles.errorText}>{errorMessage}</Text>
            </View>
          )}
          <LoginButton
            onPress={handleLogin}
            disabled={isLoading}
            style={[styles.loginButton, isLoading && styles.buttonDisabled]}
          >
            {isLoading ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <Text style={styles.loginButtonText}>Sign in</Text>
            )}
          </LoginButton>
        </View>

        <View style={styles.infoBox}>
          <Text style={styles.infoIcon}>ℹ️</Text>
          <Text style={styles.infoText}>
            Default credentials: username "default", password "12345678"
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: AppColors.scaffoldBackground,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#EEE',
  },
  backButton: {
    marginRight: 16,
  },
  backText: {
    fontSize: 16,
    color: '#424242',
  },
  title: {
    fontSize: 18,
    fontWeight: '600',
    color: '#212121',
  },
  scrollContent: {
    padding: 24,
    paddingTop: 32,
  },
  avatarContainer: {
    alignSelf: 'center',
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: '#FFF3E0',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 24,
  },
  avatarIcon: {
    fontSize: 48,
  },
  welcome: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#212121',
    textAlign: 'center',
  },
  hint: {
    fontSize: 15,
    color: '#757575',
    textAlign: 'center',
    marginTop: 8,
    marginBottom: 32,
  },
  form: {
    backgroundColor: '#FFFFFF',
    padding: 24,
    borderRadius: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 10,
    elevation: 2,
  },
  label: {
    fontSize: 14,
    color: '#616161',
    marginBottom: 4,
  },
  input: {
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    marginBottom: 16,
  },
  error: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    backgroundColor: AppColors.errorLight,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#FFCDD2',
    marginBottom: 16,
  },
  errorIcon: {
    marginRight: 8,
    fontSize: 18,
  },
  errorText: {
    flex: 1,
    fontSize: 13,
    color: AppColors.error,
  },
  loginButton: {
    backgroundColor: AppColors.primary,
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    minHeight: 52,
    justifyContent: 'center',
  },
  buttonDisabled: {
    opacity: 0.7,
  },
  loginButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  infoBox: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#E3F2FD',
    borderRadius: 8,
    marginTop: 24,
  },
  infoIcon: {
    marginRight: 8,
    fontSize: 18,
  },
  infoText: {
    flex: 1,
    fontSize: 13,
    color: '#1565C0',
  },
});
