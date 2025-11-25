class TreeGrowthModel {
  final int? id;
  final String uuid; // client-generated uuid for the growth log
  final String treeUuid; // uuid of the parent tree
  final double? height;
  final double? diameter;
  final String? notes;
  final String? createdAt; // ISO8601 string
  final int synced;
  final int pendingUpdate;
  final int pendingDelete;

  TreeGrowthModel({
    this.id,
    required this.uuid,
    required this.treeUuid,
    this.height,
    this.diameter,
    this.notes,
    this.createdAt,
    this.synced = 0,
    this.pendingUpdate = 0,
    this.pendingDelete = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'tree_uuid': treeUuid,
        'height': height,
        'diameter': diameter,
        'notes': notes,
        'created_at': createdAt,
        'synced': synced,
        'pending_update': pendingUpdate,
        'pending_delete': pendingDelete,
      };

  factory TreeGrowthModel.fromMap(Map<String, dynamic> map) {
    return TreeGrowthModel(
      id: (() {
        final v = map['id'];
        if (v == null) return null;
        if (v is int) return v;
        return int.tryParse(v.toString());
      })(),
      uuid: (map['uuid'] ?? map['id'] ?? map['uuid'])?.toString() ?? '',
      treeUuid: (map['tree_uuid'] ?? map['treeUuid'] ?? map['treeId'])?.toString() ?? '',
      height: (map['height'] is num) ? (map['height'] as num).toDouble() : double.tryParse(map['height']?.toString() ?? ''),
      diameter: (map['diameter'] is num) ? (map['diameter'] as num).toDouble() : double.tryParse(map['diameter']?.toString() ?? ''),
      notes: map['notes']?.toString(),
      createdAt: (map['created_at'] ?? map['createdAt'] ?? map['created'])?.toString(),
      synced: (() {
        final s = map['synced'];
        if (s == null) return 0;
        if (s is int) return s;
        return int.tryParse(s.toString()) ?? 0;
      })(),
      pendingUpdate: (() {
        final p = map['pending_update'];
        if (p == null) return 0;
        if (p is int) return p;
        return int.tryParse(p.toString()) ?? 0;
      })(),
      pendingDelete: (() {
        final p = map['pending_delete'];
        if (p == null) return 0;
        if (p is int) return p;
        return int.tryParse(p.toString()) ?? 0;
      })(),
    );
  }

  TreeGrowthModel copyWith({
    int? id,
    String? uuid,
    String? treeUuid,
    double? height,
    double? diameter,
    String? notes,
    String? createdAt,
    int? synced,
    int? pendingUpdate,
    int? pendingDelete,
  }) {
    return TreeGrowthModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      treeUuid: treeUuid ?? this.treeUuid,
      height: height ?? this.height,
      diameter: diameter ?? this.diameter,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      pendingUpdate: pendingUpdate ?? this.pendingUpdate,
      pendingDelete: pendingDelete ?? this.pendingDelete,
    );
  }

  @override
  String toString() {
    return 'TreeGrowthModel(uuid: $uuid, treeUuid: $treeUuid, height: $height, diameter: $diameter, createdAt: $createdAt, synced: $synced)';
  }
}