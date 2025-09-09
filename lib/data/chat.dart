class Chat {
  Chat({
    required this.id,
    required this.title,
    this.model = 'gpt-4o',
    this.temperature = 0.7,
    this.topP = 1.0,
    this.maxTokens = 2048.0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
        id: json['id'] as String,
        title: json['title'] as String,
        model: json['model'] as String? ?? 'gpt-4o',
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        topP: (json['topP'] as num?)?.toDouble() ?? 1.0,
        maxTokens: (json['maxTokens'] as num?)?.toDouble() ?? 2048.0,
      );

  final String id;
  final String title;
  final String model;
  final double temperature;
  final double topP;
  final double maxTokens;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'model': model,
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
      };
}