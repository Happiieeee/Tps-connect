class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://tps-backend-fn67.onrender.com',
  );
}
