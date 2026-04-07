import React, { useState } from 'react';
import {
  Pressable,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';

import type { Restrictions } from '../../models/restrictions';
import { defaultRestrictions } from '../../models/restrictions';
import { getTools } from '../../domain/pizzaRepository';

interface CustomizeSectionProps {
  restrictions: Restrictions;
  onRestrictionsChange: (r: Restrictions) => void;
}

export function CustomizeSection({
  restrictions,
  onRestrictionsChange,
}: CustomizeSectionProps) {
  const [expanded, setExpanded] = useState(false);
  const [tools, setTools] = useState<string[]>([]);

  React.useEffect(() => {
    getTools().then(setTools);
  }, []);

  const toggleTool = (tool: string) => {
    const excluded = restrictions.excludedTools.includes(tool)
      ? restrictions.excludedTools.filter((t) => t !== tool)
      : [...restrictions.excludedTools, tool];
    onRestrictionsChange({ ...restrictions, excludedTools: excluded });
  };

  return (
    <View style={styles.container}>
      <Pressable
        onPress={() => setExpanded(!expanded)}
        style={styles.header}
      >
        <Text style={styles.headerIcon}>⚙️</Text>
        <Text style={styles.headerTitle}>Customize your pizza</Text>
        <Text style={styles.chevron}>{expanded ? '▲' : '▼'}</Text>
      </Pressable>

      {expanded && (
        <View style={styles.content}>
          <View style={styles.row}>
            <View style={styles.field}>
              <Text style={styles.label}>Max calories</Text>
              <TextInput
                style={styles.input}
                value={String(restrictions.maxCaloriesPerSlice)}
                onChangeText={(t) =>
                  onRestrictionsChange({
                    ...restrictions,
                    maxCaloriesPerSlice: parseInt(t, 10) || defaultRestrictions.maxCaloriesPerSlice,
                  })
                }
                keyboardType="numeric"
              />
            </View>
            <View style={styles.field}>
              <Text style={styles.label}>Min toppings</Text>
              <TextInput
                style={styles.input}
                value={String(restrictions.minNumberOfToppings)}
                onChangeText={(t) =>
                  onRestrictionsChange({
                    ...restrictions,
                    minNumberOfToppings: parseInt(t, 10) || defaultRestrictions.minNumberOfToppings,
                  })
                }
                keyboardType="numeric"
              />
            </View>
            <View style={styles.field}>
              <Text style={styles.label}>Max toppings</Text>
              <TextInput
                style={styles.input}
                value={String(restrictions.maxNumberOfToppings)}
                onChangeText={(t) =>
                  onRestrictionsChange({
                    ...restrictions,
                    maxNumberOfToppings: parseInt(t, 10) || defaultRestrictions.maxNumberOfToppings,
                  })
                }
                keyboardType="numeric"
              />
            </View>
          </View>

          <View style={styles.toggleRow}>
            <Text style={styles.toggleLabel}>Vegetarian only</Text>
            <Switch
              value={restrictions.mustBeVegetarian}
              onValueChange={(v) =>
                onRestrictionsChange({ ...restrictions, mustBeVegetarian: v })
              }
              trackColor={{ false: '#E0E0E0', true: '#4CAF50' }}
              thumbColor="#FFFFFF"
            />
          </View>

          {tools.length > 0 && (
            <View style={styles.toolsSection}>
              <Text style={styles.label}>Exclude tools</Text>
              <View style={styles.chips}>
                {tools.map((tool) => {
                  const selected = restrictions.excludedTools.includes(tool);
                  return (
                    <Pressable
                      key={tool}
                      onPress={() => toggleTool(tool)}
                      style={[
                        styles.chip,
                        selected && styles.chipSelected,
                      ]}
                    >
                      <Text
                        style={[
                          styles.chipText,
                          selected && styles.chipTextSelected,
                        ]}
                      >
                        {tool}
                      </Text>
                    </Pressable>
                  );
                })}
              </View>
            </View>
          )}

          <View style={styles.field}>
            <Text style={styles.label}>Custom pizza name</Text>
            <TextInput
              style={styles.input}
              value={restrictions.customName}
              onChangeText={(t) =>
                onRestrictionsChange({ ...restrictions, customName: t })
              }
              placeholder="Optional"
            />
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 10,
    elevation: 2,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
  },
  headerIcon: {
    fontSize: 20,
    marginRight: 12,
  },
  headerTitle: {
    flex: 1,
    fontSize: 16,
    fontWeight: '600',
  },
  chevron: {
    fontSize: 12,
    color: '#757575',
  },
  content: {
    padding: 16,
    paddingTop: 0,
    borderTopWidth: 1,
    borderTopColor: '#EEE',
  },
  row: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 16,
  },
  field: {
    flex: 1,
  },
  label: {
    fontSize: 12,
    color: '#757575',
    marginBottom: 4,
  },
  input: {
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
    padding: 12,
    fontSize: 14,
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 8,
    marginBottom: 16,
  },
  toggleLabel: {
    fontSize: 14,
  },
  toolsSection: {
    marginBottom: 16,
  },
  chips: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 8,
  },
  chip: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 16,
    backgroundColor: '#F5F5F5',
  },
  chipSelected: {
    backgroundColor: '#FFCDD2',
  },
  chipText: {
    fontSize: 12,
    color: '#616161',
  },
  chipTextSelected: {
    color: '#C62828',
  },
});
