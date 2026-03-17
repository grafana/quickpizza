import React from 'react';
import { Linking, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { QuickPizzaAppBar } from '../../../core/components/QuickPizzaAppBar';
import { getBaseUrlConfig } from '../../../core/config/configService';
import { AppColors } from '../../../core/theme/appColors';

const FEATURES = [
  'Get pizza recommendations with one click',
  'Rate pizzas (Love it! or No thanks)',
  'User login and profile management',
  'Advanced customization options',
  'View your pizza ratings history',
];

const LINKS = [
  {
    title: 'Grafana Faro',
    subtitle: 'Frontend Observability',
    url: 'https://grafana.com/docs/grafana-cloud/monitor-applications/frontend-observability/',
  },
  {
    title: 'QuickPizza',
    subtitle: 'Demo application',
    url: 'https://github.com/grafana/quickpizza',
  },
];

interface AboutScreenProps {
  onProfilePress: () => void;
}

export function AboutScreen({ onProfilePress }: AboutScreenProps) {
  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <QuickPizzaAppBar onProfilePress={onProfilePress} />
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.header}>
          <Text style={styles.headerIcon}>🍕</Text>
          <Text style={styles.title}>About QuickPizza</Text>
          <Text style={styles.subtitle}>
            A demo app for mobile observability with Grafana Faro
          </Text>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Links</Text>
          {LINKS.map((link) => (
            <Pressable
              key={link.url}
              style={styles.linkCard}
              onPress={() => Linking.openURL(link.url)}
            >
              <View style={styles.linkContent}>
                <Text style={styles.linkTitle}>{link.title}</Text>
                <Text style={styles.linkSubtitle}>{link.subtitle}</Text>
              </View>
              <Text style={styles.linkArrow}>→</Text>
            </Pressable>
          ))}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>About this demo</Text>
          <View style={styles.aboutCard}>
            <Text style={styles.aboutText}>
              This React Native app demonstrates Grafana Faro SDK integration for
              mobile observability. It connects to the QuickPizza backend and
              sends telemetry to Grafana Cloud.
            </Text>
            <Text style={styles.featuresTitle}>Features:</Text>
            {FEATURES.map((f) => (
              <View key={f} style={styles.featureRow}>
                <Text style={styles.featureBullet}>•</Text>
                <Text style={styles.featureText}>{f}</Text>
              </View>
            ))}
          </View>
        </View>

        <View style={styles.footer}>
          <Text style={styles.footerText}>Made with ❤️</Text>
          <Text style={styles.footerFaro}>Powered by Grafana Faro</Text>
          <Pressable
            onPress={() => Linking.openURL(`${getBaseUrlConfig()}/admin`)}
            style={styles.adminLink}
          >
            <Text style={styles.adminLinkText}>
              Looking for the admin page? <Text style={styles.adminLinkHighlight}>Tap here</Text>
            </Text>
          </Pressable>
          <Text style={styles.version}>Version 1.0.0</Text>
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
    padding: 24,
  },
  header: {
    alignItems: 'center',
    marginBottom: 40,
  },
  headerIcon: {
    fontSize: 64,
    marginBottom: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#212121',
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    color: '#757575',
    marginTop: 8,
    textAlign: 'center',
  },
  section: {
    marginBottom: 40,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#212121',
    marginBottom: 12,
  },
  linkCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  linkContent: {
    flex: 1,
  },
  linkTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212121',
  },
  linkSubtitle: {
    fontSize: 13,
    color: '#757575',
    marginTop: 2,
  },
  linkArrow: {
    fontSize: 18,
    color: AppColors.primary,
  },
  aboutCard: {
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  aboutText: {
    fontSize: 14,
    color: '#212121',
    lineHeight: 22,
  },
  featuresTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212121',
    marginTop: 12,
    marginBottom: 8,
  },
  featureRow: {
    flexDirection: 'row',
    marginBottom: 4,
  },
  featureBullet: {
    marginRight: 8,
    color: AppColors.primary,
  },
  featureText: {
    flex: 1,
    fontSize: 14,
    color: '#212121',
  },
  footer: {
    alignItems: 'center',
    marginBottom: 24,
  },
  footerText: {
    fontSize: 14,
    color: '#757575',
  },
  footerFaro: {
    fontSize: 12,
    color: '#9E9E9E',
    marginTop: 8,
  },
  adminLink: {
    marginTop: 12,
  },
  adminLinkText: {
    fontSize: 12,
    color: '#757575',
    textAlign: 'center',
  },
  adminLinkHighlight: {
    color: AppColors.primary,
    fontWeight: '600',
  },
  version: {
    fontSize: 12,
    color: '#BDBDBD',
    marginTop: 4,
  },
});
