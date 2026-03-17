import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

export function HeroText() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Get a pizza recommendation</Text>
      <Text style={styles.subtitle}>
        Customize your preferences and tap the button below
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#212121',
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 14,
    color: '#757575',
    marginTop: 8,
    textAlign: 'center',
  },
});
