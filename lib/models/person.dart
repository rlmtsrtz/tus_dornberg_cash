class Person {
  final String id;
  final String name;
  final List<String> groups; // Liste von Gruppen-IDs oder Namen

  Person({required this.id, required this.name, required this.groups});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'groups': groups,
  };

  factory Person.fromJson(Map<String, dynamic> json) {
    // Falls das Feld 'group' (alt) noch existiert, konvertieren wir es in eine Liste
    List<String> groupsList = [];
    if (json['groups'] != null) {
      groupsList = List<String>.from(json['groups']);
    } else if (json['group'] != null) {
      groupsList = [json['group'].toString()];
    }

    return Person(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      groups: groupsList,
    );
  }
}
