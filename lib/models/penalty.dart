class Penalty {
  final String id;
  final String name; // Der Name der Strafe (String)
  final double amount; // Die Höhe in €

  Penalty({required this.id, required this.name, required this.amount});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
  };

  factory Penalty.fromJson(Map<String, dynamic> json) {
    return Penalty(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
