# 🔊 Áudio e Voz

## Perfis de Voz (Falas)

| Perfil | Característica | Exemplo |
|--------|---------------|---------|
| Padrão | Resumido, sem enrolar | "Próxima parada 3, em 2 km" |
| Waze | Muito curto | "Próxima: 3" |
| Uber | Objetivo com número | "Próxima parada 3" |
| 99 | Mínimo | "3, 2 km" |

## Slots de Som (SlotSom)

| Slot | Descrição |
|------|-----------|
| `inicioApp` | Toca ao abrir o app |
| `entradaParada` | Sino de chegada |
| `sinoEstacao` | Sino de trem (sempre toca na chegada) |
| `saidaParada` | Som de saída |
| `proximaParada` | Aproximação da entrega |
| `alertaRadar` | Alerta de radar próximo |
| `avisoGeral` | Aviso geral do app |

## Regras de Som
- Sino toca **uma vez só** na chegada
- Saída tem som próprio
- Voz fala na chegada e a cada faixa de aproximação (1 km, 500 m, 200 m)
- Vibração forte na chegada
- Rádio abaixa (duck) enquanto a voz fala
- Opção "Só o sino (sem falar as ruas)"

## ÁudioProvider
- Música de fundo, rádio online, volume, favoritos, recentes
- Ducking: abaixa rádio quando a voz fala

## SonsProvider
- Sons personalizados por slot (importados pelo usuário)
- Arquivos copiados para pasta privada do app

## VoiceService (TTS)
- flutter_tts com idioma pt-BR
- Voz, velocidade e tom configuráveis
- Perfil de fala selecionável
