class CutRecord {
  final int? id;
  final int activityId;
  final int cutNumber;
  final double activityQuantity;
  final DateTime date;
  final List<CutInsumoPurchase> purchases;

  CutRecord({
    this.id,
    required this.activityId,
    required this.cutNumber,
    required this.activityQuantity,
    required this.date,
    this.purchases = const [],
  });

  factory CutRecord.fromMap(Map<String, dynamic> map, {List<CutInsumoPurchase> purchases = const []}) {
    return CutRecord(
      id: map['id'] as int?,
      activityId: map['activityId'] as int,
      cutNumber: map['cutNumber'] as int,
      activityQuantity: (map['activityQuantity'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      purchases: purchases,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'activityId': activityId,
      'cutNumber': cutNumber,
      'activityQuantity': activityQuantity,
      'date': date.toIso8601String(),
    };
  }
}

class CutInsumoPurchase {
  final int? id;
  final int cutRecordId;
  final int? insumoId;
  final String insumoDescription;
  final double realPrice;
  final double purchasedQuantity;
  final double consumedQuantity;

  CutInsumoPurchase({
    this.id,
    required this.cutRecordId,
    this.insumoId,
    required this.insumoDescription,
    required this.realPrice,
    required this.purchasedQuantity,
    required this.consumedQuantity,
  });

  double get cost => realPrice * consumedQuantity;

  factory CutInsumoPurchase.fromMap(Map<String, dynamic> map) {
    return CutInsumoPurchase(
      id: map['id'] as int?,
      cutRecordId: map['cutRecordId'] as int,
      insumoId: map['insumoId'] as int?,
      insumoDescription: map['insumoDescription'] as String,
      realPrice: (map['realPrice'] as num).toDouble(),
      purchasedQuantity: (map['purchasedQuantity'] as num).toDouble(),
      consumedQuantity: (map['consumedQuantity'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cutRecordId': cutRecordId,
      if (insumoId != null) 'insumoId': insumoId,
      'insumoDescription': insumoDescription,
      'realPrice': realPrice,
      'purchasedQuantity': purchasedQuantity,
      'consumedQuantity': consumedQuantity,
    };
  }
}
