import React from 'react';
import { StyleSheet, Text, View } from 'react-native';

import type { PizzaRecommendation } from '../../models/pizza';
import { RatingButtons } from './RatingButtons';

interface PizzaCardProps {
  recommendation: PizzaRecommendation;
}

export function PizzaCard({ recommendation }: PizzaCardProps) {
  const { pizza } = recommendation;

  return (
    <View style={styles.container}>
      <View style={styles.card}>
        <View style={styles.header}>
          <Text style={styles.headerIcon}>🍕</Text>
          <View style={styles.headerText}>
            <Text style={styles.subtitle}>Our recommendation</Text>
            <Text style={styles.title}>{pizza.name}</Text>
          </View>
        </View>

        <View style={styles.divider} />

        <View style={styles.details}>
          <DetailRow icon="📄" label="Dough" value={pizza.dough.name} />
          <DetailRow icon="🍴" label="Tool" value={pizza.tool} />
          <DetailRow
            icon="🔥"
            label="Calories"
            value={
              recommendation.calories != null
                ? `${recommendation.calories} per slice`
                : 'N/A'
            }
          />
        </View>

        {recommendation.vegetarian === true && (
          <View style={styles.vegetarianBadge}>
            <Text style={styles.vegetarianIcon}>🌱</Text>
            <Text style={styles.vegetarianText}>Vegetarian</Text>
          </View>
        )}

        <View style={styles.ingredients}>
          <Text style={styles.ingredientsLabel}>Ingredients</Text>
          <View style={styles.ingredientsList}>
            {pizza.ingredients.map((ing) => (
              <View key={ing.id} style={styles.ingredientChip}>
                <Text style={styles.ingredientText}>{ing.name}</Text>
              </View>
            ))}
          </View>
        </View>
      </View>

      <RatingButtons recommendation={recommendation} />
    </View>
  );
}

function DetailRow({
  icon,
  label,
  value,
}: {
  icon: string;
  label: string;
  value: string;
}) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailIcon}>{icon}</Text>
      <Text style={styles.detailLabel}>{label}: </Text>
      <Text style={styles.detailValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginTop: 24,
  },
  card: {
    padding: 20,
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    shadowColor: '#F15B2A',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 20,
    elevation: 4,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  headerIcon: {
    fontSize: 28,
    marginRight: 12,
  },
  headerText: {
    flex: 1,
  },
  subtitle: {
    fontSize: 12,
    color: '#9E9E9E',
    fontWeight: '500',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#212121',
  },
  divider: {
    height: 1,
    backgroundColor: '#EEE',
    marginVertical: 16,
  },
  details: {
    gap: 8,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  detailIcon: {
    fontSize: 18,
    marginRight: 8,
  },
  detailLabel: {
    fontSize: 14,
    color: '#757575',
  },
  detailValue: {
    fontSize: 14,
    fontWeight: '500',
    color: '#212121',
  },
  vegetarianBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    paddingHorizontal: 10,
    paddingVertical: 4,
    backgroundColor: '#E8F5E9',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#A5D6A7',
    marginTop: 12,
  },
  vegetarianIcon: {
    fontSize: 16,
    marginRight: 4,
  },
  vegetarianText: {
    fontSize: 12,
    color: '#2E7D32',
    fontWeight: '500',
  },
  ingredients: {
    marginTop: 16,
  },
  ingredientsLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212121',
    marginBottom: 8,
  },
  ingredientsList: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  ingredientChip: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    backgroundColor: '#F5F5F5',
    borderRadius: 16,
  },
  ingredientText: {
    fontSize: 12,
    color: '#616161',
  },
});
