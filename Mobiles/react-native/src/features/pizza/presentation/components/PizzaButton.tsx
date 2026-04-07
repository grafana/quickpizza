import React from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text } from 'react-native';

import { withUserAction } from '../../../../core/o11y/o11yReactNative';

interface PizzaButtonProps {
  onPress: () => void;
  isLoading: boolean;
}

const TrackedPressable = withUserAction(Pressable, 'get-pizza-recommendation');

export function PizzaButton({ onPress, isLoading }: PizzaButtonProps) {
  return (
    <TrackedPressable
      onPress={onPress}
      disabled={isLoading}
      style={[styles.button, isLoading && styles.buttonDisabled]}
    >
      {isLoading ? (
        <ActivityIndicator color="#FFFFFF" />
      ) : (
        <Text style={styles.text}>Pizza, Please!</Text>
      )}
    </TrackedPressable>
  );
}

const styles = StyleSheet.create({
  button: {
    backgroundColor: '#F15B2A',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 52,
  },
  buttonDisabled: {
    opacity: 0.7,
  },
  text: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
});
