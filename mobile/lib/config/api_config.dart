class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:5000', // 10.0.2.2 maps to host machine on Android emulator
  );
}
