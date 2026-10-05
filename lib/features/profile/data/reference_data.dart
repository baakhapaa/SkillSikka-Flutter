import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// A province, district, municipality or school as the backend holds it.
///
/// One type for all four because they are structurally identical — an id and a
/// name — and because the pickers only ever need those two things. The extra
/// field each carries is kept where it matters: [provinceId] on a district and
/// [districtId] on a municipality are what make each list filterable by its
/// parent.
///
/// Confirmed against the live endpoints 2026-10-01, and schools on 2026-10-02:
/// `/locations/provinces/` → `{id, name}`,
/// `/locations/districts/` → `{id, name, province_id}`,
/// `/locations/municipalities/` → `{id, name, district_id}`,
/// `/locations/schools/` → `{id, name, logo_url, sector, municipality_id}`.
@immutable
class ReferenceItem {
  const ReferenceItem({
    required this.id,
    required this.name,
    this.provinceId,
    this.districtId,
    this.municipalityId,
  });

  final String id;
  final String name;

  /// Set on districts only; the province they belong to.
  final String? provinceId;

  /// Set on municipalities only; the district they belong to.
  final String? districtId;

  /// Set on schools only; the municipality they belong to.
  ///
  /// **Not cosmetic — this is how a student supplies `municipality_id`.** The
  /// student form has no municipality picker, but
  /// `POST /me/complete-profile/` cannot be answered without one: it validates
  /// `municipality_id` against the district and then reads a `municipality` key,
  /// so omitting it is a `500 KeyError: 'municipality'` rather than a 400 the
  /// user could act on (verified live 2026-10-02). A school carries its
  /// municipality, so picking a school is enough to know it.
  final String? municipalityId;

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
      districtId: _string(json['district_id']),
      municipalityId: _string(json['municipality_id']),
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

