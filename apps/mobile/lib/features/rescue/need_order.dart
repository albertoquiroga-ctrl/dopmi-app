import 'rescue_repository.dart';
import '../adoption/community_repository.dart';

int needRank(Object? value) => switch (value.toString().toLowerCase()) {
  'veterinary' || 'veterinario' => 0,
  'medicine' || 'medicina' => 1,
  'food' || 'comida' => 2,
  _ => 3,
};

List<Json> orderedNeedItems(Iterable<Json> values) {
  final indexed = values.toList().asMap().entries.toList();
  indexed.sort((a, b) {
    final difference = needRank(a.value['category'] ?? a.value['type'])
        .compareTo(needRank(b.value['category'] ?? b.value['type']));
    return difference == 0 ? a.key.compareTo(b.key) : difference;
  });
  return indexed.map((entry) => entry.value).toList();
}

/// Presentation order only; never used to allocate financial resources.
List<RescueRecord> orderedNeeds(Iterable<RescueRecord> values) {
  final indexed = values.toList().asMap().entries.toList();
  int rank(RescueRecord value) =>
      needRank(value.publicData['category'] ?? value.publicData['type']);
  indexed.sort((a, b) {
    final difference = rank(a.value).compareTo(rank(b.value));
    return difference == 0 ? a.key.compareTo(b.key) : difference;
  });
  return indexed.map((entry) => entry.value).toList();
}
