/// A stand-in cover for a course the API has no thumbnail for.
///
/// **Every course in the dev database has `thumbnail_url: ''`.** The column is
/// a plain `URLField(blank=True)` and the backend has no upload endpoint yet, so
/// nothing fills it — which is why the catalogue grid rendered twenty grey
/// boxes while the home rail, fed by the bundled `coursePool`, showed proper
/// illustrations. This closes that gap without inventing data: it picks one of
/// the **art already shipped in the app** for the subject the course is about.
///
/// It is a fallback, never a preference. [courseCoverAsset] is only consulted
/// when `thumbnail_url` is empty, so the moment the backend starts returning a
/// real cover, that cover wins and this file stops mattering.
///
/// **The three illustrations are shared, not per-course.** The app ships four
/// catalogue illustrations in total (`course-thumbnail*.png`) and reuses them
/// across all 34 bundled entries, so three Mathematics courses legitimately
/// land on the same compass. That is the existing house style, not a bug.
///
/// Keywords are matched against **subject + category + title**, because the
/// subject is coarse (`Science` covers chemistry, biology and physics) and the
/// title is where the actual topic is (`Grade 9: Matter and Chemical
/// Reactions`).
library;

/// The bundled catalogue art, by subject family.
const _geometryArt = 'assets/figma/homescreen/course-thumbnail3.png';
const _chemistryArt = 'assets/figma/homescreen/course-thumbnail.png';
const _biologyArt = 'assets/figma/homescreen/course-thumbnail4.png';
const _codingArt = 'assets/figma/courses/python.png';
const _artArt = 'assets/figma/premiumcourse/premcourse3.png';

/// Matched in order: the first family whose keyword appears wins.
///
/// Order is load-bearing where keys overlap — `Science` is the subject of the
/// chemistry, biology and physics courses alike, so the *specific* title words
/// have to be tested before any generic one. Nothing generic is tested at all
/// here; a course whose words match nothing gets `''` and the caller draws its
/// own placeholder.
const _families = <({List<String> keys, String asset})>[
  (
    keys: ['biolog', 'dna', 'life science', 'living', 'brain', 'neural'],
    asset: _biologyArt,
  ),
  (
    keys: [
      'chem',
      'matter',
      'reaction',
      'lab',
      'physics',
      'force',
      'motion',
      'newton',
      'energy',
      'science',
    ],
    asset: _chemistryArt,
  ),
  (
    keys: [
      'geometry',
      'trigonometr',
      'shape',
      'angle',
      'math',
      'algebra',
      'fraction',
      'arithmetic',
      'equation',
      'decimal',
      'number',
    ],
    asset: _geometryArt,
  ),
  (
    keys: ['python', 'code', 'coding', 'program', 'web', 'software'],
    asset: _codingArt,
  ),
  (
    keys: ['draw', 'art', 'paint', 'sketch', 'illustrat', 'design'],
    asset: _artArt,
  ),
];

/// An asset path for [subject] / [category] / [title], or `''` when the app
/// ships nothing that fits.
///
/// Empty is a real answer, not a failure: the caller renders
/// `CourseThumbPlaceholder` rather than a photograph of the wrong subject. A
/// biology course illustrated with beakers is worse than an honest blank.
String courseCoverAsset({
  String subject = '',
  String category = '',
  String title = '',
}) {
  final haystack = '$subject $category $title'.toLowerCase();
  if (haystack.trim().isEmpty) return '';

  for (final family in _families) {
    for (final key in family.keys) {
      if (haystack.contains(key)) return family.asset;
    }
  }
  return '';
}
