# Melhorias Sugeridas — GPS Caminhoneiro Pro

## Alta prioridade
1. **Camadas de clima (nuvens/terreno/vento/precipitação)** — precisam mudar de verdade ou serem removidas (pendência #9). Implementar renderização real via MapLibre ou remover toggles.
2. **Foto de perfil visível a todos** — compartilhamento de avatar na rede (pendência #10).
3. **Duplicidade dos botões Mapa/Gráfico** — manter apenas na tela principal (pendência #8).

## Média prioridade
4. **Rota só com endereços próximos** — remover bairro da busca (pendência #12).
5. **Fundir "limpar sinais" e "limpar cache"** — simplificar UX (pendência #13).
6. **Checklist completo de todos os botões** — real vs genérico com baterias (pendência #14).
7. **Notificação push mais rica** na barra do Android (pendência #5).
8. **Sensibilidade dos botões flutuantes** — ajuste de toque (pendência #11).

## Baixa prioridade / opcional
9. **Backend com PostGIS** — testar quando Docker estiver disponível.
10. **Deploy/push em lote** — aguardando decisão do usuário (sem repositório git remoto configurado).
11. **Emulador AVD `teste_apk`** — configurar para testes automatizados locais.

## Já feito / validado
- Build APK debug instalado e app rodando no celular R9XY1016R6V.
- `flutter analyze` → "No issues found!".
- Bateria app uso real 10/10 (2x) contra produção.
- Banco unificado no Supabase.
- Clima Open-Meteo + RainViewer (radar animado).
- Rota com paradas (Google Directions + Nominatim).
