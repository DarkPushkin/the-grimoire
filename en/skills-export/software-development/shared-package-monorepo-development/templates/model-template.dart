# Dart Model Template (shared/models/lib/src/)

Use this template when creating new model files for the simplex-node monorepo.

## Basic Model Structure

```dart
/// [ClassName] represents [description]
class ClassName {
  final Type fieldName;
  final Type? optionalField; // nullable for optional JSON fields

  ClassName({
    required this.fieldName,
    this.optionalField,
  });

  factory ClassName.fromJson(Map<String, dynamic> json) {
    return ClassName(
      fieldName: (json['snake_case_field'] as Type?)?.toType() ?? defaultValue,
      optionalField: (json['optional_field'] as Type?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'snake_case_field': fieldName,
      if (optionalField != null) 'optional_field': optionalField,
    };
  }
}
```

## Common Patterns for simplex-node

### Numeric amounts (ng - nano-gold)
```dart
// Go uses int64, Dart uses int
final int amountNg;
amountNg: (json['amount_ng'] as num?)?.toInt() ?? 0,
```

### Optional double ratios
```dart
final double? ratio;
ratio: (json['ratio'] as num?)?.toDouble(),
```

### Optional timestamps
```dart
final int? timestampMs;
timestampMs: (json['timestamp_ms'] as num?)?.toInt(),
```

### Enum-like strings
```dart
final String status;
status: json['status'] as String? ?? 'unknown',

// With computed label
String get statusLabel {
  switch (status) {
    case 'active': return 'Active';
    case 'pending': return 'Pending';
    default: return status;
  }
}
```

## Example: MarketListing Model

```dart
/// MarketListing represents a marketplace listing
class MarketListing {
  final String id;
  final String itemId;
  final String seller;
  final int priceNg;
  final int quantity;
  final String status;
  final String createdAt;

  MarketListing({
    required this.id,
    required this.itemId,
    required this.seller,
    required this.priceNg,
    required this.quantity,
    required this.status,
    required this.createdAt,
  });

  factory MarketListing.fromJson(Map<String, dynamic> json) {
    return MarketListing(
      id: json['id'] as String? ?? '',
      itemId: json['item_id'] as String? ?? '',
      seller: json['seller'] as String? ?? '',
      priceNg: (json['price_ng'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_id': itemId,
      'seller': seller,
      'price_ng': priceNg,
      'quantity': quantity,
      'status': status,
      'created_at': createdAt,
    };
  }

  // Computed getters for screen compatibility
  String get serial => id;
  int get denominationNg => priceNg;
  String get grade => 'standard';
  bool get available => status == 'active';
  String get sellerShort => seller.length > 12 ? '${seller.substring(0, 12)}...' : seller;
}
```

## Export from models.dart

```dart
// In shared/models/lib/models.dart
export 'src/class_name.dart';
```

## Adding to pubspec.yaml

```yaml
# No additional deps needed for basic models
# Only add if using json_serializable, equatable, etc.
```