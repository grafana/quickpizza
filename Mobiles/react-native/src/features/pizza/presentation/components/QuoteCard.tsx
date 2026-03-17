import React, { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { getQuote } from '../../domain/pizzaRepository';

export function QuoteCard() {
  const [quote, setQuote] = useState('');

  useEffect(() => {
    getQuote().then(setQuote);
  }, []);

  if (!quote) return null;

  return (
    <View style={styles.container}>
      <Text style={styles.quoteIcon}>"</Text>
      <Text style={styles.quote}>{quote}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 10,
    elevation: 2,
  },
  quoteIcon: {
    fontSize: 24,
    color: '#FFB74D',
    marginRight: 12,
  },
  quote: {
    flex: 1,
    fontSize: 14,
    fontStyle: 'italic',
    color: '#616161',
  },
});
