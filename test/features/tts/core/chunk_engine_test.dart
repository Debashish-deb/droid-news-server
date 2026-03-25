import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/presentation/features/tts/core/chunk_engine.dart';

void main() {
  group('ChunkEngine Tests', () {
    test('Should handle empty text gracefully', () {
      final chunks = ChunkEngine.createChunks('');
      expect(chunks, isEmpty);
    });

    test('Should keep short text as single chunk', () {
      const text = 'This is a short sentence.';
      final chunks = ChunkEngine.createChunks(text);
      expect(chunks.length, 1);
      expect(chunks.first.text, text);
    });

    test('Should split long text at natural boundaries', () {
      // Create text roughly 2000 chars long to force split
      final sentence = 'This is a sentence that is repeated many times to create length. ' * 50; 
      // 65 chars * 50 = 3250 chars. Max chunk is 1500. Should get ~3 chunks.
      
      final chunks = ChunkEngine.createChunks(sentence);
      
      expect(chunks.length, greaterThan(1));
      
      for (final chunk in chunks) {
        expect(chunk.text.length, lessThanOrEqualTo(1500));
        // Should roughly be > 100 unless it's the last tail
        if (chunk != chunks.last) {
           expect(chunk.text.length, greaterThan(100)); // Arbitrary efficient min size
        }
        
        // Verify boundary integrity (ends with punctuation usually, or space)
        // With current engine, it might strip trailing whitespace, but it should be coherent.
      }
    });

    test('Should merge very small sentences', () {
      const text = 'Hi. '; 
      const text2 = 'How are you? ';
      final text3 = 'I am fine. ' * 20; // Filler to make the chunk substantial
      
      final fullText = text + text2 + text3;
      final chunks = ChunkEngine.createChunks(fullText);
      
      // "Hi." and "How are you?" are < 100 chars, so they should be merged 
      // into the next chunk if possible, or together.
      // Expected: 1 chunk if total < 1500
      expect(chunks.length, 1);
      expect(chunks.first.text, contains('Hi.'));
      expect(chunks.first.text, contains('How are you?'));
    });
    
    test('Should preserve context (titles)', () {
      // Assumption: Engine prepends title if passed?
      // Actually ChunkEngine.chunk takes (text). 
      // The PipelineOrchestrator adds title.
      // So this test might check if ChunkEngine behaves well with "Title. Content..." format.
      
      const title = "Breaking News.";
      const content = "Something happened.";
      final chunks = ChunkEngine.createChunks("$title $content");
      
      expect(chunks.length, 1);
      expect(chunks.first.text, "$title $content");
    });
  });
}
