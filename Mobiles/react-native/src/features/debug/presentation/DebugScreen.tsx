import React, { useMemo } from 'react';
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  View,
} from 'react-native';
import MaterialIcons from '@react-native-vector-icons/material-icons';
import { SafeAreaView } from 'react-native-safe-area-context';

import { triggerNativeCrash } from '../../../core/native/nativeCrash';
import { reportError } from '../../../core/o11y/o11yErrors';
import { trackEvent } from '../../../core/o11y/o11yEvents';
import { pushDebugLog, pushErrorLog } from '../../../core/o11y/o11yLogs';
import { AppColors } from '../../../core/theme/appColors';
import {
  type DebugSettings,
  useDebugSettingsStore,
} from '../domain/debugSettingsStore';
import {
  hasActiveDebugSettings,
  hasRestartRequired,
} from './debugConfigHelpers';

interface DebugScreenProps {
  onNavigateToConfig: () => void;
}

function SettingSwitch({
  title,
  subtitle,
  value,
  onValueChange,
}: {
  title: string;
  subtitle: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
}) {
  return (
    <View style={styles.settingRow}>
      <View style={styles.settingText}>
        <Text style={styles.settingTitle}>{title}</Text>
        <Text style={styles.settingSubtitle}>{subtitle}</Text>
      </View>
      <Switch value={value} onValueChange={onValueChange} />
    </View>
  );
}

function ActionButton({
  title,
  tone = 'primary',
  onPress,
}: {
  title: string;
  tone?: 'primary' | 'secondary' | 'danger';
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.actionButton,
        tone === 'secondary' && styles.secondaryButton,
        tone === 'danger' && styles.dangerButton,
        pressed && styles.pressedButton,
      ]}
    >
      <Text
        style={[
          styles.actionButtonText,
          tone === 'secondary' && styles.secondaryButtonText,
        ]}
      >
        {title}
      </Text>
    </Pressable>
  );
}

