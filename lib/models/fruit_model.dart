class FruitModel {
  final String? fruit_tag;
  final String? harvest_uuid;
  final String? transaction_uuid;
  final String? harvested_at;
  final String? created_at;
  final bool is_spoiled;
  final String? tree_uuid;
  final double? weight;
  final String? grade;

  final int synced;          // 0 = offline, 1 = synced
  final int pendingUpdate;   // 1 if waiting for update sync
  final int pendingDelete;   // 1 if waiting for delete sync

  FruitModel({
    this.fruit_tag,
    this.harvest_uuid,
    this.transaction_uuid,
    this.harvested_at,
    this.is_spoiled = false,
    this.tree_uuid,
    this.weight,
    this.grade,
    this.created_at,
    this.synced = 0,
    this.pendingUpdate = 0,
    this.pendingDelete = 0,
  });

  /// Convert model to map for SQLite or JSON upload
  Map<String, dynamic> toMap() => {
    'fruit_tag': fruit_tag,
        'harvest_uuid': harvest_uuid,
        'transaction_uuid': transaction_uuid,
        'harvested_at': harvested_at,
        'created_at': created_at,
        'is_spoiled': is_spoiled ? 1 : 0,
        'tree_uuid': tree_uuid,
        'weight': weight,
        'grade': grade,
        'synced': synced,
        'pending_update': pendingUpdate,
        'pending_delete': pendingDelete,
      };

  /// Create FruitModel from SQLite or API map
  factory FruitModel.fromMap(Map<String, dynamic> map) {
    return FruitModel(
      fruit_tag: (map['fruit_tag'] ?? map['fruitTag'] ?? map['tag'])?.toString(),
      // Accept multiple key names that different APIs may return.
      harvest_uuid: (map['harvest_uuid'] ?? map['harvestId'] ?? map['uuid'] ?? map['id'])?.toString(),
      transaction_uuid: (map['transaction_uuid'] ?? map['tx_uuid'] ?? map['transactionId'])?.toString(),
  harvested_at: (map['harvested_at'] ?? map['date'] ?? map['harvestedAt'])?.toString(),
  created_at: (map['created_at'] ?? map['createdAt'] ?? map['created'])?.toString(),
      is_spoiled: (map['is_spoiled'] == 1 || map['is_spoiled'] == true),
      tree_uuid: map['tree_uuid']?.toString(),
      weight: (map['weight'] is num)
          ? (map['weight'] as num).toDouble()
          : double.tryParse(map['weight']?.toString() ?? '0') ?? 0,
      grade: map['grade']?.toString(),
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

  /// Copy model with modifications
  FruitModel copyWith({
    String? fruit_tag,
    String? harvest_uuid,
    String? transaction_uuid,
    String? harvested_at,
    bool? is_spoiled,
    String? tree_uuid,
    double? weight,
    String? grade,
    String? created_at,
    int? synced,
    int? pendingUpdate,
    int? pendingDelete,
  }) {
    return FruitModel(
      fruit_tag: fruit_tag ?? this.fruit_tag,
      harvest_uuid: harvest_uuid ?? this.harvest_uuid,
      transaction_uuid: transaction_uuid ?? this.transaction_uuid,
      harvested_at: harvested_at ?? this.harvested_at,
      is_spoiled: is_spoiled ?? this.is_spoiled,
      tree_uuid: tree_uuid ?? this.tree_uuid,
      weight: weight ?? this.weight,
      grade: grade ?? this.grade,
      created_at: created_at ?? this.created_at,
      synced: synced ?? this.synced,
      pendingUpdate: pendingUpdate ?? this.pendingUpdate,
      pendingDelete: pendingDelete ?? this.pendingDelete,
    );
  }

  /// Helpful for debugging
  @override
  String toString() {
    return 'FruitModel(fruit_tag: $fruit_tag, harvest_uuid: $harvest_uuid, tree_uuid: $tree_uuid, '
        'weight: $weight, grade: $grade, synced: $synced, '
        'pendingUpdate: $pendingUpdate, pendingDelete: $pendingDelete)';
  }
}
