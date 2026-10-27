# 🔧 Providers (Gerenciamento de Estado)

| Provider | Responsabilidade | Persistência |
|----------|-----------------|--------------|
| `AuthProvider` | Login, cadastro, sessão, token, conexão socket | SharedPreferences (`session.driver`, `session.token`) |
| `SettingsProvider` | FPS, camada, GPS, tema, som, cor da rota, modo câmera | SharedPreferences (`settings.*`) |
| `AlertProvider` | Alertas/sinais de estrada (adicionar, ocultar, limpar) | SharedPreferences (`alerts.hidden.v1`) |
| `PeerProvider` | Caminhões próximos (radar V2X) | Memória (via socket) |
| `MarkerProvider` | Sinais/emoji temporários no mapa (TTL 12h) | Memória + limpeza automática |
| `RouteProvider` | Rota com paradas, chegada, entrega, recálculo por desvio | SharedPreferences (stops, status) |
| `SharedRoutesProvider` | Rotas compartilhadas de grupos, visibilidade, progresso | SharedPreferences (`ocultas`, `seguindo`) |
| `GroupProvider` | Grupos/comboios (criar, entrar, sair, membros) | REST API + SharedPreferences |
| `TripProvider` | Histórico de viagens local | SharedPreferences (`history.trips`, max 50) |
| `WeatherProvider` | Clima (Open-Meteo) + alertas de vento/chuva | Memória + cache |
| `MapLayersProvider` | Camadas ambientais: radar, nuvens, relevo, precipitação, vento, temperatura | Memória + Timer |
| `AudioProvider` | Música, rádio online, volume, favoritos | SharedPreferences (`audio_*`, `radio.*`) |
| `SonsProvider` | Sons personalizados por slot | SharedPreferences (`sons.customizados`) |
| `VoiceService` | TTS: voz, velocidade, tom, perfil, modo de fala | SharedPreferences (`audio_voz*`) |
| `NavigationProvider` | Estado de navegação (iniciar/parar) | Memória |
