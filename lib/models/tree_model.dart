import 'dart:io';

class TreeModel {
  final int? id;
  final String uuid;
  final String? treeTag;
  final String? speciesId;
  final DateTime? plantedAt;
  final double? height;
  final double? diameter;
  final int? floweringPeriod;
  final String? thumbnail;
  final double? latitude;
  final double? longitude;
  final int synced;
  final File? imageFile;
  final int pendingUpdate;
  final int pendingDelete;

  TreeModel({
    this.id,
    required this.uuid,
    this.treeTag,
    this.speciesId,
    this.plantedAt,
    this.height,
    this.diameter,
    this.floweringPeriod,
    this.thumbnail,
    this.latitude,
    this.longitude,
    this.synced = 0,
    this.imageFile,
    this.pendingUpdate = 0,
    this.pendingDelete = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'uuid': uuid,
    'tree_tag': treeTag,
    'species_id': speciesId,
    'planted_at': plantedAt?.toIso8601String(),
    'height': height,
    'diameter': diameter,
    'flowering_period': floweringPeriod,
    'thumbnail': thumbnail,
    'latitude': latitude,
    'longitude': longitude,
    'synced': synced,
    'pending_update': pendingUpdate,
    'pending_delete': pendingDelete,
  };

  factory TreeModel.fromMap(Map<String, dynamic> map) => TreeModel(
    id: (() {
      final v = map['id'];
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    })(),
    uuid: map['uuid'],
    treeTag: map['tree_tag'],
    speciesId: map['species_id']?.toString(),
    plantedAt: (() {
      final p = map['planted_at'];
      if (p == null) return null;
      try {
        return DateTime.parse(p.toString());
      } catch (_) {
        return null;
      }
    })(),
    height:
        (map['height'] is num)
            ? (map['height'] as num).toDouble()
            : double.tryParse(map['height']?.toString() ?? '0'),
    diameter:
        (map['diameter'] is num)
            ? (map['diameter'] as num).toDouble()
            : double.tryParse(map['diameter']?.toString() ?? '0'),
    floweringPeriod: (() {
      final fp = map['flowering_period'];
      if (fp == null) return null;
      if (fp is int) return fp;
      if (fp is num) return fp.toInt();
      return int.tryParse(fp.toString());
    })(),
    thumbnail: map['thumbnail'],
    latitude:
        (map['latitude'] is num)
            ? (map['latitude'] as num).toDouble()
            : double.tryParse(map['latitude']?.toString() ?? '0'),
    longitude:
        (map['longitude'] is num)
            ? (map['longitude'] as num).toDouble()
            : double.tryParse(map['longitude']?.toString() ?? '0'),
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

  TreeModel copyWith({
    int? id,
    String? uuid,
    String? treeTag,
    String? speciesId,
    DateTime? plantedAt,
    double? height,
    double? diameter,
    int? floweringPeriod,
    String? thumbnail,
    double? latitude,
    double? longitude,
    int? synced,
    File? imageFile,
    int? pendingUpdate,
    int? pendingDelete,
  }) {
    return TreeModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      treeTag: treeTag ?? this.treeTag,
      speciesId: speciesId ?? this.speciesId,
      plantedAt: plantedAt ?? this.plantedAt,
      height: height ?? this.height,
      diameter: diameter ?? this.diameter,
      floweringPeriod: floweringPeriod ?? this.floweringPeriod,
      thumbnail: thumbnail ?? this.thumbnail,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      synced: synced ?? this.synced,
      imageFile: imageFile ?? this.imageFile,
      pendingUpdate: pendingUpdate ?? this.pendingUpdate,
      pendingDelete: pendingDelete ?? this.pendingDelete,
    );
  }
}
