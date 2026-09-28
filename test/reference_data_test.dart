import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/core/config/app_config_provider.dart';
import 'package:skillsikka/core/config/app_environment.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/features/profile/data/reference_data.dart';

/// A stand-in for the real transport, as in `api_client_test.dart`.
///
/// Duplicated rather than shared: the project has no mocking package, the class
/// is twenty lines, and a shared helper would tie three unrelated suites
/// together.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Answers every path from [byPath], or 404 for anything unlisted.
_FakeAdapter _serving(Map<String, Object?> byPath) {
  return _FakeAdapter((options) {
    final body = byPath[options.path];
    if (body == null) return _json({'detail': 'not found'}, status: 404);
    return _json(body);
  });
}

ProviderContainer _scopeFor(HttpClientAdapter adapter) {
  final scope = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: AppEnvironment.production,
          apiBaseUrl: 'https://api.example.test',
        ),
      ),
    ],
  );
  scope.read(dioProvider).httpClientAdapter = adapter;
  return scope;
}

/// The live `/locations/provinces/` shape, abbreviated to three.
const _provincesBody = [
  {'id': 1, 'name': 'Bagmati'},
  {'id': 2, 'name': 'Gandaki'},
  {'id': 3, 'name': 'Koshi'},
];

/// Districts carry `province_id` — that is the field the filter needs.
const _districtsBody = [
  {'id': 10, 'name': 'Kathmandu', 'province_id': 1},
  {'id': 11, 'name': 'Lalitpur', 'province_id': 1},
  {'id': 12, 'name': 'Kaski', 'province_id': 2},
];

void main() {
  group('ReferenceItem.tryParse', () {
    test('reads the live row shape, stringifying a numeric id', () {
      final item = ReferenceItem.tryParse({
        'id': 1,
        'name': 'Bagmati',
        'province_id': 3,
      });

      expect(item, isNotNull);
      expect(item!.id, '1', reason: 'a Django AutoField arrives as a number');
      expect(item.name, 'Bagmati');
      expect(item.provinceId, '3');
    });

    test('trims the name rather than rendering it padded', () {
      final item = ReferenceItem.tryParse({'id': 1, 'name': '  Koshi  '});
      expect(item!.name, 'Koshi');
    });

    test('rejects a row with no usable name', () {
      // A blank name would render an unselectable row that looks like a bug.
      expect(ReferenceItem.tryParse({'id': 1, 'name': '   '}), isNull);
      expect(ReferenceItem.tryParse({'id': 1}), isNull);
      expect(ReferenceItem.tryParse({'id': 1, 'name': 42}), isNull);
      expect(ReferenceItem.tryParse('not a map'), isNull);
      expect(ReferenceItem.tryParse(null), isNull);
    });

    test('leaves provinceId null when absent, rather than inventing one', () {
      final item = ReferenceItem.tryParse({'id': 1, 'name': 'Bagmati'});
      expect(item!.provinceId, isNull);
    });
  });

  group('ReferenceDataApi over HTTP', () {
    test('parses the province list and keeps the trailing slash', () async {
      final adapter = _serving({'/locations/provinces/': _provincesBody});
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);

      final provinces = await scope.read(referenceDataApiProvider).provinces();

      expect(provinces.map((p) => p.name), ['Bagmati', 'Gandaki', 'Koshi']);
      // Without the slash Django answers 301, which dio does not follow.
      expect(adapter.requests.single.path, endsWith('/locations/provinces/'));
    });

    test('drops a malformed row instead of failing the whole list', () async {
      // One bad record out of many should cost the user that record, not the
      // picker.
      final adapter = _serving({
        '/locations/provinces/': [
          {'id': 1, 'name': 'Bagmati'},
          {'id': 2}, // no name
          {'id': 3, 'name': 'Koshi'},
        ],
      });
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);

      final provinces = await scope.read(referenceDataApiProvider).provinces();

      expect(provinces.map((p) => p.name), ['Bagmati', 'Koshi']);
    });
  });

  group('districtsForProvinceProvider', () {
    test('filters to the chosen province by resolving name to id', () async {
      // The form holds a province *name*, the districts carry an *id*, so the
      // name has to be resolved before it can filter anything. This is the
      // logic the gate test's override bypasses, which is why it is tested
      // here.
      final adapter = _serving({
        '/locations/provinces/': _provincesBody,
        '/locations/districts/': _districtsBody,
      });
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);

      final districts = await scope.read(
        districtsForProvinceProvider('Bagmati').future,
      );

      expect(districts.map((d) => d.name), [
        'Kathmandu',
        'Lalitpur',
      ], reason: 'Kaski belongs to Gandaki and must not appear');
    });

    test('returns nothing for a province the backend does not have', () async {
      final adapter = _serving({
        '/locations/provinces/': _provincesBody,
        '/locations/districts/': _districtsBody,
      });
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);

      final districts = await scope.read(
        districtsForProvinceProvider('Atlantis').future,
      );

      // Empty, not "every district": offering a district that does not belong
      // to the picked province would let the user save an impossible pair.
      expect(districts, isEmpty);
    });

    test('returns nothing before a province is picked', () async {
      final adapter = _serving({
        '/locations/provinces/': _provincesBody,
        '/locations/districts/': _districtsBody,
      });
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);

      final districts = await scope.read(
        districtsForProvinceProvider('   ').future,
      );

      expect(districts, isEmpty);
      expect(
        adapter.requests,
        isEmpty,
        reason: 'a blank province must not cost a request',
      );
    });
  });

  group('gradesProvider', () {
    test('reads the backend range, not the old Class 8-12 list', () async {
      final adapter = _serving({
        '/grades/': [
          for (var i = 1; i <= 12; i++) {'id': i, 'name': 'Grade $i'},
        ],
      });
      final scope = _scopeFor(adapter);
      addTearDown(scope.dispose);

      final grades = await scope.read(gradesProvider.future);

      expect(grades.length, 12);
      expect(grades.first.name, 'Grade 1');
      expect(grades.last.name, 'Grade 12');
    });
  });
}
