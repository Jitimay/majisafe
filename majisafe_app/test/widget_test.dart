import 'package:flutter_test/flutter_test.dart';
import 'package:majisafe_app/config/api_config.dart';
import 'package:majisafe_app/config/theme.dart';

void main() {
  test('API prefix is /api', () {
    expect(ApiConfig.apiPrefix, '/api');
  });

  test('Brand colors are defined', () {
    expect(AppTheme.primary.toARGB32(), isNonNegative);
    expect(AppTheme.error.toARGB32(), isNonNegative);
  });
}
