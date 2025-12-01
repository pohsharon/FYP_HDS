class AgrochemicalModel {
  final String? tree_uuid;
  final String? agrochemicalId;
  final String? agrochemicalName;
  final String? applied_at;
  final String? description;

  final int synced;
  final int pendingUpdate;
  final int pendingDelete;

  AgrochemicalModel({
    this.tree_uuid,
    this.agrochemicalId,
    this.agrochemicalName,
    this.applied_at,
    this.description,
    this.synced = 0,
    this.pendingUpdate = 0,
    this.pendingDelete = 0,
  });

  /// Convert model to map for SQLite or JSON upload
  Map<String, dynamic> toMap() => {
    'tree_uuid': tree_uuid,
        'agrochemicalId': agrochemicalId,
        'agrochemical_name': agrochemicalName,
        'applied_at': applied_at,
        'description': description,
        'synced': synced,
        'pending_update': pendingUpdate,
        'pending_delete': pendingDelete,
      };

  factory AgrochemicalModel.fromMap(Map<String, dynamic> map) {
    return AgrochemicalModel(
      tree_uuid: (map['tree_uuid'] ?? map['treeUuid'] ?? map['uuid'] ?? map['id'])?.toString(),
      agrochemicalId: (map['agrochemicalId'] ?? map['agrochemical_id'])?.toString(),
      agrochemicalName: (map['agrochemical_name'] ?? map['agrochemicalName'] ?? (map['agrochemical'] is Map ? (map['agrochemical']['agrochemicalName'] ?? map['agrochemical']['name']) : null))?.toString(),
      applied_at: (map['applied_at'])?.toString(),
      description: (map['description'])?.toString(),
      synced: (map['synced'] is int) ? map['synced'] : int.tryParse(map['synced']?.toString() ?? '0') ?? 0,
      pendingUpdate: (map['pending_update'] is int) ? map['pending_update'] : int.tryParse(map['pending_update']?.toString() ?? '0') ?? 0,
      pendingDelete: (map['pending_delete'] is int) ? map['pending_delete'] : int.tryParse(map['pending_delete']?.toString() ?? '0') ?? 0,
    );
  }

  /// Copy model with modifications
  AgrochemicalModel copyWith({
    String? tree_uuid,
    String? agrochemicalId,
    String? agrochemicalName,
    String? applied_at,
    String? description,
    int? synced,
    int? pendingUpdate,
    int? pendingDelete,
  }) {
    return AgrochemicalModel(
      tree_uuid: tree_uuid ?? this.tree_uuid,
      agrochemicalId: agrochemicalId ?? this.agrochemicalId,
      agrochemicalName: agrochemicalName ?? this.agrochemicalName,
      applied_at: applied_at ?? this.applied_at,
      description: description ?? this.description,
      synced: synced ?? this.synced,
      pendingUpdate: pendingUpdate ?? this.pendingUpdate,
      pendingDelete: pendingDelete ?? this.pendingDelete,
    );
  }

  /// Helpful for debugging
  @override
  String toString() {
    return 'AgrochemicalModel(tree_uuid: $tree_uuid, agrochemicalId: $agrochemicalId, agrochemicalName: $agrochemicalName, applied_at: $applied_at, '
        'description: $description, synced: $synced, '
        'pendingUpdate: $pendingUpdate, pendingDelete: $pendingDelete)';
  }
}
