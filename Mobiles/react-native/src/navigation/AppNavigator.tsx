import React from 'react';
import {
  NavigationContainer,
  useNavigation,
  useNavigationContainerRef,
} from '@react-navigation/native';
import MaterialIcons from '@react-native-vector-icons/material-icons';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';

import { useO11yNavigation } from '../core/o11y/o11yReactNative';

import { AboutScreen } from '../features/about/presentation/AboutScreen';
import { AdminScreen } from '../features/admin/presentation/AdminScreen';
import { HomeScreen } from '../features/pizza/presentation/HomeScreen';
import { LoginScreen } from '../features/auth/presentation/LoginScreen';
import { ProfileScreen } from '../features/profile/presentation/ProfileScreen';
import { useAuthStore } from '../features/auth/domain/authStore';
import { ConfigScreen } from '../features/debug/presentation/ConfigScreen';
import { DebugScreen } from '../features/debug/presentation/DebugScreen';

export type RootStackParamList = {
  Main: undefined;
  Login: undefined;
  Profile: undefined;
  Admin: undefined;
  DebugConfig: undefined;
};

export type TabParamList = {
  Home: undefined;
  About: undefined;
  Debug: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();
const Tab = createBottomTabNavigator<TabParamList>();

function HomeTabIcon({color, size}: {color: string; size: number}) {
  return <MaterialIcons name="home" size={size} color={color} />;
}

function AboutTabIcon({color, size}: {color: string; size: number}) {
  return <MaterialIcons name="info" size={size} color={color} />;
}

function DebugTabIcon({color, size}: {color: string; size: number}) {
  return <MaterialIcons name="bug-report" size={size} color={color} />;
}

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

  const handleAdminPress = () => {
    rootNavigation.navigate('Admin');
  };

  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: '#F15B2A',
        tabBarInactiveTintColor: '#757575',
        tabBarLabelStyle: {
          fontSize: 16,
          fontWeight: '600',
        },
        tabBarStyle: {
          backgroundColor: '#FFFFFF',
          borderTopColor: '#EEE',
        },
      }}
    >
      <Tab.Screen
        name="Home"
        options={{
          tabBarLabel: 'Home',
          tabBarIcon: HomeTabIcon,
        }}
      >
        {() => <HomeScreen onProfilePress={handleProfilePress} />}
      </Tab.Screen>
      <Tab.Screen
        name="About"
        options={{
          tabBarLabel: 'About',
          tabBarIcon: AboutTabIcon,
        }}
      >
        {() => (
          <AboutScreen
            onProfilePress={handleProfilePress}
            onAdminPress={handleAdminPress}
          />
        )}
      </Tab.Screen>
      <Tab.Screen
        name="Debug"
        options={{
          tabBarLabel: 'Debug',
          tabBarIcon: DebugTabIcon,
        }}
      >
        {() => (
          <DebugScreen
            onNavigateToConfig={() => rootNavigation.navigate('DebugConfig')}
          />
        )}
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

function AdminScreenWrapper() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const handleBack = () => {
    if (navigation.canGoBack()) {
      navigation.goBack();
    } else {
      navigation.navigate('Main');
    }
  };
  return (
    <AdminScreen
      onBack={handleBack}
    />
  );
}

function DebugConfigScreenWrapper() {
  const navigation = useNavigation<NativeStackNavigationProp<RootStackParamList>>();
  const handleBack = () => {
    if (navigation.canGoBack()) {
      navigation.goBack();
    } else {
      navigation.navigate('Main');
    }
  };
  return <ConfigScreen onBack={handleBack} />;
}

export function AppNavigator() {
  const navigationRef = useNavigationContainerRef<RootStackParamList>();
  useO11yNavigation(navigationRef);

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
        <Stack.Screen
          name="Admin"
          component={AdminScreenWrapper}
          options={{ presentation: 'modal' }}
        />
        <Stack.Screen
          name="DebugConfig"
          component={DebugConfigScreenWrapper}
          options={{ presentation: 'modal' }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
