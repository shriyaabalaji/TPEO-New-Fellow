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

MockProvider? mockProviderById(String id) {
  try {
    return mockProviders.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
}

const mockServicesByProvider = <String, List<MockService>>{
  '1': [MockService('Vintage styling', r'$30', '1 hr'), MockService('Consultation', r'$15', '30 min')],
  '2': [MockService('Accessories fitting', r'$20', '45 min')],
  '3': [MockService('Haircut', r'$25', '45 min'), MockService('Beard trim', r'$10', '15 min')],
  '4': [MockService('Full set', r'$45', '1 hr'), MockService('Fill', r'$25', '45 min')],
  '5': [MockService('Portrait session', r'$75', '1 hr')],
  '6': [MockService('Tutoring session', r'$30', '1 hr')],
};

class MockService {
  const MockService(this.name, this.price, this.duration);
  final String name;
  final String price;
  final String duration;
}
