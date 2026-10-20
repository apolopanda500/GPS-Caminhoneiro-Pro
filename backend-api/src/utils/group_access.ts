export interface ConvoyGroupRow {
  id: string;
  name: string;
  owner_driver_id: string | null;
  is_public: boolean;
}

export interface SharedRouteRow {
  id: string;
  group_id: string;
  driver_id: string | null;
  driver_name: string;
  payload: unknown;
  is_public: boolean;
}

/** Decisao de visibilidade: rota visivel se o grupo for publico, a rota for
publica (para grupos publicos) ou o solicitante for membro do grupo. */
export function canSeeRoute(
  group: { is_public: boolean } | null | undefined,
  route: { is_public: boolean; group_id: string },
  isMember: boolean,
): boolean {
  if (isMember) return true;
  if (!group || !group.is_public) return false;
  return route.is_public;
}

export function isOwner(group: ConvoyGroupRow | null | undefined, driverId: string | null | undefined): boolean {
  return Boolean(group && driverId && group.owner_driver_id === driverId);
}
