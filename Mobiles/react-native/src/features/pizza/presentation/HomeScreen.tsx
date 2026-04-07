import React, { useEffect, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { runSimulateDemoCatalogErrorRequest } from '../../../core/demo/simulateDemoBackendError';
import { isSimulateDemoErrorEnabled } from '../../../core/config/configService';
import { QuickPizzaAppBar } from '../../../core/components/QuickPizzaAppBar';
import { AppColors } from '../../../core/theme/appColors';
import { defaultRestrictions } from '../models/restrictions';
import type { Restrictions } from '../models/restrictions';
import { useAuthStore } from '../../auth/domain/authStore';
import { usePizzaStore } from '../domain/pizzaStore';
import { CustomizeSection } from './components/CustomizeSection';
import { HeroText } from './components/HeroText';
import { PizzaButton } from './components/PizzaButton';
import { PizzaCard } from './components/PizzaCard';
import { QuoteCard } from './components/QuoteCard';

const DEMO_CATALOG_ERROR_AUTO_DISMISS_MS = 30_000;

interface HomeScreenProps {
  onProfilePress: () => void;
}

export function HomeScreen({ onProfilePress }: HomeScreenProps) {
  const [restrictions, setRestrictions] = useState<Restrictions>(defaultRestrictions);
  const [advancedEnabled, setAdvancedEnabled] = useState(false);
  const { pizza, isLoading, errorMessage, getPizza } = usePizzaStore();
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [demoCatalogError, setDemoCatalogError] = useState<string | null>(null);

  const effectiveRestrictions = advancedEnabled ? restrictions : defaultRestrictions;

  useEffect(() => {
    if (!isSimulateDemoErrorEnabled() || !isLoggedIn) {
      setDemoCatalogError(null);
      return;
    }

    let cancelled = false;
    void runSimulateDemoCatalogErrorRequest().then((result) => {
      if (cancelled) {
        return;
      }
      if (result.ran && !result.ok) {
        setDemoCatalogError(result.userMessage);
      } else {
        setDemoCatalogError(null);
      }
    });

    return () => {
      cancelled = true;
    };
  }, [isLoggedIn]);

  useEffect(() => {
    if (demoCatalogError == null) {
      return;
    }
    const id = setTimeout(() => {
      setDemoCatalogError(null);
    }, DEMO_CATALOG_ERROR_AUTO_DISMISS_MS);
    return () => clearTimeout(id);
  }, [demoCatalogError]);

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <QuickPizzaAppBar
        onProfilePress={onProfilePress}
        advancedEnabled={advancedEnabled}
        onAdvancedChange={setAdvancedEnabled}
      />
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <QuoteCard />
        {demoCatalogError != null && (
          <>
            <View style={styles.spacer} />
            <View style={styles.error}>
              <Text style={styles.errorIcon}>⚠️</Text>
              <Text style={styles.errorText}>{demoCatalogError}</Text>
              <Pressable
                onPress={() => setDemoCatalogError(null)}
                hitSlop={12}
                accessibilityRole="button"
                accessibilityLabel="Dismiss demo catalog error"
                style={({ pressed }) => [
                  styles.errorDismiss,
                  pressed && styles.errorDismissPressed,
                ]}
              >
                <Text style={styles.errorDismissText}>✕</Text>
              </Pressable>
            </View>
          </>
        )}
        <View style={styles.spacer} />
        <HeroText />
        <View style={styles.spacer} />
        {advancedEnabled && (
          <>
            <CustomizeSection
              restrictions={restrictions}
              onRestrictionsChange={setRestrictions}
            />
            <View style={styles.spacer} />
          </>
        )}
        <PizzaButton
          onPress={() => getPizza(effectiveRestrictions)}
          isLoading={isLoading}
        />
        {errorMessage != null && (
          <View style={styles.error}>
            <Text style={styles.errorIcon}>⚠️</Text>
            <Text style={styles.errorText}>{errorMessage}</Text>
          </View>
        )}
        {pizza != null && <PizzaCard recommendation={pizza} />}
        <View style={styles.bottomSpacer} />
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
  },
  spacer: {
    height: 24,
  },
  bottomSpacer: {
    height: 40,
  },
  error: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 16,
    padding: 12,
    backgroundColor: AppColors.errorLight,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#FFCDD2',
  },
  errorIcon: {
    fontSize: 20,
    marginRight: 8,
  },
  errorText: {
    flex: 1,
    fontSize: 14,
    color: AppColors.error,
    marginRight: 8,
  },
  errorDismiss: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    justifyContent: 'center',
  },
  errorDismissPressed: {
    opacity: 0.6,
  },
  errorDismissText: {
    fontSize: 18,
    color: AppColors.error,
    fontWeight: '600',
  },
});
