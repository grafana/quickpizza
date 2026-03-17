import React, { useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { QuickPizzaAppBar } from '../../../core/components/QuickPizzaAppBar';
import { AppColors } from '../../../core/theme/appColors';
import { defaultRestrictions } from '../models/restrictions';
import type { Restrictions } from '../models/restrictions';
import { usePizzaStore } from '../domain/pizzaStore';
import { CustomizeSection } from './components/CustomizeSection';
import { HeroText } from './components/HeroText';
import { PizzaButton } from './components/PizzaButton';
import { PizzaCard } from './components/PizzaCard';
import { QuoteCard } from './components/QuoteCard';

interface HomeScreenProps {
  onProfilePress: () => void;
}

export function HomeScreen({ onProfilePress }: HomeScreenProps) {
  const [restrictions, setRestrictions] = useState<Restrictions>(defaultRestrictions);
  const { pizza, isLoading, errorMessage, getPizza } = usePizzaStore();

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <QuickPizzaAppBar onProfilePress={onProfilePress} />
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <QuoteCard />
        <View style={styles.spacer} />
        <HeroText />
        <View style={styles.spacer} />
        <CustomizeSection
          restrictions={restrictions}
          onRestrictionsChange={setRestrictions}
        />
        <View style={styles.spacer} />
        <PizzaButton
          onPress={() => getPizza(restrictions)}
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
  },
});
