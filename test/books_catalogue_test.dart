import 'package:flutter_test/flutter_test.dart';
import 'package:skillsikka/features/books/data/book_api.dart';
import 'package:skillsikka/features/books/data/catalogue_book.dart';

void main() {
  test('a catalogue row fills the existing book card', () {
    final book = CatalogueBook.fromJson({
      'id': 12,
      'title': 'Geometry',
      'author': 'Sample Writer',
      'description': 'An introduction to geometry',
      'cover_url': 'https://cdn.example.com/cover.png',
      'category': 'Math',
      'subject_name': 'Mathematics',
      'difficulty': 'beginner',
      'highlights': ['Worked examples'],
      'price': '0.00',
      'currency': 'NPR',
      'average_rating': 4.5,
      'is_saved': true,
      'has_reading_access': false,
      'available_action': 'get_free',
    });

    expect(book.categoryLabel, 'Math');
    expect(book.tags, ['Beginner', 'Worked examples']);
    expect(book.ratingLabel, '4.5');
    expect(book.priceLabel, 'Free');
    expect(book.action, 'get_free');
  });

  test('a shelf keeps the place screen fields', () {
    final book = CatalogueBook.fromJson({
      'id': 12,
      'title': 'Geometry',
      'author': 'Sample Writer',
      'cover_url': '',
      'price': '100.00',
      'currency': 'NPR',
    });
    final owned = ownedFromShelf(
      book,
      BookShelfPayload.fromParts(
        contents: {
          'reader_mode': 'chapters',
          'chapters': [
            {
              'id': 31,
              'chapter_number': 1,
              'title': 'Angles',
              'estimated_reading_minutes': 2,
              'pdf_page_start': null,
              'pdf_page_end': null,
              'is_completed': true,
            },
            {
              'id': 32,
              'chapter_number': 2,
              'title': 'Triangles',
              'estimated_reading_minutes': 4,
              'is_completed': false,
            },
          ],
          'progress': {
            'last_chapter_id': 32,
            'completed_chapter_ids': [31],
            'overall_percentage': 50,
          },
        },
        bookmarks: [
          {
            'id': 7,
            'chapter_id': 32,
            'position': {'paragraph': 0},
          },
        ],
      ),
    );

    expect(owned.currentChapter, 1);
    expect(owned.chapters[1].title, 'Triangles');
    expect(owned.chapters[1].subtitle, '4 min');
    expect(owned.percent, 50);
    expect(owned.completed, {0});
    expect(owned.bookmarks, {1});
    expect(owned.bookmarkIds[1], 7);
    expect(owned.overallPage, 2);
    expect(owned.totalPages, 2);
    expect(book.priceLabel, 'NPR 100');
  });
}
