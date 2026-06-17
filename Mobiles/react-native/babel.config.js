module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [
    [
      'babel-plugin-transform-inline-environment-variables',
      {
        include: ['DEMO_APP_VERSION', 'ENABLE_FARO_PAYLOAD_DIAGNOSTICS'],
      },
    ],
  ],
};
