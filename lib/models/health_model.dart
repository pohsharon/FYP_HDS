class HealthModel {
  final String? tree_uuid;
  final String? diseaseId;
  final String? status;
  final String? recorded_at;
  final String? treatment;
  final String? thumbnail;

  final int synced;
  final int pendingUpdate;
  final int pendingDelete;

  HealthModel({
    this.tree_uuid,
    this.diseaseId,
    this.status,
    this.recorded_at,
    this.treatment,
    this.thumbnail,
    this.synced = 0,
    this.pendingUpdate = 0,
    this.pendingDelete = 0,
  });

  /// Convert model to map for SQLite or JSON upload
  Map<String, dynamic> toMap() => {
    'tree_uuid': tree_uuid,
        'diseaseId': diseaseId,
        'status': status,
        'recorded_at': recorded_at,
        'treatment': treatment,
        'thumbnail': thumbnail,
        'synced': synced,
        'pending_update': pendingUpdate,
        'pending_delete': pendingDelete,
      };

  factory HealthModel.fromMap(Map<String, dynamic> map) {
    return HealthModel(
      tree_uuid: (map['tree_uuid'] ?? map['treeUuid'] ?? map['uuid'] ?? map['id'])?.toString(),
      diseaseId: (map['diseaseId'] ?? map['disease_id'])?.toString(),
      status: (map['status'])?.toString(),
      recorded_at: (map['recorded_at'] ?? map['recordedAt'])?.toString(),
      treatment: (map['treatment'])?.toString(),
      thumbnail: (map['thumbnail'])?.toString(),
      synced: (map['synced'] is int) ? map['synced'] : int.tryParse(map['synced']?.toString() ?? '0') ?? 0,
      pendingUpdate: (map['pending_update'] is int) ? map['pending_update'] : int.tryParse(map['pending_update']?.toString() ?? '0') ?? 0,
      pendingDelete: (map['pending_delete'] is int) ? map['pending_delete'] : int.tryParse(map['pending_delete']?.toString() ?? '0') ?? 0,
    );
  }

  /// Copy model with modifications
  HealthModel copyWith({
    String? tree_uuid,
    String? diseaseId,
    String? status,
    String? recorded_at,
    String? treatment,
    String? thumbnail,
    int? synced,
    int? pendingUpdate,
    int? pendingDelete,
  }) {
    return HealthModel(
      tree_uuid: tree_uuid ?? this.tree_uuid,
      diseaseId: diseaseId ?? this.diseaseId,
      status: status ?? this.status,
      recorded_at: recorded_at ?? this.recorded_at,
      treatment: treatment ?? this.treatment,
      thumbnail: thumbnail ?? this.thumbnail,
      synced: synced ?? this.synced,
      pendingUpdate: pendingUpdate ?? this.pendingUpdate,
      pendingDelete: pendingDelete ?? this.pendingDelete,
    );
  }

  /// Helpful for debugging
  @override
  String toString() {
    return 'HealthModel(tree_uuid: $tree_uuid, diseaseId: $diseaseId, status: $status, '
        'recorded_at: $recorded_at, treatment: $treatment, thumbnail: $thumbnail, synced: $synced, '
        'pendingUpdate: $pendingUpdate, pendingDelete: $pendingDelete)';
  }
}
