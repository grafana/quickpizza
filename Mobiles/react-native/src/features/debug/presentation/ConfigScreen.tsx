import React, { useEffect, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import MaterialIcons from '@react-native-vector-icons/material-icons';
import { SafeAreaView } from 'react-native-safe-area-context';

import { getRuntimeConfig } from '../../../core/config/configService';
import { AppColors } from '../../../core/theme/appColors';
import { useDebugSettingsStore } from '../domain/debugSettingsStore';
import { maskCollectorUrl } from './debugConfigHelpers';

interface ConfigScreenProps {
  onBack: () => void;
}

export function ConfigScreen({ onBack }: ConfigScreenProps) {
  const { settings, update } = useDebugSettingsStore();
  const activeConfig = getRuntimeConfig();
  const [backendUrl, setBackendUrl] = useState(settings.backendUrlOverride);
  const [faroCollectorUrl, setFaroCollectorUrl] = useState(
    settings.faroCollectorUrlOverride,
  );
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    setBackendUrl(settings.backendUrlOverride);
    setFaroCollectorUrl(settings.faroCollectorUrlOverride);
  }, [settings.backendUrlOverride, settings.faroCollectorUrlOverride]);

  const save = () => {
    update({
      backendUrlOverride: backendUrl,
      faroCollectorUrlOverride: faroCollectorUrl,
    })
      .then(() => {
        setSaved(true);
        setTimeout(() => setSaved(false), 3000);
      })
      .catch(() => undefined);
  };

  const clearOverrides = () => {
    setBackendUrl('');
    setFaroCollectorUrl('');
    update({ backendUrlOverride: '', faroCollectorUrlOverride: '' }).catch(
      () => undefined,
    );
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <Pressable
          onPress={onBack}
          style={styles.backButton}
          accessibilityRole="button"
          accessibilityLabel="Back"
        >
          <MaterialIcons name="arrow-back" size={24} color="#212121" />
        </Pressable>
        <Text style={styles.title}>Config</Text>
        <View style={styles.headerSpacer} />
      </View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <Text style={styles.intro}>
          Override the URLs used by this app. Changes only take effect after
          you kill and restart the app so traces, logs, and metrics stay
          correlated within a single session.
        </Text>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Backend URL</Text>
          <Text style={styles.label}>Currently in use</Text>
          <Text style={styles.currentValue}>{activeConfig.baseUrl}</Text>
          <TextInput
            style={styles.input}
            value={backendUrl}
            onChangeText={setBackendUrl}
            placeholder="Override (empty = use default)"
            autoCapitalize="none"
            autoCorrect={false}
          />
        </View>

        <View style={styles.card}>
          <Text style={styles.cardTitle}>Faro collector URL</Text>
          <Text style={styles.label}>Currently in use</Text>
          <Text style={styles.currentValue}>
            {maskCollectorUrl(activeConfig.faroCollectorUrl)}
          </Text>
          <TextInput
            style={styles.input}
            value={faroCollectorUrl}
            onChangeText={setFaroCollectorUrl}
            placeholder="Override (empty = use default)"
            autoCapitalize="none"
            autoCorrect={false}
          />
        </View>

        <Pressable
          onPress={save}
          style={({ pressed }) => [
            styles.primaryButton,
            pressed && styles.pressedButton,
          ]}
        >
          <MaterialIcons name="save" size={18} color="#FFFFFF" />
          <Text style={styles.primaryButtonText}>Save</Text>
        </Pressable>

        <Pressable
          onPress={clearOverrides}
          style={({ pressed }) => [
            styles.secondaryButton,
            pressed && styles.pressedButton,
          ]}
        >
          <MaterialIcons name="restart-alt" size={18} color={AppColors.primary} />
          <Text style={styles.secondaryButtonText}>
            Use defaults (clear overrides)
          </Text>
        </Pressable>

        {saved && (
          <View style={styles.savedBanner}>
            <MaterialIcons name="check-circle" size={18} color="#2E7D32" />
            <Text style={styles.savedText}>
              Saved. Restart the app for changes to take effect.
            </Text>
          </View>
        )}
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
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 16,
  },
  backButton: {
    padding: 4,
  },
  title: {
    fontSize: 22,
    fontWeight: '600',
    color: '#212121',
  },
  headerSpacer: {
    width: 32,
  },
  scroll: {
    flex: 1,
  },
  content: {
    padding: 20,
    paddingBottom: 40,
  },
  intro: {
    color: '#616161',
    fontSize: 15,
    lineHeight: 22,
    marginBottom: 24,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderColor: '#E8E8E8',
    borderRadius: 16,
    borderWidth: 1,
    padding: 18,
    marginBottom: 18,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#212121',
    marginBottom: 14,
  },
  label: {
    fontSize: 13,
    color: '#757575',
    marginBottom: 4,
  },
  currentValue: {
    fontSize: 15,
    color: '#212121',
    marginBottom: 14,
  },
  input: {
    borderColor: '#9E9E9E',
    borderRadius: 8,
    borderWidth: 1,
    color: '#212121',
    fontSize: 15,
    padding: 14,
  },
  primaryButton: {
    alignItems: 'center',
    backgroundColor: AppColors.primary,
    borderRadius: 16,
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'center',
    marginTop: 10,
    paddingVertical: 15,
  },
  primaryButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '700',
  },
  secondaryButton: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderColor: '#9E9E9E',
    borderRadius: 16,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'center',
    marginTop: 14,
    paddingVertical: 15,
  },
  secondaryButtonText: {
    color: AppColors.primary,
    fontSize: 16,
    fontWeight: '700',
  },
  pressedButton: {
    opacity: 0.75,
  },
  savedBanner: {
    alignItems: 'center',
    backgroundColor: '#E8F5E9',
    borderColor: '#A5D6A7',
    borderRadius: 12,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 8,
    marginTop: 18,
    padding: 12,
  },
  savedText: {
    color: '#2E7D32',
    flex: 1,
    fontSize: 13,
  },
});
