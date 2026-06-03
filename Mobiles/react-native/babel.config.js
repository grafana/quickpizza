module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: [
    [
      'babel-plugin-transform-inline-environment-variables',
      {
        include: ['ENABLE_FARO_PAYLOAD_DIAGNOSTICS'],
      },
    ],
  ],
};
