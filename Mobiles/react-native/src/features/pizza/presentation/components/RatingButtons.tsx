import React, { useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { withUserAction } from '../../../../core/o11y/o11yReactNative';

import { trackEvent } from '../../../../core/o11y/o11yEvents';
import {
  type AuthState,
  useAuthStore,
} from '../../../auth/domain/authStore';
import type { PizzaRecommendation } from '../../models/pizza';
import * as ratingsRepository from '../../../ratings/domain/ratingsRepository';

const TrackedRatingButton = withUserAction(Pressable, 'rate-pizza');

interface RatingButtonsProps {
  recommendation: PizzaRecommendation;
}

export function RatingButtons({ recommendation }: RatingButtonsProps) {
  const [isLoading, setIsLoading] = useState(false);
  const [rateResult, setRateResult] = useState<string | null>(null);
  const isLoggedIn = useAuthStore((s: AuthState) => s.isLoggedIn);
  const pizzaId = recommendation.pizza.id;

  const ratePizza = async (stars: number) => {
    if (!isLoggedIn) {
      setRateResult('Please log in first');
      return;
    }

    trackEvent('pizza_rated', {
      pizza_id: String(pizzaId),
      stars: String(stars),
    });
    setIsLoading(true);
    setRateResult(null);

    try {
      await ratingsRepository.ratePizza(pizzaId, stars);
      setRateResult(stars >= 4 ? 'Thanks! We\'re glad you liked it!' : 'Thanks for your feedback!');
    } catch (error) {
      setRateResult(
        error instanceof Error ? error.message : 'Failed to submit rating',
      );
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.buttons}>
        <TrackedRatingButton
          faroContext={{ stars: '1' }}
          onPress={() => ratePizza(1)}
          disabled={isLoading}
          style={[styles.button, styles.buttonSecondary]}
        >
          {isLoading ? (
            <ActivityIndicator size="small" color="#757575" />
          ) : (
            <>
              <Text style={styles.buttonIcon}>👎</Text>
              <Text style={styles.buttonLabelSecondary}>No thanks</Text>
            </>
          )}
        </TrackedRatingButton>
        <TrackedRatingButton
          faroContext={{ stars: '5' }}
          onPress={() => ratePizza(5)}
          disabled={isLoading}
          style={[styles.button, styles.buttonPrimary]}
        >
          {isLoading ? (
            <ActivityIndicator size="small" color="#FFFFFF" />
          ) : (
            <>
              <Text style={styles.buttonIcon}>❤️</Text>
              <Text style={styles.buttonLabelPrimary}>Love it</Text>
            </>
          )}
        </TrackedRatingButton>
      </View>
      {rateResult != null && (
        <Text style={styles.result}>{rateResult}</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginTop: 20,
  },
  buttons: {
    flexDirection: 'row',
    gap: 16,
  },
  button: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingVertical: 14,
    borderRadius: 12,
  },
  buttonPrimary: {
    backgroundColor: '#E53935',
  },
  buttonSecondary: {
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  buttonIcon: {
    fontSize: 18,
  },
  buttonLabelPrimary: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '500',
  },
  buttonLabelSecondary: {
    color: '#616161',
    fontSize: 16,
    fontWeight: '500',
  },
  result: {
    marginTop: 12,
    fontSize: 14,
    fontWeight: '500',
    color: '#616161',
    textAlign: 'center',
  },
});
