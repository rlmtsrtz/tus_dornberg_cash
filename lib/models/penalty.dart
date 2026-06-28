class Penalty {
  final String id;
  final String name;
  final double amount;
  final List<String> tags;

  Penalty({
    required this.id,
    required this.name,
    required this.amount,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'tags': tags.join(','), // Store as comma-separated string for Google Sheets
  };

  factory Penalty.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags']?.toString() ?? '';
    return Penalty(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      tags: tagsRaw.isEmpty ? [] : tagsRaw.split(',').map((e) => e.trim()).toList(),
    );
  }
}
