// Automated tests for AgriSphere's shared logic and widgets.
// Run with:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agrisphere/core/services/weather.dart';
import 'package:agrisphere/core/widgets/app_extras.dart';
import 'package:agrisphere/core/widgets/app_ui.dart';
import 'package:agrisphere/core/widgets/location.dart';
import 'package:agrisphere/core/widgets/ux.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Weather w({double temp = 25, int hum = 50, double wind = 10, List<int> rain = const [0, 0, 0]}) => Weather(
      temp: temp,
      humidity: hum,
      wind: wind,
      code: 0,
      days: [for (final r in rain) DayForecast(date: DateTime(2026), code: 0, max: 30, min: 20, rainChance: r)],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('money format rs()', () {
    test('adds thousands separators', () {
      expect(rs(0), 'Rs 0');
      expect(rs(999), 'Rs 999');
      expect(rs(1500), 'Rs 1,500');
      expect(rs(1234567), 'Rs 1,234,567');
    });
    test('rounds and handles negatives', () {
      expect(rs(99.6), 'Rs 100');
      expect(rs(-1500), 'Rs -1,500');
      expect(rs(double.nan), 'Rs 0');
    });
  });

  group('distance label', () {
    test('metres under 1 km, one decimal under 10 km', () {
      expect(kmLabel(0.35), '350 m');
      expect(kmLabel(3.24), '3.2 km');
      expect(kmLabel(42.7), '43 km');
      expect(kmLabel(null), '');
    });
  });

  group('form checks (V)', () {
    test('Pakistani mobile numbers', () {
      final c = V.phone();
      expect(c('03001234567'), isNull);
      expect(c('+923001234567'), isNull);
      expect(c('0300-1234567'), isNull);
      expect(c('12345'), isNotNull);
      expect(c(''), isNotNull);
      expect(c('04001234567'), isNotNull); // landline-like prefix
    });
    test('numbers with limits', () {
      final c = V.number('Price', min: 1, max: 1000);
      expect(c('120'), isNull);
      expect(c(''), contains('Enter'));
      expect(c('abc'), contains('must be a number'));
      expect(c('0'), isNotNull);
      expect(c('5000'), contains('at most'));
    });
    test('min length and optional numbers', () {
      expect(V.minLen(3, 'Name')('Al'), isNotNull);
      expect(V.minLen(3, 'Name')('Ali'), isNull);
      expect(V.optionalNumber('Year')(''), isNull);
      expect(V.optionalNumber('Year')('20x1'), isNotNull);
    });
  });

  group('weather farming tips', () {
    test('rain today means skip irrigation', () {
      expect(w(rain: [80, 0, 0]).tip, contains('skip irrigation'));
    });
    test('rain tomorrow means harvest today', () {
      expect(w(rain: [10, 70, 0]).tip, contains('tomorrow'));
    });
    test('strong wind means no spraying', () {
      expect(w(wind: 30).tip, contains('avoid spraying'));
    });
    test('heat and frost warnings', () {
      expect(w(temp: 41).tip, contains('Very hot'));
      expect(w(temp: 2).tip, contains('Frost'));
    });
    test('normal day', () {
      expect(w().tip, contains('Good conditions'));
    });
    test('weather codes have readable labels', () {
      expect(weatherLabel(0), 'Clear sky');
      expect(weatherLabel(63), 'Rain');
      expect(weatherLabel(95), 'Thunderstorm');
    });
  });

  group('widgets', () {
    testWidgets('LiveField shows an error while typing and a tick when valid', (t) async {
      final c = TextEditingController();
      await t.pumpWidget(wrap(LiveField('Mobile number', c, check: V.phone())));
      expect(find.text('Use the format 03001234567'), findsNothing); // no error before typing

      await t.enterText(find.byType(TextField), '0300');
      await t.pump();
      expect(find.text('Use the format 03001234567'), findsOneWidget);

      await t.enterText(find.byType(TextField), '03001234567');
      await t.pump();
      expect(find.text('Use the format 03001234567'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('FormCheck.validate() shows every error at once on submit', (t) async {
      final form = FormCheck();
      await t.pumpWidget(wrap(Column(children: [
        LiveField('Name', TextEditingController(), form: form, check: V.minLen(3, 'Name')),
        LiveField('Price', TextEditingController(), form: form, check: V.number('Price')),
      ])));
      String? first;
      await t.runAsync(() async => first = form.validate());
      await t.pump();
      expect(first, 'Name must be at least 3 characters');
      expect(find.text('Name must be at least 3 characters'), findsOneWidget);
      expect(find.text('Enter Price'), findsOneWidget);
    });

    testWidgets('EmptyState shows its action button and runs it', (t) async {
      var tapped = 0;
      await t.pumpWidget(wrap(SizedBox(
        height: 400,
        child: EmptyState(icon: Icons.inbox, text: 'Nothing here', action: EmptyAction('Add item', () async => tapped++)),
      )));
      expect(find.text('Nothing here'), findsOneWidget);
      await t.tap(find.text('Add item'));
      expect(tapped, 1);
    });

    testWidgets('PrimaryButton shows a spinner while loading', (t) async {
      await t.pumpWidget(wrap(PrimaryButton(label: 'Pay', loading: true, onPressed: () {})));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('settings', () {
    test('text size is remembered', () async {
      await AppPrefs.setScale(1.3);
      AppPrefs.textScale.value = 1.0;
      await AppPrefs.load();
      expect(AppPrefs.textScale.value, 1.3);
    });
  });
}
