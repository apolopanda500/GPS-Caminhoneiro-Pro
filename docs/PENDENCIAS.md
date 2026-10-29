# ⏳ Pendências Conhecidas (Ação do Usuário)

## Pendências Críticas

| # | Pendência | Impacto | Status |
|---|-----------|---------|--------|
| 1 | `envs PIX_*` no Render | Premium quebrado em produção | Pendente |
| 2 | `DATABASE_URL` do Render → pooler Supabase | Postgres do Render expira em 18/11/2026 | Pendente |
| 3 | SHA-1 (release + debug) na chave do Google Routes | Rota com trânsito ao vivo responde 403 | Pendente |
| 4 | Perfil no celular → SALVAR após troca do banco | Foto do perfil pode ser perdida | Pendente |

## Pendências Opcionais (Novas Sessões)

| # | Pendência | Descrição |
|---|-----------|-----------|
| 5 | Notificação push mais rica na barra do Android | Melhorar notificações do sistema |
| 6 | Mais opções de ângulo/inclinação da câmera | Câmera 3D aprimorada |
| 7 | Melhorar "aparência" (barras, bordas, linhas, temas) | UI refinada |
| 8 | Duplicidade dos botões Mapa/Gráfico | Manter só na tela principal |
| 9 | Camadas (nuvens/terrenos/ventos/precipitação) | Precisam mudar de verdade ou serem removidas |
| 10 | Foto de perfil visível a todos | Compartilhamento de foto na rede |
| 11 | Sensibilidade dos botões flutuantes | Ajuste de toque |
| 12 | Rota só com pesquisa de endereços próximos | Remover bairro da busca |
| 13 | Fundir "limpar sinais" e "limpar cache" | Simplificar UX |
| 14 | Checklist completo de todos os botões | Real vs genérico com baterias |

## SHA-1 para Google Cloud Console

| Keystore | SHA-1 | Uso |
|----------|-------|-----|
| `android/app/upload-keystore.jks` (release) | `2F:AE:30:A2:3F:CC:E2:5F:29:08:2A:CE:4B:02:02:07:C9:54:83:34` | APK de release (Play Store) |
| `~/.android/debug.keystore` (debug) | `C4:EB:B1:5B:BA:7F:D2:7F:79:FA:45:6E:DF:B3:E6:09:57:73:14:DD` | APK de debug |

SHA-256 do release: `72:ED:AA:CD:F3:E4:E7:3B:C4:9F:AA:1D:8A:2D:DD:81:80:9C:7D:67:98:C0:E7:16:E7:19:8B:B8:E6:F3:46:15`

Package name: `com.gpscamioneiro.gps_camioneiro_pro`

## Resolvido na sessão 28/10/2026

| Item | Situação |
|---|---|
| Crash do `animateCamera` no MapLibre | Corrigido e validado no celular (sem `E flutter` no startup) |
| Tiles "Zoom Level Not Supported" do RainViewer | Corrigido com `maxzoom = 7`; radar anima 13 frames |
| Camadas de clima (item 9) | Radar de chuva e nuvens reais confirmados; grade Open-Meteo segue como previsão |
| Bateria de uso real só com celular | `--sem-emulador` com GPS real: 12/12 (10.0) em duas rodadas |
| Testes | Flutter 235/235, backend 29/29, simulação real 10/10 |

Detalhes e evidências em [SESSAO-2026-10-28.md](SESSAO-2026-10-28.md).
