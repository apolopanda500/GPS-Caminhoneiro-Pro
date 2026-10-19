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

  static bool canUse(PremiumFeature feature, {required bool isPremium}) =>
      isPremium;

  static bool isLocked(PremiumFeature feature, {required bool isPremium}) =>
      !isPremium;

  static List<PremiumFeature> get features => PremiumFeature.values;

  static List<PremiumFeature> lockedFor({required bool isPremium}) =>
      isPremium ? const <PremiumFeature>[] : PremiumFeature.values;
}
