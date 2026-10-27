# 🗺️ Mapa e Rota

## Camadas de Mapa (sem chave API necessária)

| Camada | Provedor | URL |
|--------|----------|-----|
| Ruas (claro/escuro) | OpenStreetMap / OpenFreeMap | tile.openstreetmap.org |
| Satélite | Esri World Imagery | server.arcgisonline.com |
| Detalhada (3D prédios) | OpenFreeMap vetorial | tiles.openfreemap.org |

## Câmera 3D
- Rotação (bearing) e inclinação (pitch) com gestos de dois dedos
- 3 modos: Norte, Navegação, Cabine 3D (tilt 60°)
- Botão 3D e botão "Aqui" controlam a câmera

## Rota com Paradas
- Busca de endereços via Nominatim/OSM (geocoding automático ao digitar)
- Cálculo via Google Directions API (chave opcional em `app_constants.dart`)
- Fallback: OpenRouteService (caminhão) → TomTom (trânsito) → OSRM (reserva)
- Recálculo automático em desvio (>80 m, 3 leituras, cooldown 25s)
- Paradas com status: pendente → chegou → entregue
- Dwell time: 45s parado confirma entrega
- ETA e distância exibidos no painel de rota

## Camadas Ambientais (tempo real)
- Radar de chuva animado (RainViewer, frames a cada 10 min)
- Nuvens infravermelho (com fallback Open-Meteo)
- Relevo/hillshade (AWS Terrain Tiles DEM)
- Precipitação, vento, temperatura (Open-Meteo, círculos coloridos)

## Sinais/emoji no mapa
- TTL: 12 horas (expiração automática)
- Limpeza a cada 5 minutos
- Toque longo no mapa ou FAB para colocar sinal
