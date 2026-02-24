class MockProvider {
  const MockProvider({
    required this.id,
    required this.businessName,
    required this.tags,
    this.rating = 5.0,
    this.reviewCount = 37,
    this.priceFrom = r'$20',
  });

  final String id;
  final String businessName;
  final List<String> tags;
  final double rating;
  final int reviewCount;
  final String priceFrom;
}

const mockProviders = [
  MockProvider(id: '1', businessName: 'Mint Vintage', tags: ['Vintage', 'Clothing'], reviewCount: 170),
  MockProvider(id: '2', businessName: 'Dark Paradise', tags: ['Vintage', 'Accessories'], reviewCount: 44),
  MockProvider(id: '3', businessName: 'Campus Cuts', tags: ['Hair', 'Beauty']),
  MockProvider(id: '4', businessName: 'Longhorn Nails', tags: ['Nails', 'Beauty'], reviewCount: 89),
  MockProvider(id: '5', businessName: 'UT Photography', tags: ['Photography']),
  MockProvider(id: '6', businessName: 'Study Buddy Tutoring', tags: ['Tutoring', 'Academic']),
];

const mockCategories = [
  'Nails', 'Hair', 'Photography', 'Tutoring', 'Vintage', 'Other',
];
