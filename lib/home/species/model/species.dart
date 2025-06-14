
class Species {
  final int id;
  final String name;
  final String code;
  final String? description;
  final int treeCount;

  Species({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.treeCount,
  });

  factory Species.fromJson(Map<String, dynamic> json) {
    return Species(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      description: json['description'],
      treeCount: json['trees_count'] ?? 0,
    );
  }
}
