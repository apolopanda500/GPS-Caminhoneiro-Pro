# Baterias de simulação real - GPS Caminhoneiro Pro

Todas as baterias rodam contra o **backend de verdade** (Render ou local) e o
**banco de verdade** (PostGIS). Nenhuma delas é "simulada" no papel: cadastro,
socket, grupo, rota, PIX e carga são de verdade.

---

## 1. Bateria multi-usuário (10 perfis)

```bash
node tools/bateria-simulacao-real.js                      # deploy (Render)
node tools/bateria-simulacao-real.js --local              # backend local
node tools/bateria-simulacao-real.js --usuarios 12 --passos 30
```

Cria **N motoristas diferentes** (motorista, ajudante, HAZMAT, premium) e
exercita o ciclo inteiro:

| # | Cenário | O que prova |
|---|---|---|
| 1 | Serviço no ar | `/status` com banco conectado |
| 2 | Cadastro e login | cadastro com e-mail + verificação + login de 10 contas |
| 3 | Perfil e fotos | nome, modelo, carga, foto do motorista e do caminhão |
| 4 | Rede V2X | todos veem todos se movendo (radar em tempo real) |
| 5 | Alertas | sinal criado aparece para quem está perto (socket + REST) e é removido |
| 6 | Chat e reações | chat público, privado, reação por emoji, persistência |
| 7 | Grupos | grupo privado, rota compartilhada visível só para membros, ajudante bloqueado |
| 8 | Premium PIX | BR Code + CRC16 válidos e ativação do Premium |
| 9 | Segurança | token inválido, identidade pelo token, payload hostil |
| 10 | Robustez | desconexão/reconexão, carga sem 5xx, assistente respondendo |

**Resultado local: 10/10 (nota 10/10).**

---

## 2. Bateria das DUAS contas reais (celular + PC)

```bash
# em qualquer deploy (cria as duas contas pela API, como o app faz)
node tools/bateria-duas-contas.js --url https://gps-truck-backend.onrender.com --criar

# com contas que ja existem (login de verdade)
node tools/bateria-duas-contas.js --url http://127.0.0.1:3000 \
  --celular-email a@b.com --pc-email c@d.com --senha 123456
```

Usa as **duas contas que estão rodando nos aparelhos** e o mesmo caminho do
app (token de sessão + socket):

1. as duas contas online e se vendo no radar
2. fotos de perfil diferentes (o que o motorista vê)
3. chat nos dois sentidos + histórico no servidor
4. chat privado só para o destino
5. reação por emoji
6. sinal de estrada criado no celular chega no PC
7. grupo (comboio) com as duas contas
8. convite de grupo
9. compartilhamento de ponto de encontro
10. segurança (token, identidade, payload hostil)
11. 450 requisições sem erro 5xx
12. app aberto nos dois aparelhos
13. **rota compartilhada no grupo chega e fica salva**
14. **acompanhar rota** (o seguidor recebe o estado; o dono é avisado)
15. **progresso ao vivo** (a parada muda para "chegou" e "entregue" em tempo real)

**Resultado: 15/15 (nota 10/10).**

---

## 3. Baterias dentro do app (Dart)

```bash
cd frontend-flutter
flutter test test/bateria_simulacao_real_test.dart   # 13 testes
flutter test test/bateria_ciclo_vida_test.dart        # 21 testes
flutter test                                          # 226 testes no total
```

- `bateria_simulacao_real_test.dart`: frota de 10 motoristas com GPS e rotas
  próprias (cada um entrega 3 paradas sem se misturar), empresa, rede de peers,
  sinais por proximidade, ocultação, expiração de marcadores, persistência,
  porta do Premium e carga de GPS com teleporte.
- `bateria_ciclo_vida_test.dart`: perfis de voz (Padrão/Waze/Uber/99) com frases
  resumidas, regra dos sons (sino só na chegada, sino de estação, som de saída),
  escolha de quais rotas compartilhadas ver (1 de 10, 9 de 10), progresso ao
  vivo e acompanhamento.

---

## 4. Observador da rede (prova independente)

```bash
node tools/observador-v2x.js --segundos 300
```

Conecta como um terceiro caminhão e **grava tudo que passa no fio**: posições,
chat, reações, rotas compartilhadas, alertas, convites. Serve de prova de que
o que apareceu na tela realmente viajou pela rede.

---

## 5. Como rodar o emulador (o "PC" da bateria)

```powershell
# o AVD precisa de particao menor (o disco nao tem espaco para 7 GB)
# config: disk.dataPartition.size = 2147483648
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd teste_apk `
  -no-boot-anim -gpu swiftshader_indirect -partition-size 2040

# os dois aparelhos precisam do mesmo ponto (o celular vai parar no RJ)
adb -s emulator-5554 emu geo fix -43.538143 -22.845021
```

O APK tem que ser **arm64 + x64** para rodar no emulador (x86_64) e no celular:

```powershell
flutter build apk --release --target-platform android-arm64,android-x64 `
  --dart-define-from-file=keys.json
```
