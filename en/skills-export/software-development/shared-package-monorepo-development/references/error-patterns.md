# Common Error Patterns & Fixes (simplex-node Monorepo)

## Model-Screen Mismatch Errors

### Pattern: Screen uses fields model doesn't have
```
error - market_screen.dart:143:9 - The named parameter 'serial' isn't defined
error - market_screen.dart:144:9 - The named parameter 'denominationNg' isn't defined
error - market_screen.dart:165:39 - The getter 'serial' isn't defined for the type 'MarketListing'
```

**Root Cause**: Screen was written against old model structure; new model has different fields.

**Fix Options**:
1. **Extend model** (preferred for backward compatibility):
   ```dart
   class MarketListing {
     // ... existing fields ...
     String get serial => id;
     int get denominationNg => priceNg; // or compute from itemId
     String get grade => 'standard';
     bool get available => status == 'active';
   }
   ```

2. **Refactor screen** to use actual model fields:
   ```dart
   // Instead of listing.serial
   Text(listing.id, style: const TextStyle(fontFamily: 'monospace')),
   // Instead of listing.denominationNg
   NgDisplay(ngAmount: listing.priceNg),
   ```

### Pattern: Missing model classes
```
error - market_screen.dart:19:8 - The name 'MarketListing' isn't a type
error - market_screen.dart:20:8 - The name 'MarketOrder' isn't a type
```

**Fix**: Create model file in `shared/models/lib/src/` and export from `models.dart`

## Model-Backend Mismatch

### Pattern: Type mismatch on deserialization
```
type 'int' is not a subtype of type 'double'
```

**Fix**: In `fromJson`, handle both int and double:
```dart
backingRatio: (json['backing_ratio'] as num?)?.toDouble(),
```

### Pattern: Nullable field accessed without null check
```
The property 'amountNg' can't be unconditionally accessed because the receiver can be 'null'
```

**Fix**: Use `?.` or `!!` or `??` default:
```dart
tx.amountNg?.toString() ?? '0'
tx.amountNg ?? 0
```

## API Client Errors

### Pattern: Method doesn't exist on sub-client
```
error - wallet_screen.dart:156:47 - The method 'receive' isn't defined for the type 'WalletApi'
```

**Fix**: Check `simplex_api_client.dart` for actual methods, or add missing method to sub-client.

### Pattern: Future.wait type inference failure
```
error - royal_screen.dart:49:41 - Couldn't infer type parameter 'E'
```

**Fix**: Explicitly type the list:
```dart
final results = await Future.wait<List<dynamic>>([...]);
// OR cast each element individually
_treasury = results[0] as TreasuryState;
```

## Static Analysis Workflow

### Per-file analysis (fast)
```bash
dart analyze apps/isle_app/lib/screens/royal_screen.dart
dart analyze apps/isle_app/lib/screens/
```

### Fix unused imports automatically
```bash
cd apps/isle_app && dart fix --apply
```

## Common Model Extensions Needed

### MarketListing computed getters
```dart
extension MarketListingExt on MarketListing {
  String get serial => id;
  int get denominationNg => priceNg; // or look up item
  String get grade => 'standard';
  bool get available => status == 'active';
  String get sellerShort => seller.length > 12 ? '${seller.substring(0, 12)}...' : seller;
}
```

### WalletBalance missing fields
```dart
// If screens need these, add to WalletBalance model:
int get stakedNg => reservedNg; // alias
int get silverNg => 0; // compute from silver assets
double get totalValueUsd => totalNg / 414713066 * 75.0; // approximate
```

## Verification Sequence After Model Changes

1. `dart analyze apps/shared/models/lib/src/` - models clean
2. `dart analyze apps/isle_app/lib/screens/<changed>.dart` - each screen clean
3. `dart analyze apps/royal_app/lib/screens/` - admin screens clean
4. `go build ./cmd/simplex-node/` - backend compiles
5. Check API client sub-clients use updated models