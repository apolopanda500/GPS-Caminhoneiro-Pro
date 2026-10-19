# Guia do Mapa (MapLibre GL + Satélite)

O GPS Caminhoneiro Pro usa **`maplibre_gl`** (MapLibre GL Native) com estilos raster
gratuitos — nenhuma chave de API é necessária para o mapa.

## Camadas disponíveis

| Camada | Provedor | URL | Estilo |
|--------|----------|-----|--------|
| Ruas | OpenStreetMap | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | `assets/map_styles/style_streets.json` |
| Satélite | Esri World Imagery | `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}` | `assets/map_styles/style_satellite.json` |

A troca de camada é feita pelo botão de camada (canto superior direito) ou pelo menu do mapa.
O MapLibre aplica o estilo chamando `controller.setStyle(json)`.

## Como funciona

No `lib/views/map/map_screen.dart`:

- `MapLibreMap` renderiza o mapa; a câmera suporta **rotação (bearing)** e
  **inclinação/tilt (pitch)** — o famoso "3D de todos os ângulos" com gestos de
  dois dedos (arrastar para inclinar, girar para rotacionar).
- Os estilos são lidos de `assets/map_styles/*.json` via `rootBundle` e passados como
  JSON para `styleString` (assim a troca de camada funciona sem rede extra).
- Marcadores são **símbolos** do MapLibre (`addSymbol`), desenhados como imagens em
  runtime (`lib/views/map/utils/map_icons.dart`) porque o MapLibre não renderiza
  widgets Flutter nem emoji em `textField` de forma confiável:
  - caminhões próximos (V2X) — toque abre o perfil;
  - alertas de via ativos;
  - sinais/emoji temporários (TTL 12h);
  - posição atual do caminhão (azul);
  - paradas de rota numeradas.
- `controller.addLine` desenha a polilinha da rota planejada.
- O botão **3D** e o botão **Aqui** (`gps_fixed`) controlam a câmera (inclinar / recentralizar).
- Ao trocar de camada, `onStyleLoadedCallback` é chamado novamente e os marcadores são
  redesenhados (as imagens precisam ser reenviadas com `addImage`).

## Rota com paradas (Google Directions)

A aba **Rota** (`lib/views/map/widgets/route_planner_sheet.dart`) permite buscar endereços
(Nominatim/OSM), adicionar e reordenar paradas e calcular a rota.

- Serviço: `lib/core/network/directions_service.dart` (Google Directions, decode de polyline).
- Estado: `lib/providers/route_provider.dart` (registrado em `lib/main.dart`).
- Exige a chave do Google Directions em `AppConstants.googleDirectionsApiKey`
  (`lib/core/constants/app_constants.dart`). Enquanto não configurada
  (`directionsConfigured == false`), o cálculo retorna uma mensagem amigável.

## Boas práticas de uso dos tiles

- O OpenStreetMap é gratuito, mas **não** use em produção com tráfego alto sem antes
  consultar a [política de uso](https://operations.osmfoundation.org/policies/tiles/).
- O MapLibre envia o User-Agent do app; garanta um UA identificável e cache local.
- Para produção, considere provedores com chave (MapTiler, Stadia, Mapbox) trocando o
  `tiles` do estilo JSON correspondente.

## Permissões

O `AndroidManifest.xml` já declara:

- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION`
- `INTERNET`
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_LOCATION`
- `WAKE_LOCK`

O app solicita a permissão de localização na primeira execução via `LocationHandler`.
