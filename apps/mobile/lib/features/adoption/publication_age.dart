/// Bare numbers retain the existing draft contract: months.
int? publicationAgeMonths(String input) {
  final value = input.trim().toLowerCase();
  if (value.isEmpty) return 0;
  final bare = int.tryParse(value);
  if (bare != null) return bare >= 0 && bare <= 360 ? bare : null;
  final match = RegExp(
    r'^(?:(\d+)\s*(?:años?|anos?)\s*)?(?:(?:y\s+)?(\d+)\s*mes(?:es)?)?$',
  ).firstMatch(value);
  if (match == null || (match[1] == null && match[2] == null)) return null;
  final years = int.tryParse(match[1] ?? '0');
  final months = int.tryParse(match[2] ?? '0');
  if (years == null || months == null || years > 30 || months > 360) return null;
  final total = years * 12 + months;
  return total <= 360 ? total : null;
}
