import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/domain/entities/category.dart';
import 'package:spendly/domain/services/category_matcher.dart';

Category _cat(String id, String name, {bool isDeleted = false}) => Category(
  id: id,
  userId: 'u',
  name: name,
  iconCode: 0,
  colorValue: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  isDeleted: isDeleted,
);

final _cats = <Category>[
  _cat('c-food', 'Food'),
  _cat('c-groc', 'Groceries'),
  _cat('c-trans', 'Transport'),
  _cat('c-bills', 'Bills & Utilities'),
];

void main() {
  test('exact match', () {
    expect(matchCategoryId('Groceries', _cats), 'c-groc');
  });

  test('case-insensitive exact match', () {
    expect(matchCategoryId('groceries', _cats), 'c-groc');
    expect(matchCategoryId('  FOOD  ', _cats), 'c-food');
  });

  test('fuzzy: AI label contains a category name', () {
    // "Bills" is contained in the category "Bills & Utilities"
    expect(matchCategoryId('Bills', _cats), 'c-bills');
  });

  test('fuzzy: a category name contains the AI label', () {
    expect(matchCategoryId('Transportation', _cats), 'c-trans');
  });

  test(
    'no confident match -> null (never invents, never defaults to Other)',
    () {
      expect(matchCategoryId('Entertainment', _cats), isNull);
      expect(matchCategoryId('Petrol', _cats), isNull);
    },
  );

  test('null / empty label -> null', () {
    expect(matchCategoryId(null, _cats), isNull);
    expect(matchCategoryId('   ', _cats), isNull);
  });

  test('deleted categories are never matched', () {
    final cats = <Category>[_cat('c-old', 'Groceries', isDeleted: true)];
    expect(matchCategoryId('Groceries', cats), isNull);
  });

  test('prefers the shortest containing candidate', () {
    final cats = <Category>[
      _cat('short', 'Food'),
      _cat('long', 'Food and drinks out'),
    ];
    expect(matchCategoryId('Food', cats), 'short'); // exact wins anyway
    expect(matchCategoryId('Foodie', cats), 'short'); // contains 'Food'
  });
}
