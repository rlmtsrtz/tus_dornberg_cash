enum PersonGroup {
  mg1('Materialgruppe 1'),
  mg2('Materialgruppe 2'),
  mg3('Materialgruppe 3'),
  mg4('Materialgruppe 4'),
  trainer('Trainer'),
  ersatzbank('Ersatzbank');

  final String displayName;
  const PersonGroup(this.displayName);

  static PersonGroup fromString(String value) {
    return PersonGroup.values.firstWhere(
      (e) => e.name == value || e.displayName == value,
      orElse: () => PersonGroup.ersatzbank,
    );
  }
}

class Person {
  final String id;
  final String name;
  final PersonGroup group;

  Person({required this.id, required this.name, required this.group});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'group': group.name,
  };

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      group: PersonGroup.fromString(json['group']?.toString() ?? ''),
    );
  }
}
