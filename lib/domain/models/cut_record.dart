class CutRecord {
  final String id;
  final String apuCodigo;
  final int cutNumber;
  final double activityQuantity;
  final DateTime date;
  final List<CutInsumoPurchase> purchases;

  CutRecord({
    required this.id,
    required this.apuCodigo,
    required this.cutNumber,
    required this.activityQuantity,
    required this.date,
    this.purchases = const [],
  });

  factory CutRecord.fromMap(Map<String, dynamic> map, {List<CutInsumoPurchase> purchases = const []}) {
    return CutRecord(
      id: map['id'] as String,
      apuCodigo: map['apuCodigo'] as String,
      cutNumber: map['cutNumber'] as int,
      activityQuantity: (map['activityQuantity'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      purchases: purchases,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'apuCodigo': apuCodigo,
      'cutNumber': cutNumber,
      'activityQuantity': activityQuantity,
      'date': date.toIso8601String(),
    };
  }
}

class CutInsumoPurchase {
  final String id;
  final String cutRecordId;
  final String insumoDescription;
  final double realPrice;
  final double purchasedQuantity;

  CutInsumoPurchase({
    required this.id,
    required this.cutRecordId,
    required this.insumoDescription,
    required this.realPrice,
    required this.purchasedQuantity,
  });

  double get cost => realPrice * purchasedQuantity;

  factory CutInsumoPurchase.fromMap(Map<String, dynamic> map) {
    return CutInsumoPurchase(
      id: map['id'] as String,
      cutRecordId: map['cutRecordId'] as String,
      insumoDescription: map['insumoDescription'] as String,
      realPrice: (map['realPrice'] as num).toDouble(),
      purchasedQuantity: (map['purchasedQuantity'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cutRecordId': cutRecordId,
      'insumoDescription': insumoDescription,
      'realPrice': realPrice,
      'purchasedQuantity': purchasedQuantity,
    };
  }
}
