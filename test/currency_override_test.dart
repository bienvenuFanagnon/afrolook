import 'package:afrotok/services/currency_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la devise suit le pays, puis le choix de la personne, puis revient en automatique', () async {
    SharedPreferences.setMockInitialValues({});
    final c = CurrencyService.instance;
    c.setCountry('TG');
    expect(c.currency, 'XOF');
    await c.setOverride('EUR');
    expect(c.currency, 'EUR');
    expect(c.override, 'EUR');
    // changer de pays ne remplace pas un choix explicite
    c.setCountry('NG');
    expect(c.currency, 'EUR');
    // 1 000 FCFA s'affichent dans la devise choisie
    expect(c.fmt(1000), contains('€'));
    await c.setOverride(null);
    expect(c.currency, 'NGN');
    expect(c.override, isNull);
  });

  test('un code inconnu est ignoré, « MANUAL » ne donne plus le dollar', () async {
    SharedPreferences.setMockInitialValues({});
    final c = CurrencyService.instance;
    await c.setOverride('ZZZ');
    expect(c.override, isNull);
    c.setCountry('MANUAL');
    expect(c.currency, c.automaticCurrency);
    expect(CurrencyService.currencyFor('MANUAL'), 'USD'); // le code « MANUAL » seul n'a pas de devise : c'est setCountry qui le traite
  });

  test('le choix gardé sur le téléphone est relu au démarrage', () async {
    SharedPreferences.setMockInitialValues({'display_currency': 'GHS'});
    final c = CurrencyService.instance;
    c.setCountry('TG');
    await c.loadOverride();
    expect(c.currency, 'GHS');
    // le choix du compte remplace celui du téléphone
    await c.loadOverride(serverValue: 'KES');
    expect(c.currency, 'KES');
    await c.setOverride(null);
  });
}
