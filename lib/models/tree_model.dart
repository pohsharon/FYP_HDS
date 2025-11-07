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
    'synced': synced ?? 0,
  };

  factory TreeModel.fromMap(Map<String, dynamic> map) => TreeModel(
    id: map['id'],
    uuid: map['uuid'],
    treeTag: map['tree_tag'],
    speciesId: map['species_id']?.toString(),
    plantedAt: DateTime.parse(map['planted_at']),
    height:
        (map['height'] is num)
            ? map['height'].toDouble()
            : double.tryParse(map['height'] ?? '0'),
    diameter:
        (map['diameter'] is num)
            ? map['diameter'].toDouble()
            : double.tryParse(map['diameter'] ?? '0'),
    floweringPeriod: map['flowering_period'],
    thumbnail: map['thumbnail'],
    latitude:
        (map['latitude'] is num)
            ? map['latitude'].toDouble()
            : double.tryParse(map['latitude'] ?? '0'),
    longitude:
        (map['longitude'] is num)
            ? map['longitude'].toDouble()
            : double.tryParse(map['longitude'] ?? '0'),
    synced: map['synced'] ?? 0,
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
    );
  }
}
