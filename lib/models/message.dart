class ChatMessage {
  final String role; // "user" или "assistant"
  final String text;
  final bool isCorrections; // отдельное сообщение с ошибками

  ChatMessage({
    required this.role,
    required this.text,
    this.isCorrections = false,
  });
}

class SavedWord {
  final String word;
  final String translation;
  final String example;
  final String exampleTranslation;

  const SavedWord({
    required this.word,
    required this.translation,
    required this.example,
    required this.exampleTranslation,
  });
}