export function DebugScreen({ onNavigateToConfig }: DebugScreenProps) {
  const { settings, update, reset } = useDebugSettingsStore();
  const restartRequired = useMemo(
    () => hasRestartRequired(settings),
    [settings],
  );
  const activeOverrides = useMemo(
    () => hasActiveDebugSettings(settings),
    [settings],
  );

  const updateSetting = (patch: Partial<DebugSettings>) => {
    update(patch).catch(() => undefined);
  };

  const sendDebugLog = () => {
    pushDebugLog('QuickPizza RN debug log signal', {
      source: 'debug_screen',
    });
  };

  const sendErrorLog = () => {
    pushErrorLog('QuickPizza RN error log signal', {
      source: 'debug_screen',
    });
  };

  const sendCustomEvent = () => {
    trackEvent('debug_custom_event', {
      source: 'debug_screen',
    });
  };

  const reportHandledException = () => {
    try {
      throw new Error('QuickPizza RN handled debug exception');
    } catch (error) {
      reportError({
        type: 'HandledDebugException',
        error: error instanceof Error ? error.message : String(error),
        stacktrace: error instanceof Error ? error.stack : undefined,
        context: { source: 'debug_screen' },
      });
    }
  };

  const triggerUnhandledException = () => {
    setTimeout(() => {
      throw new Error('QuickPizza RN unhandled debug exception');
    }, 0);
  };

  const confirmNativeCrash = (variant: 'runtimeException' | 'nullPointer') => {
    Alert.alert(
      'Trigger native crash?',
      'The app will terminate. Relaunch it to let Faro report the crash.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Crash',
          style: 'destructive',
          onPress: () => triggerNativeCrash(variant),
        },
      ],
    );
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.header}>
          <Text style={styles.title}>Debug</Text>
          {activeOverrides && (
            <Pressable onPress={reset} hitSlop={12}>
              <Text style={styles.resetAllText}>Reset All</Text>
            </Pressable>
          )}
        </View>
        <Text style={styles.subtitle}>
          Runtime config, failure simulation, and telemetry diagnostics.
        </Text>

        <Pressable
          onPress={onNavigateToConfig}
          style={({ pressed }) => [
            styles.configCard,
            pressed && styles.pressedButton,
          ]}
        >
          <MaterialIcons name="settings" size={24} color="#757575" />
          <View style={styles.configCardText}>
            <Text style={styles.configCardTitle}>Config</Text>
            <Text style={styles.configCardSubtitle}>
              Change backend and Faro collector URLs (requires restart)
            </Text>
          </View>
          <MaterialIcons name="chevron-right" size={26} color="#757575" />
        </Pressable>

        <View style={styles.introSection}>
          <Text style={styles.subtitle}>
            Use these tools to simulate issues and exercise the observability
            instrumentation during demos.
          </Text>
        </View>

        {restartRequired && (
          <View style={styles.restartBanner}>
            <Text style={styles.restartTitle}>Restart required</Text>
            <Text style={styles.restartText}>
              Saved config differs from the values active in this app session.
            </Text>
          </View>
        )}

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Backend simulation</Text>
          <SettingSwitch
            title="Slow recommendations"
            subtitle="Adds x-delay-record-recommendation: 3s"
            value={settings.backendSlowRecommendations}
            onValueChange={(value) =>
              updateSetting({ backendSlowRecommendations: value })
            }
          />
          <SettingSwitch
            title="Error recommendations"
            subtitle="Adds x-error-record-recommendation"
            value={settings.backendErrorRecommendations}
            onValueChange={(value) =>
              updateSetting({ backendErrorRecommendations: value })
            }
          />
          <SettingSwitch
            title="Slow ingredients"
            subtitle="Adds x-delay-get-ingredients: 750ms"
            value={settings.backendSlowIngredients}
            onValueChange={(value) => updateSetting({ backendSlowIngredients: value })}
          />
          <SettingSwitch
            title="Error ingredients"
            subtitle="Adds x-error-get-ingredients"
            value={settings.backendErrorIngredients}
            onValueChange={(value) => updateSetting({ backendErrorIngredients: value })}
          />
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Client simulation</Text>
          <SettingSwitch
            title="Faulty pizza JSON parsing"
            subtitle="Parses the recommendation as a fake v2 schema"
            value={settings.clientFaultyPizzaJson}
            onValueChange={(value) => updateSetting({ clientFaultyPizzaJson: value })}
          />
          <SettingSwitch
            title="Skip auth dependency in tools"
            subtitle="Stops the tools list from reacting to login changes"
            value={settings.clientSkipAuthDependency}
            onValueChange={(value) =>
              updateSetting({ clientSkipAuthDependency: value })
            }
          />
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Quick Signals</Text>
          <View style={styles.buttonGrid}>
            <ActionButton title="Debug log" onPress={sendDebugLog} />
            <ActionButton title="Error log" onPress={sendErrorLog} />
            <ActionButton title="Custom event" onPress={sendCustomEvent} />
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Exceptions</Text>
          <View style={styles.buttonGrid}>
            <ActionButton
              title="Handled exception"
              onPress={reportHandledException}
            />
            <ActionButton
              title="Unhandled exception"
              tone="danger"
              onPress={triggerUnhandledException}
            />
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Native crash</Text>
          <Text style={styles.settingSubtitle}>
            These intentionally terminate the app and are reported after relaunch.
          </Text>
          <View style={styles.buttonGrid}>
            <ActionButton
              title="RuntimeException / fatalError"
              tone="danger"
              onPress={() => confirmNativeCrash('runtimeException')}
            />
            <ActionButton
              title="Null pointer / force unwrap"
              tone="danger"
              onPress={() => confirmNativeCrash('nullPointer')}
            />
          </View>
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
  scroll: {
    flex: 1,
  },
  content: {
    padding: 20,
    paddingBottom: 40,
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#212121',
  },
  subtitle: {
    fontSize: 15,
    color: '#757575',
    lineHeight: 21,
  },
  resetAllText: {
    color: AppColors.primary,
    fontSize: 15,
    fontWeight: '700',
  },
  configCard: {
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderColor: '#E8E8E8',
    borderRadius: 16,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 14,
    marginTop: 20,
    marginBottom: 22,
    padding: 16,
  },
  configCardText: {
    flex: 1,
  },
  configCardTitle: {
    color: '#212121',
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 2,
  },
  configCardSubtitle: {
    color: '#616161',
    fontSize: 14,
    lineHeight: 20,
  },
  introSection: {
    marginBottom: 20,
  },
  restartBanner: {
    backgroundColor: '#FFF8E1',
    borderColor: '#FFE082',
    borderWidth: 1,
    borderRadius: 12,
    padding: 14,
    marginBottom: 16,
  },
  restartTitle: {
    color: '#F57F17',
    fontWeight: '700',
    marginBottom: 4,
  },
  restartText: {
    color: '#F57F17',
    fontSize: 13,
  },
  section: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#E8E8E8',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#212121',
    marginBottom: 12,
  },
  settingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    borderTopWidth: 1,
    borderTopColor: '#F2F2F2',
  },
  settingText: {
    flex: 1,
    paddingRight: 12,
  },
  settingTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: '#212121',
  },
  settingSubtitle: {
    fontSize: 12,
    color: '#757575',
    marginTop: 3,
    lineHeight: 17,
  },
  buttonGrid: {
    gap: 10,
  },
  actionButton: {
    backgroundColor: AppColors.primary,
    borderRadius: 12,
    paddingVertical: 13,
    alignItems: 'center',
  },
  secondaryButton: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E0E0E0',
    marginTop: 14,
  },
  dangerButton: {
    backgroundColor: '#C62828',
  },
  pressedButton: {
    opacity: 0.75,
  },
  actionButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
  secondaryButtonText: {
    color: '#424242',
  },
});
