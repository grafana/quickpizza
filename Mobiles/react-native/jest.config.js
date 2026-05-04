module.exports = {
  preset: 'react-native',
  setupFiles: ['./jest.setup.js'],
  moduleNameMapper: {
    '\\.(png|jpg|jpeg|gif|webp|ttf)$': '<rootDir>/__mocks__/fileMock.js',
  },
};
