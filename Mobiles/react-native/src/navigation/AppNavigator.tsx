import React from 'react';
import {
  NavigationContainer,
  useNavigation,
  useNavigationContainerRef,
} from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';

import { useFaroNavigation } from '@grafana/faro-react-native';

import { AboutScreen } from '../features/about/presentation/AboutScreen';
import { HomeScreen } from '../features/pizza/presentation/HomeScreen';
import { LoginScreen } from '../features/auth/presentation/LoginScreen';
import { ProfileScreen } from '../features/profile/presentation/ProfileScreen';
import { useAuthStore } from '../features/auth/domain/authStore';

export type RootStackParamList = {
  Main: undefined;
  Login: undefined;
  Profile: undefined;
};

export type TabParamList = {
  Home: undefined;
  About: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();
const Tab = createBottomTabNavigator<TabParamList>();

function MainTabs({
  rootNavigation,
}: {
  rootNavigation: NativeStackNavigationProp<RootStackParamList>;
}) {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);

  const handleProfilePress = () => {
    if (isLoggedIn) {
      rootNavigation.navigate('Profile');
    } else {
      rootNavigation.navigate('Login');
    }
  };

  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: '#F15B2A',
        tabBarInactiveTintColor: '#757575',
        tabBarStyle: {
          backgroundColor: '#FFFFFF',
          borderTopColor: '#EEE',
        },
      }}
    >
      <Tab.Screen
        name="Home"
        options={{ tabBarLabel: 'Home', tabBarIcon: () => null }}
      >
        {() => <HomeScreen onProfilePress={handleProfilePress} />}
      </Tab.Screen>
      <Tab.Screen
        name="About"
        options={{ tabBarLabel: 'About', tabBarIcon: () => null }}
      >
        {() => <AboutScreen onProfilePress={handleProfilePress} />}
      </Tab.Screen>
    </Tab.Navigator>
  );
}

function MainTabsWrapper() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  return <MainTabs rootNavigation={navigation} />;
}

function LoginScreenWrapper() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const handleBack = () => {
    if (navigation.canGoBack()) {
      navigation.goBack();
    } else {
      navigation.navigate('Main');
    }
  };
  return (
    <LoginScreen
      onBack={handleBack}
      onSuccess={handleBack}
    />
  );
}

function ProfileScreenWrapper() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const handleBack = () => {
    if (navigation.canGoBack()) {
      navigation.goBack();
    } else {
      navigation.navigate('Main');
    }
  };
  return <ProfileScreen onBack={handleBack} />;
}

export function AppNavigator() {
  const navigationRef = useNavigationContainerRef<RootStackParamList>();
  useFaroNavigation(navigationRef);

  return (
    <NavigationContainer ref={navigationRef}>
      <Stack.Navigator
        screenOptions={{
          headerShown: false,
          animation: 'slide_from_right',
        }}
      >
        <Stack.Screen name="Main" component={MainTabsWrapper} />
        <Stack.Screen
          name="Login"
          component={LoginScreenWrapper}
          options={{ presentation: 'modal' }}
        />
        <Stack.Screen
          name="Profile"
          component={ProfileScreenWrapper}
          options={{ presentation: 'modal' }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
