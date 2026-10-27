# 💎 Premium e PIX

## Política Premium

| Recurso | Gratuito | Premium |
|---------|----------|---------|
| Mapa | ✅ | ✅ |
| Rotas | ✅ | ✅ |
| Busca de ruas | ❌ | ✅ |
| Alertas comunidade | ❌ | ✅ |
| Sinalizar no mapa | ❌ | ✅ |
| Rádio da estrada | ❌ | ✅ |
| Ver outros caminhões | ❌ | ✅ |
| Mapa 3D detalhado | ❌ | ✅ |
| Prédios em 3D | ❌ | ✅ |
| Histórico de viagens | ❌ | ✅ |
| Contatos de estrada | ❌ | ✅ |

- Preço: R$ 4,99/mês
- Promoção ativa até 29/11/2026 (todos os recursos liberados durante promo)
- `PremiumPolicy.canUse(feature, isPremium: bool)` controla acesso

## PIX
- Geração de BR Code com CRC16 recalculado
- Validação campo a campo do BR Code
- Chaves configuradas no Render: `PIX_KEY`, `PIX_NAME`, `PIX_CITY`, `PIX_AMOUNT`, `PIX_DESCRIPTION`
- Exemplo: PIX_KEY=rickjax123@gmail.com, PIX_NAME=HENRIQUE DE CARVALHO
