enum AdjustmentType {
  delete,
  insert,
}

class PositionAdjustment {
  final AdjustmentType type;
  final int position;
  final int length;

  PositionAdjustment({
    required this.type,
    required this.position,
    required this.length,
  });
}