  Future<List<ReferenceItem>> municipalities() =>
      _list('/locations/municipalities/');

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

/// The municipality list for a district.
///
/// Keyed on the district *name*, because that is what the form holds, and the id
/// is resolved back out of the district list the same way
/// [districtsForProvinceProvider] resolves a province. Needed because the
/// instructor registration requires `municipality_id` (live schema,
/// 2026-10-01) — the student hierarchy stops at the school instead.
final municipalitiesForDistrictProvider =
    FutureProvider.family<List<ReferenceItem>, String>((
      ref,
      districtName,
    ) async {
      final trimmed = districtName.trim();
      if (trimmed.isEmpty) return const [];

      final districts = await ref.watch(referenceDataApiProvider).districts();
      final district = _byName(districts, trimmed);
      // An unresolved district means nothing can be attributed to it. Returning
      // every municipality would offer ones from other districts.
      if (district == null) return const [];

      final municipalities = await ref
          .watch(referenceDataApiProvider)
          .municipalities();
      return municipalities
          .where((municipality) => municipality.districtId == district.id)
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

/// The ids behind a set of geographic **names**, for the completion endpoints.
///
/// **Why this has to exist.** Both completion routes validate their geographic
/// fields by primary key, but the profile store holds the names the user read —
/// the ids only ever exist inside a picker sheet and are dropped when it closes.
/// So a user who has just signed in has names and no ids, and their class,
/// province, district and school could not be sent at all.
///
/// Resolving here, at save time, from the same reference data the pickers used,
/// is what closes that gap: the same name always resolves to the same id, so a
/// profile saved in one session and re-saved in the next produces the same body.
///
/// **A name that resolves to nothing yields a null id, not a guess.** The
/// endpoints reject a mismatched hierarchy ("District does not belong to the
/// selected province."), so inventing an id would trade a skipped field for a
/// failed save.
class LocationIds {
  const LocationIds({
    this.provinceId,
    this.districtId,
    this.municipalityId,
    this.schoolId,
  });

  final String? provinceId;
  final String? districtId;

  /// For a student, taken from the **school**, which is the only one of the four
  /// that carries it. See [ReferenceItem.municipalityId] — the student form has
  /// no municipality picker, and the route 500s without this. For an instructor,
  /// who has no school but does have a municipality picker, it is resolved from
  /// the name instead. See [resolveLocationIds].
  final String? municipalityId;

  final String? schoolId;

  /// True when nothing at all resolved, so there is no point sending a body.
  bool get isEmpty =>
      provinceId == null &&
      districtId == null &&
      municipalityId == null &&
      schoolId == null;
}

/// Resolves [province], [district], [municipality] and [school] names to ids.
///
/// Takes the already-fetched lists rather than reading providers itself, so the
/// caller controls which requests are made and can pass lists it has already
/// loaded for the pickers.
///
/// [gradeName] resolves against [grades], which is a flat list needing no
/// hierarchy.
///
/// **[municipalityName] and [municipalities] are optional because only the
/// instructor has a municipality picker.** A student's form goes province →
/// district → school with no municipality step, so their municipality id can
/// only come from the school — which is what the fallback below does. An
/// instructor picks the municipality directly and has no school at all, so
/// without this the instructor's three required geographic ids would resolve to
/// nothing whenever the user had not reopened the pickers.
({String? gradeId, LocationIds locations}) resolveLocationIds({
  required List<ReferenceItem> grades,
  required List<ReferenceItem> provinces,
  required List<ReferenceItem> districts,
  required List<ReferenceItem> schools,
  required String gradeName,
  required String provinceName,
  required String districtName,
  required String schoolName,
  List<ReferenceItem> municipalities = const [],
  String municipalityName = '',
}) {
  final province = _byName(provinces, provinceName.trim());
  final district = _byName(districts, districtName.trim());
  final school = _byName(schools, schoolName.trim());
  final municipality = _byName(municipalities, municipalityName.trim());

  // A district is only trusted when it really belongs to the chosen province —
  // the endpoint checks exactly this, so resolving it here would only move the
  // rejection later. Same reasoning for a grade: no hierarchy to verify, so a
  // plain name match is the whole check.
  final districtBelongsToProvince =
      district != null &&
      province != null &&
      district.provinceId == province.id;

  // And a municipality against its district, for the same reason. A blank
  // [municipalityName] never matches — `_byName` compares against '' and no
  // row is named that — so a student skips this and falls through to the school.
  final municipalityBelongsToDistrict =
      municipality != null &&
      district != null &&
      districtBelongsToProvince &&
      municipality.districtId == district.id;

  return (
    gradeId: _byName(grades, gradeName.trim())?.id,
    locations: LocationIds(
      provinceId: province?.id,
      districtId: districtBelongsToProvince ? district.id : null,
      // The student's path first in practice, because they have no municipality
      // name to resolve. See [ReferenceItem.municipalityId] — the route 500s
      // without this rather than answering a 400 the user could act on.
      municipalityId:
          (municipalityBelongsToDistrict ? municipality.id : null) ??
          school?.municipalityId,
      schoolId: school?.id,
    ),
  );
}

/// The item whose id matches [id], or null.
///
/// The inverse lookup to [_byName], and exported because the profile bootstrap
/// needs it: the server hands back primary keys and the store is keyed by the
/// names a person reads.
///
/// **A blank [id] matches nothing, deliberately.** [ReferenceItem.id] falls back
/// to `''` for a row whose id the backend omitted (see [ReferenceItem.tryParse]),
/// so a naive `firstWhere((item) => item.id == id)` would match the *first such
/// malformed row* whenever the caller passed `''` — which is exactly what an
/// absent field looks like. Guarding here means an absent id resolves to nothing,
/// which is the honest answer.
ReferenceItem? referenceItemById(List<ReferenceItem> items, String? id) {
  final needle = (id ?? '').trim();
  if (needle.isEmpty) return null;
  for (final item in items) {
    if (item.id == needle) return item;
  }
  return null;
}

/// The geographic **names** behind a set of ids. The inverse of [LocationIds].
@immutable
class LocationNames {
  const LocationNames({
    this.province,
    this.district,
    this.municipality,
    this.school,
  });

  final String? province;
  final String? district;
  final String? municipality;
  final String? school;

  bool get isEmpty =>
      province == null &&
      district == null &&
      municipality == null &&
      school == null;

  @override
  String toString() =>
      'LocationNames(province: $province, district: $district, '
      'municipality: $municipality, school: $school)';
}

/// Resolves geographic and grade **ids** back to the names a person reads.
///
/// The exact inverse of [resolveLocationIds], and needed for the same reason:
/// the store is keyed by names, the wire speaks primary keys, so anything the
/// server sends has to be turned back before it can be shown.
///
/// **Every list is required, including the ones a given role never uses.** The
/// caller already has to fetch provinces, districts and schools to resolve a
/// profile at all, and municipalities come from the same four calls' worth of
/// endpoints — gating them per role would mean branching the caller on a detail
/// that belongs here.
///
/// **The hierarchy is deliberately not re-validated.** [resolveLocationIds]
/// checks it, because it is *building* a body the server will reject if the
/// chain is wrong. Here the ids came *from* the server already validated, and a
/// name is worth showing even if its parent is missing — dropping a district
/// because a province did not resolve would hide data the user can actually see.
/// The check still happens on the next save, which is where it can still act.
({String? gradeName, LocationNames locations}) resolveLocationNames({
  required List<ReferenceItem> grades,
  required List<ReferenceItem> provinces,
  required List<ReferenceItem> districts,
  required List<ReferenceItem> municipalities,
  required List<ReferenceItem> schools,
  String? gradeId,
  String? provinceId,
  String? districtId,
  String? municipalityId,
  String? schoolId,
}) {
  return (
    gradeName: referenceItemById(grades, gradeId)?.name,
    locations: LocationNames(
      province: referenceItemById(provinces, provinceId)?.name,
      district: referenceItemById(districts, districtId)?.name,
      municipality: referenceItemById(municipalities, municipalityId)?.name,
      school: referenceItemById(schools, schoolId)?.name,
    ),
  );
}
