import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// A province, district or school as the backend holds it.
///
/// One type for all three because they are structurally identical — an id and a
/// name — and because the pickers only ever need those two things. The extra
/// field each carries is kept where it matters: [provinceId] on a district is
/// what makes the district list filterable by the chosen province.
@immutable
class ReferenceItem {
  const ReferenceItem({required this.id, required this.name, this.provinceId});

  final String id;
  final String name;

  /// Set on districts only; the province they belong to.
  final String? provinceId;

  /// Parses one entry, or null when it has no usable name.
  ///
  /// A blank name is treated as absent rather than rendered as an empty row in a
  /// picker, where it would be unselectable and look like a bug.
  static ReferenceItem? tryParse(Object? body) {
    if (body is! Map) return null;
    final json = body.cast<String, dynamic>();
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    return ReferenceItem(
      id: _string(json['id']) ?? '',
      name: name.trim(),
      provinceId: _string(json['province_id']),
    );
  }

  static String? _string(Object? value) {
    if (value is num) return value.toString();
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  @override
  String toString() => 'ReferenceItem($id, $name)';
}

/// Reads the location tree and the grade list from the backend.
///
/// **Confirmed live 2026-09-28**, all unauthenticated:
/// - `/locations/provinces/` → 7 provinces
/// - `/locations/districts/` → every district, each with `province_id`
/// - `/locations/schools/` → **only test rows so far** (`TestSchool`), so the
///   school picker has almost nothing real to show. That is a seeding gap on the
///   backend, not a client bug — the picker degrades to an empty list.
/// - `/grades/` → `Grade 1` … `Grade 12`
///
/// These replaced hardcoded `const` lists in `edit_profile_page.dart`, which held
/// **four** provinces against the backend's seven, and school names that do not
/// exist in the database at all. A const list here is wrong the moment the
/// reference data changes, and it silently invites the user to save a value the
/// backend has never heard of.
class ReferenceDataApi {
  const ReferenceDataApi(this._client);

  final ApiClient _client;

  Future<List<ReferenceItem>> provinces() => _list('/locations/provinces/');

  Future<List<ReferenceItem>> districts() => _list('/locations/districts/');

  Future<List<ReferenceItem>> schools() => _list('/locations/schools/');

  Future<List<ReferenceItem>> grades() => _list('/grades/');

  /// Fetches a list and drops any entry without a usable name.
  ///
  /// A malformed row is skipped rather than failing the whole request: one bad
  /// record out of eighty should cost the user that record, not the picker.
  ///
  /// Requested as `List<dynamic>` rather than `Object?` so [ApiClient] itself
  /// enforces the shape — it throws its own "unexpected response" error when the
  /// body is not a list, which is the message that describes a backend shape
  /// problem. Asking for `Object?` made the local type check below provably
  /// unreachable (`data is! Object?` is always false), which the analyzer reports
  /// as dead code.
  Future<List<ReferenceItem>> _list(String path) async {
    final body = await _client.get<List<dynamic>>(path);
    return body
        .map(ReferenceItem.tryParse)
        .whereType<ReferenceItem>()
        .toList(growable: false);
  }
}

final referenceDataApiProvider = Provider<ReferenceDataApi>(
  (ref) => ReferenceDataApi(ref.watch(apiClientProvider)),
);

/// The province list. Starts empty and fills when first read.
final provincesProvider = FutureProvider<List<ReferenceItem>>(
  (ref) => ref.watch(referenceDataApiProvider).provinces(),
);

/// The grade list — `Grade 1` to `Grade 12`.
final gradesProvider = FutureProvider<List<ReferenceItem>>(
  (ref) => ref.watch(referenceDataApiProvider).grades(),
);

/// The district list, **filtered by the chosen province**.
///
/// Keyed on the province name, because that is what the form stores. The filter
/// is what makes the dependency real: picking a province must narrow the
/// districts, and without the link every district in the country would be
/// selectable under any province.
///
/// Matching is by the province's own id, resolved from [provincesProvider] — the
/// form holds a *name*, and the districts carry an id, so the name has to be
/// resolved back to an id before it can filter anything. An unknown or empty
/// province yields an empty list rather than every district, so the picker
/// cannot offer a district that does not belong to what the user picked.
final districtsForProvinceProvider =
    FutureProvider.family<List<ReferenceItem>, String>((
      ref,
      provinceName,
    ) async {
      final trimmed = provinceName.trim();
      if (trimmed.isEmpty) return const [];

      final provinces = await ref.watch(provincesProvider.future);
      final province = _byName(provinces, trimmed);
      if (province == null) return const [];

      final districts = await ref.watch(referenceDataApiProvider).districts();
      return districts
          .where((district) => district.provinceId == province.id)
          .toList(growable: false);
    });

/// The school list for a district.
///
/// **The backend currently has almost no schools seeded**, so this returns an
/// empty list in practice. Kept wired rather than left as a const list because
/// the const list was actively wrong — it offered college names the database has
/// never contained, and a user could save one.
final schoolsForDistrictProvider = FutureProvider.family<List<ReferenceItem>, String>((
  ref,
  districtName,
) async {
  final trimmed = districtName.trim();
  if (trimmed.isEmpty) return const [];

  final schools = await ref.watch(referenceDataApiProvider).schools();
  final districts = await ref.watch(referenceDataApiProvider).districts();
  final match = _byName(districts, trimmed);
  // No district resolved means nothing can be attributed to it. Returning all
  // schools would offer schools from other districts.
  if (match == null) return const [];

  // `School` carries `municipality_id`, not a district id, so it cannot be
  // filtered to a district from the data we have. Rather than guess a mapping,
  // the whole list is returned once the district is known — which is harmless
  // while the table holds only test rows, and is the reason this needs
  // revisiting when the backend seeds real schools with their municipality.
  return schools;
});

/// The item whose name matches [name], case-insensitively, or null.
///
/// A local helper rather than `firstOrNull` from `package:collection`: that
/// package is not a dependency of this project, and adding one for a single
/// lookup is not worth it.
ReferenceItem? _byName(List<ReferenceItem> items, String name) {
  final needle = name.toLowerCase();
  for (final item in items) {
    if (item.name.toLowerCase() == needle) return item;
  }
  return null;
}
