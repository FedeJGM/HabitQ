import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/chat_service.dart';

void main() {
  group('ChatSource.citation', () {
    test('formats authors, year, title, journal and pages', () {
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
        'Doe J, Roe R (2024). Sleep and health. Sleep Journal. Págs. 1, 3.',
      );
    });

    test('falls back to title and organization when metadata is missing', () {
      const source = ChatSource(documentId: 'd1', title: 'Healthy Sleep', organization: 'CDC');

      expect(source.citation, 'Healthy Sleep. CDC.');
    });

    test('uses the singular for a single page', () {
      const source = ChatSource(documentId: 'd1', title: 'T', pages: [4]);

      expect(source.citation, 'T. Pág. 4.');
    });

    test('does not double the period when the title already ends with one', () {
      const source = ChatSource(documentId: 'd1', title: 'A title.', year: 2020);

      expect(source.citation, '(2020). A title.');
    });

    test('does not include the link, which is shown separately', () {
      const source = ChatSource(
        documentId: 'd1',
        title: 'T',
        doi: '10.1/abc',
        sourceUrl: 'https://example.org/x',
      );

      expect(source.citation, 'T.');
    });
  });

  group('ChatSource.link', () {
    test('is the DOI link when there is a DOI', () {
      const source = ChatSource(
        documentId: 'd1',
        title: 'T',
        doi: '10.1/abc',
        sourceUrl: 'https://europepmc.org/articles/PMC1',
      );

      expect(source.link, Uri.parse('https://doi.org/10.1/abc'));
    });

    test('falls back to the source URL when there is no DOI', () {
      const source = ChatSource(
        documentId: 'd1',
        title: 'T',
        sourceUrl: 'https://example.org/sleep',
      );

      expect(source.link, Uri.parse('https://example.org/sleep'));
    });

    test('is null when there is neither DOI nor URL', () {
      const source = ChatSource(documentId: 'd1', title: 'T');

      expect(source.link, isNull);
    });

    test('ignores URLs that are not http or https', () {
      for (final url in ['javascript:alert(1)', 'file:///etc/passwd', 'not a url', 'https://']) {
        final source = ChatSource(documentId: 'd1', title: 'T', sourceUrl: url);

        expect(source.link, isNull, reason: url);
      }
    });

    test('percent-encodes odd characters in a DOI instead of throwing', () {
      const source = ChatSource(documentId: 'd1', title: 'T', doi: '10.1002/(SICI) x<y>');

      final link = source.link;

      expect(link, isNotNull);
      expect(link!.scheme, 'https');
      expect(link.host, 'doi.org');
      expect(link.toString(), isNot(contains(' ')));
    });
  });
}
