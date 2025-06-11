
class Species {
  final String name;
  final String code;
  final String? description;
  final int treeCount;
  final bool isActive;

  Species({
    required this.name,
    required this.code,
    this.description,
    required this.treeCount,
    required this.isActive,
  });

  factory Species.fromJson(Map<String, dynamic> json) {
    return Species(
      name: json['name'],
      code: json['code'],
      description: json['description'],
      treeCount: json['trees_count'] ?? 0,
      isActive: json['is_active'] == true,
    );
  }
}
