/* eslint-env jest */

import mockAsyncStorage from '@react-native-async-storage/async-storage/jest/async-storage-mock';

jest.mock('@react-native-async-storage/async-storage', () => mockAsyncStorage);

jest.mock('react-native-keychain', () => ({
  setGenericPassword: jest.fn(() => Promise.resolve(true)),
  getGenericPassword: jest.fn(() => Promise.resolve(false)),
  resetGenericPassword: jest.fn(() => Promise.resolve(true)),
}));

jest.mock('react-native-device-info', () => ({
  getApplicationName: jest.fn(() => 'QuickPizza'),
  getBrand: jest.fn(() => 'Apple'),
  getBundleId: jest.fn(() => 'com.quickpizza'),
  getDeviceId: jest.fn(() => 'jest-device'),
  getDeviceType: jest.fn(() => 'Handset'),
  getManufacturer: jest.fn(() => Promise.resolve('Apple')),
  getModel: jest.fn(() => 'iPhone'),
  getSystemName: jest.fn(() => 'iOS'),
  getSystemVersion: jest.fn(() => '17.0'),
  getUniqueId: jest.fn(() => Promise.resolve('jest-unique-id')),
  getVersion: jest.fn(() => '1.0.0'),
  hasNotch: jest.fn(() => false),
}));

jest.mock('@grafana/faro-react-native', () => {
  const React = require('react');
  return {
    FaroErrorBoundary: ({ children }) => React.createElement(React.Fragment, null, children),
    InternalLoggerLevel: { VERBOSE: 0, ERROR: 4 },
    LogLevel: { DEBUG: 'debug', ERROR: 'error', LOG: 'log', TRACE: 'trace' },
    SamplingRate: class SamplingRate {
      constructor(rate) {
        this.rate = rate;
      }
    },
    faro: {
      api: {
        pushEvent: jest.fn(),
        pushError: jest.fn(),
        pushLog: jest.fn(),
        setUser: jest.fn(),
        startUserAction: jest.fn(),
      },
    },
    initializeFaro: jest.fn(() =>
      Promise.resolve({
        api: {
          pushEvent: jest.fn(),
        },
      }),
    ),
    useFaroNavigation: jest.fn(),
    withFaroUserAction: (Component) => Component,
  };
});
