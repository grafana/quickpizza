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

import { AppColors } from '../../../core/theme/appColors';
import { useAdminStore } from '../domain/adminStore';

const AdminLoginButton = withFaroUserAction(Pressable, 'adminLogin');

interface AdminScreenProps {
  onBack: () => void;
  onProfilePress: () => void;
}

export function AdminScreen({ onBack, onProfilePress }: AdminScreenProps) {
  const {
    isLoggedIn,
    isLoading,
    loginError,
    recommendations,
    recommendationsLoading,
    login,
    logout,
    restoreSession,
    fetchRecommendations,
    clearLoginError,
  } = useAdminStore();

  const [username, setUsername] = React.useState('admin');
  const [password, setPassword] = React.useState('admin');

  useEffect(() => {
    restoreSession();
  }, [restoreSession]);

  const handleLogin = async () => {
    const success = await login(username, password);
    if (success) {
      clearLoginError();
    }
  };

  const handleLogout = async () => {
    await logout();
  };

  if (isLoggedIn) {
    return (
      <SafeAreaView style={styles.container} edges={['top']}>
        <View style={styles.screenHeader}>
          <Pressable onPress={onBack} style={styles.backButton}>
            <Text style={styles.backText}>← Back</Text>
          </Pressable>
          <Text style={styles.screenHeaderTitle}>Admin</Text>
        </View>
        <ScrollView
          style={styles.scroll}
          contentContainerStyle={styles.content}
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.header}>
            <Text style={styles.title}>QuickPizza Administration</Text>
            <Text style={styles.subtitle}>
              Latest pizza recommendations (tap Refresh to reload)
            </Text>
          </View>

          <View style={styles.buttonRow}>
            <Pressable style={styles.refreshButton} onPress={fetchRecommendations} disabled={recommendationsLoading}>
              {recommendationsLoading ? (
                <ActivityIndicator color="#FFFFFF" size="small" />
              ) : (
                <View style={styles.refreshButtonContent}>
                  <Text style={styles.refreshIcon}>🔄</Text>
                  <Text style={styles.refreshButtonText}>Refresh</Text>
                </View>
              )}
            </Pressable>
            <Pressable style={styles.logoutButton} onPress={handleLogout}>
              <Text style={styles.logoutButtonText}>Logout</Text>
            </Pressable>
          </View>

          <View style={styles.listSection}>
            {recommendations.length === 0 && !recommendationsLoading ? (
              <View style={styles.emptyState}>
                <Text style={styles.emptyIcon}>🍕</Text>
                <Text style={styles.emptyText}>No recommendations yet</Text>
                <Text style={styles.emptySubtext}>
                  Generate pizzas on the Home tab to see them here
                </Text>
              </View>
            ) : (
              recommendations.slice(0, 15).map((pizza, index) => (
                <View
                  key={pizza.id}
                  style={[
                    styles.pizzaCard,
                    index === 0 && styles.pizzaCardNewest,
                  ]}
                >
                  <View style={styles.pizzaCardHeader}>
                    <View style={styles.pizzaIconContainer}>
                      <Text style={styles.pizzaIcon}>🍕</Text>
                    </View>
                    <View style={styles.pizzaCardTitleRow}>
                      <Text style={styles.pizzaCardName} numberOfLines={2}>
                        {pizza.name}
                      </Text>
                      {index === 0 && (
                        <View style={styles.newestBadge}>
                          <Text style={styles.newestBadgeText}>Newest</Text>
                        </View>
                      )}
                    </View>
                  </View>
                  <View style={styles.pizzaCardMeta}>
                    <View style={styles.pizzaMetaChip}>
                      <Text style={styles.pizzaMetaIcon}>🔪</Text>
                      <Text style={styles.pizzaMetaText}>{pizza.tool}</Text>
                    </View>
                    <View style={styles.pizzaMetaChip}>
                      <Text style={styles.pizzaMetaIcon}>🥫</Text>
                      <Text style={styles.pizzaMetaText}>
                        {pizza.ingredients?.length ?? 0} ingredients
                      </Text>
                    </View>
                    {pizza.dough?.name && (
                      <View style={styles.pizzaMetaChip}>
                        <Text style={styles.pizzaMetaIcon}>🥖</Text>
                        <Text style={styles.pizzaMetaText}>{pizza.dough.name}</Text>
                      </View>
                    )}
                  </View>
                </View>
              ))
            )}
          </View>
        </ScrollView>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.screenHeader}>
        <Pressable onPress={onBack} style={styles.backButton}>
          <Text style={styles.backText}>← Back</Text>
        </Pressable>
        <Text style={styles.screenHeaderTitle}>Admin</Text>
      </View>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.loginHeader}>
          <Text style={styles.loginTitle}>QuickPizza Administration</Text>
          <Text style={styles.loginHint}>Sign in to manage pizzas and ingredients</Text>
        </View>

        <View style={styles.form}>
          <Text style={styles.label}>Username (hint: admin)</Text>
          <TextInput
            style={styles.input}
            value={username}
            onChangeText={setUsername}
            placeholder="Username"
            autoCapitalize="none"
            autoCorrect={false}
          />
          <Text style={styles.label}>Password (hint: admin)</Text>
          <TextInput
            style={styles.input}
            value={password}
            onChangeText={setPassword}
            placeholder="Password"
            secureTextEntry
          />
          {loginError != null && (
            <View style={styles.error}>
              <Text style={styles.errorIcon}>⚠️</Text>
              <Text style={styles.errorText}>{loginError}</Text>
            </View>
          )}
          <AdminLoginButton
            onPress={handleLogin}
            disabled={isLoading}
            style={[styles.loginButton, isLoading && styles.buttonDisabled]}
          >
            {isLoading ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <Text style={styles.loginButtonText}>Sign in</Text>
            )}
          </AdminLoginButton>
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
  screenHeader: {
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
  screenHeaderTitle: {
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
  scrollContent: {
    padding: 24,
    paddingTop: 32,
  },
  header: {
    marginBottom: 24,
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#212121',
  },
  subtitle: {
    fontSize: 16,
    color: '#757575',
    marginTop: 8,
  },
  loginHeader: {
    marginBottom: 24,
  },
  loginTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#212121',
    textAlign: 'center',
  },
  loginHint: {
    fontSize: 15,
    color: '#757575',
    textAlign: 'center',
    marginTop: 8,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 24,
  },
  refreshButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    paddingHorizontal: 20,
    backgroundColor: AppColors.primary,
    borderRadius: 12,
    minWidth: 120,
  },
  refreshButtonContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  refreshIcon: {
    fontSize: 16,
  },
  refreshButtonText: {
    fontSize: 14,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  logoutButton: {
    paddingVertical: 12,
    paddingHorizontal: 20,
    backgroundColor: '#E0E0E0',
    borderRadius: 12,
    justifyContent: 'center',
  },
  logoutButtonText: {
    fontSize: 14,
    color: '#424242',
    fontWeight: '600',
  },
  listSection: {
    gap: 12,
  },
  pizzaCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: '#E8E8E8',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 3,
  },
  pizzaCardNewest: {
    borderColor: AppColors.primary,
    borderWidth: 2,
    backgroundColor: '#FFFBF9',
  },
  pizzaCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  pizzaIconContainer: {
    width: 44,
    height: 44,
    borderRadius: 12,
    backgroundColor: '#FFF3E0',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  pizzaIcon: {
    fontSize: 24,
  },
  pizzaCardTitleRow: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    flexWrap: 'wrap',
  },
  pizzaCardName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212121',
    flex: 1,
  },
  newestBadge: {
    backgroundColor: AppColors.primary,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  newestBadgeText: {
    fontSize: 11,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  pizzaCardMeta: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  pizzaMetaChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F5F5F5',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 10,
  },
  pizzaMetaIcon: {
    fontSize: 12,
    marginRight: 4,
  },
  pizzaMetaText: {
    fontSize: 12,
    color: '#616161',
  },
  emptyState: {
    alignItems: 'center',
    padding: 32,
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#E8E8E8',
    borderStyle: 'dashed',
  },
  emptyIcon: {
    fontSize: 48,
    marginBottom: 12,
  },
  emptyText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#757575',
    marginBottom: 4,
  },
  emptySubtext: {
    fontSize: 13,
    color: '#9E9E9E',
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
});
