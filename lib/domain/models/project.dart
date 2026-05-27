class Project {
  final int? id;
  final String name;
  final String date;

  Project({
    this.id,
    required this.name,
    required this.date,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as int?,
      name: map['name'] as String,
      date: map['date'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'date': date,
    };
  }
}
