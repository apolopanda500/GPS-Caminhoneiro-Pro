enum PremiumFeature {
  streetSearch('Buscar ruas'),
  communityAlerts('Avisar a comunidade'),
  mapSignal('Sinalizar no mapa'),
  radio('Rádio da estrada'),
  peers('Ver outros caminhões'),
  detailedMap('Ruas 3D detalhadas'),
  buildings3d('Prédios em 3D'),
  tripHistory('Histórico de viagens'),
  roadContacts('Contatos de estrada');

  const PremiumFeature(this.label);
  final String label;
}

class PremiumPolicy {
  const PremiumPolicy._();

  static const bool freeHasMap = true;
  static const bool freeHasRoutes = true;

  static const double priceBrl = 4.99;

  static final DateTime promoUntil = DateTime(2026, 11, 29, 23, 59, 59);

  static bool promoActive([DateTime? now]) =>
      (now ?? DateTime.now()).isBefore(promoUntil);

  static bool hasPremiumAccess({
    required bool isPremium,
    DateTime? now,
  }) =>
      isPremium || promoActive(now);

  static bool canUse(
    PremiumFeature feature, {
    required bool isPremium,
    DateTime? now,
  }) =>
      hasPremiumAccess(isPremium: isPremium, now: now);

  static bool isLocked(
    PremiumFeature feature, {
    required bool isPremium,
    DateTime? now,
  }) =>
      !hasPremiumAccess(isPremium: isPremium, now: now);

  static List<PremiumFeature> get features => PremiumFeature.values;

  static List<PremiumFeature> lockedFor(
          {required bool isPremium, DateTime? now}) =>
      hasPremiumAccess(isPremium: isPremium, now: now)
          ? const <PremiumFeature>[]
          : PremiumFeature.values;
}
