import React from 'react';
import {
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { useAuthStore } from '../../features/auth/domain/authStore';
import { AppColors } from '../theme/appColors';

interface QuickPizzaAppBarProps {
  onProfilePress: () => void;
}

export function QuickPizzaAppBar({ onProfilePress }: QuickPizzaAppBarProps) {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);

  return (
    <View style={styles.container}>
      <View style={styles.titleRow}>
        <Text style={styles.icon}>🍕</Text>
        <Text style={styles.title}>QuickPizza</Text>
      </View>
      <Pressable
        onPress={onProfilePress}
        style={[styles.avatar, isLoggedIn ? styles.avatarLoggedIn : styles.avatarLoggedOut]}
        accessibilityLabel={isLoggedIn ? 'Go to profile' : 'Log in'}
      >
        <Text style={styles.avatarIcon}>{isLoggedIn ? '👤' : '🔓'}</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: AppColors.white,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  icon: {
    fontSize: 28,
  },
  title: {
    color: AppColors.primary,
    fontWeight: 'bold',
    fontSize: 20,
  },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarLoggedIn: {
    backgroundColor: AppColors.primary,
  },
  avatarLoggedOut: {
    backgroundColor: '#E0E0E0',
  },
  avatarIcon: {
    fontSize: 18,
  },
});
