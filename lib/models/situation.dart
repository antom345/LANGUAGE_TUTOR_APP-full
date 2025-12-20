class SituationContext {
  final String myRole;
  final String partnerRole;
  final String circumstances;

  const SituationContext({
    required this.myRole,
    required this.partnerRole,
    required this.circumstances,
  });

  factory SituationContext.fromJson(Map<String, dynamic> json) {
    String stringify(dynamic value) {
      if (value == null) return '';
      if (value is String) return value.trim();
      return value.toString().trim();
    }
    return SituationContext(
      myRole: stringify(
        json['my_role'] ??
            json['myRole'] ??
            json['learner_role'] ??
            json['learnerRole'],
      ),
      partnerRole: stringify(
        json['partner_role'] ?? json['partnerRole'] ?? json['ai_role'],
      ),
      circumstances: stringify(json['circumstances'] ?? json['context']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'my_role': myRole,
      'partner_role': partnerRole,
      'circumstances': circumstances,
    };
  }

  SituationContext copyWith({
    String? myRole,
    String? partnerRole,
    String? circumstances,
  }) {
    return SituationContext(
      myRole: myRole ?? this.myRole,
      partnerRole: partnerRole ?? this.partnerRole,
      circumstances: circumstances ?? this.circumstances,
    );
  }

  String shortSummary({int maxChars = 96}) {
    final base = '${partnerRole.trim()}: ${circumstances.trim()}'.trim();
    final source = base.isEmpty ? circumstances.trim() : base;
    if (source.length <= maxChars) return source;
    return '${source.substring(0, maxChars).trim()}…';
  }
}
