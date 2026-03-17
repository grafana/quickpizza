import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useAuthStore } from '../../auth/domain/authStore';
import type { Rating } from '../../ratings/domain/ratingsRepository';
import {
  deleteRatings,
  getRatings,
} from '../../ratings/domain/ratingsRepository';

interface ProfileScreenProps {
  onBack: () => void;
}

export function ProfileScreen({ onBack }: ProfileScreenProps) {
  const { username, logout } = useAuthStore();
  const [ratings, setRatings] = useState<Rating[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    getRatings()
      .then(setRatings)
      .finally(() => setLoading(false));
  }, []);

  const handleLogout = async () => {
    setActionLoading(true);
    await logout();
    setActionLoading(false);
    onBack();
  };

  const handleClearRatings = async () => {
    setActionLoading(true);
    try {
      await deleteRatings();
      setRatings([]);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Failed to clear ratings. Please try again.';
      Alert.alert('Error', message);
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <Pressable onPress={onBack} style={styles.backButton}>
          <Text style={styles.backText}>← Back</Text>
        </Pressable>
        <Text style={styles.title}>Profile</Text>
      </View>

      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.profileCard}>
          <View style={styles.avatarContainer}>
            <Text style={styles.avatarIcon}>👤</Text>
          </View>
          <Text style={styles.username}>{username ?? 'Pizza Lover'}</Text>
          {loading ? (
            <ActivityIndicator size="small" color="#757575" />
          ) : (
            <Text style={styles.ratingsCount}>
              {ratings.length} pizza{ratings.length !== 1 ? 's' : ''} rated
            </Text>
          )}
        </View>

        <View style={styles.ratingsSection}>
          <View style={styles.ratingsHeader}>
            <Text style={styles.starIcon}>⭐</Text>
            <Text style={styles.sectionTitle}>Your ratings</Text>
          </View>
          {loading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator />
            </View>
          ) : ratings.length === 0 ? (
            <View style={styles.emptyState}>
              <Text style={styles.emptyIcon}>🍕</Text>
              <Text style={styles.emptyTitle}>No ratings yet</Text>
              <Text style={styles.emptySubtitle}>Rate some pizzas to see them here</Text>
            </View>
          ) : (
            ratings.map((r) => (
              <View key={r.id} style={styles.ratingRow}>
                <View
                  style={[
                    styles.ratingIcon,
                    r.stars >= 4 ? styles.ratingIconLove : styles.ratingIconPass,
                  ]}
                >
                  <Text style={styles.ratingEmoji}>{r.stars >= 4 ? '❤️' : '👎'}</Text>
                </View>
                <View style={styles.ratingContent}>
                  <Text style={styles.ratingPizza}>Pizza #{r.pizzaId}</Text>
                  <Text style={styles.ratingLabel}>
                    {r.stars >= 4 ? 'Loved it' : 'No thanks'}
                  </Text>
                </View>
                <View style={styles.stars}>
                  {[1, 2, 3, 4, 5].map((i) => (
                    <Text key={i} style={styles.star}>
                      {i <= r.stars ? '★' : '☆'}
                    </Text>
                  ))}
                </View>
              </View>
            ))
          )}
        </View>

        <View style={styles.actions}>
          {ratings.length > 0 && (
            <Pressable
              onPress={handleClearRatings}
              disabled={actionLoading}
              style={[styles.button, styles.clearButton]}
            >
              <Text style={styles.clearButtonText}>Clear ratings</Text>
            </Pressable>
          )}
          <Pressable
            onPress={handleLogout}
            disabled={actionLoading}
            style={[styles.button, styles.logoutButton]}
          >
            <Text style={styles.logoutButtonText}>Sign out</Text>
          </Pressable>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFF5F0',
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
  scroll: {
    flex: 1,
  },
  content: {
    padding: 24,
  },
  profileCard: {
    alignItems: 'center',
    padding: 24,
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 10,
    elevation: 2,
    marginBottom: 24,
  },
  avatarContainer: {
    width: 96,
    height: 96,
    borderRadius: 48,
    backgroundColor: '#FFF3E0',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
  },
  avatarIcon: {
    fontSize: 48,
  },
  username: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#212121',
  },
  ratingsCount: {
    fontSize: 14,
    color: '#757575',
    marginTop: 4,
  },
  ratingsSection: {
    padding: 20,
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 10,
    elevation: 2,
    marginBottom: 24,
  },
  ratingsHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  starIcon: {
    fontSize: 22,
    marginRight: 8,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#212121',
  },
  loadingContainer: {
    padding: 24,
    alignItems: 'center',
  },
  emptyState: {
    alignItems: 'center',
    padding: 24,
  },
  emptyIcon: {
    fontSize: 48,
    marginBottom: 12,
    opacity: 0.5,
  },
  emptyTitle: {
    fontSize: 16,
    color: '#757575',
  },
  emptySubtitle: {
    fontSize: 13,
    color: '#9E9E9E',
    marginTop: 4,
  },
  ratingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#EEE',
  },
  ratingIcon: {
    width: 36,
    height: 36,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  ratingIconLove: {
    backgroundColor: '#FFEBEE',
  },
  ratingIconPass: {
    backgroundColor: '#F5F5F5',
  },
  ratingEmoji: {
    fontSize: 18,
  },
  ratingContent: {
    flex: 1,
  },
  ratingPizza: {
    fontWeight: '600',
    color: '#212121',
  },
  ratingLabel: {
    fontSize: 13,
    color: '#757575',
    marginTop: 2,
  },
  stars: {
    flexDirection: 'row',
    gap: 2,
  },
  star: {
    fontSize: 16,
    color: '#FF9800',
  },
  actions: {
    flexDirection: 'row',
    gap: 12,
  },
  button: {
    flex: 1,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
  },
  clearButton: {
    borderWidth: 1,
    borderColor: '#EF5350',
  },
  clearButtonText: {
    color: '#C62828',
    fontSize: 16,
    fontWeight: '500',
  },
  logoutButton: {
    backgroundColor: '#757575',
  },
  logoutButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '500',
  },
});
