/// Client request deduplication for the current Mexico City civil day (UTC-6).
/// PostgreSQL computes its own America/Mexico_City day; a wrong device clock
/// can only cause an extra idempotent request, never a second counted view.
String adoptionViewDay(DateTime instant) => instant
    .toUtc()
    .subtract(const Duration(hours: 6))
    .toIso8601String()
    .substring(0, 10);
