/// Converts the single amount field in the design into the existing API fields.
class FoodAmount {
  const FoodAmount(this.quantity, this.unit);
  final String quantity;
  final String unit;

  static bool isUnspecified(String text) =>
      text.trim().isEmpty || text.trim().toLowerCase() == 'not specified';

  static FoodAmount? tryParse(String text) {
    final match = RegExp(r'^(\d{1,6}(?:\.\d{1,2})?)(?:\s*([^\d.\-/+\s].*))?$')
        .firstMatch(text.trim());
    if (match == null) return null;
    final quantity = match.group(1)!;
    final unit = match.group(2)?.trim() ?? 'item';
    if ((double.tryParse(quantity) ?? 0) <= 0 ||
        unit.isEmpty ||
        unit.length > 30 ||
        RegExp(r'^[\d.\-/+]').hasMatch(unit)) {
      return null;
    }
    return FoodAmount(quantity, unit);
  }
}
