import 'package:dio/dio.dart';
import 'package:skillsikka/core/network/api_client.dart';
import 'package:skillsikka/features/profile/data/reference_data.dart';

/// A stand-in for the reference-data endpoints, for tests that need a save to
/// resolve geographic names into ids (or a login to resolve ids back into names).
///
/// **Live values, copied from the location tree on 2026-10-02.** Real ids, not
/// invented ones: the whole point of these tests is that a name joins to the id
/// the backend actually holds, and a made-up id would pass while the real save
/// failed.
///
/// Counts calls, because the geographic resolution on the login path has a
/// contract of its own — it must make **none** until the server sends an id.
/// [calls] is how a test asserts that.
class FakeReferenceData extends ReferenceDataApi {
  FakeReferenceData() : super(ApiClient(Dio()));

  /// How many reference requests were made across all five endpoints.
  int calls = 0;

  /// Thrown from every endpoint when set. Models the location tree being
  /// unreachable, which must cost the geographic fields and nothing else.
  Object? failure;

  void _tick() {
    calls++;
    if (failure != null) throw failure!;
  }

  @override
  Future<List<ReferenceItem>> grades() async {
    _tick();
    return _grades;
  }

  @override
  Future<List<ReferenceItem>> provinces() async {
    _tick();
    return _provinces;
  }

  @override
  Future<List<ReferenceItem>> districts() async {
    _tick();
    return _districts;
  }

  @override
  Future<List<ReferenceItem>> municipalities() async {
    _tick();
    return _municipalities;
  }

  @override
  Future<List<ReferenceItem>> schools() async {
    _tick();
    return _schools;
  }
}

const _provinces = [ReferenceItem(id: '3', name: 'Bagmati')];
const _districts = [
  ReferenceItem(id: '27', name: 'Kathmandu', provinceId: '3'),
];
const _municipalities = [
  ReferenceItem(
    id: '316',
    name: 'Kathmandu Metropolitan City',
    districtId: '27',
  ),
  // Two municipalities genuinely share this name — the duplicate-name case an
  // id lookup has to survive and a name lookup cannot.
  ReferenceItem(id: '318', name: 'Aaurahi', districtId: '27'),
  ReferenceItem(id: '319', name: 'Aaurahi', districtId: '27'),
];
const _grades = [ReferenceItem(id: '11', name: 'Grade 11')];
const _schools = [
  ReferenceItem(id: '2', name: 'TestSchooll', municipalityId: '316'),
];
