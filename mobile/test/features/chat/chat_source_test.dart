import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/chat_service.dart';

void main() {
  group('ChatSource.citation', () {
    test('formats a complete reference with DOI link and pages', () {
      const source = ChatSource(
        documentId: 'd1',
        title: 'Sleep and health',
        organization: 'Sleep Journal',
        sourceUrl: 'https://europepmc.org/articles/PMC1',
        authors: 'Doe J, Roe R.',
        year: 2024,
        doi: '10.1/abc',
        pages: [1, 3],
      );

      expect(
        source.citation,
        'Doe J, Roe R (2024). Sleep and health. Sleep Journal. '
        'https://doi.org/10.1/abc · págs. 1, 3',
      );
    });

    test('falls back to title and organization when metadata is missing', () {
      const source = ChatSource(documentId: 'd1', title: 'Healthy Sleep', organization: 'CDC');

      expect(source.citation, 'Healthy Sleep. CDC.');
    });

    test('uses the source URL when there is no DOI', () {
      const source = ChatSource(
        documentId: 'd1',
        title: 'Healthy Sleep',
        sourceUrl: 'https://example.org/sleep',
      );

      expect(source.citation, 'Healthy Sleep. https://example.org/sleep');
    });

    test('uses the singular for a single page', () {
      const source = ChatSource(documentId: 'd1', title: 'T', pages: [4]);

      expect(source.citation, 'T. pág. 4');
    });

    test('does not double the period when the title already ends with one', () {
      const source = ChatSource(documentId: 'd1', title: 'A title.', year: 2020);

      expect(source.citation, '(2020). A title.');
    });
  });
}
