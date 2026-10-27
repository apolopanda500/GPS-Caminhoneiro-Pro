# 🔋 Baterias de Simulação (Node.js)

## tools/bateria-simulacao-real.js
Simula N motoristas REAIS contra o backend de verdade (Render ou local).

**Cenários (10):**
1. Serviço no ar — `/status` com banco conectado
2. Cadastro e login — 10 contas com verificação de email
3. Perfil e fotos — nome, modelo, carga, foto do motorista e caminhão
4. Rede V2X — todos veem todos se movendo (radar em tempo real)
5. Alertas — sinal criado aparece para quem está perto (socket + REST)
6. Chat e reações — chat público, privado, reação por emoji, persistência
7. Grupos — grupo privado, rota compartilhada visível só para membros, ajudante bloqueado
8. Premium PIX — BR Code + CRC16 válidos e ativação do Premium
9. Segurança — token inválido, identidade pelo token, payload hostil
10. Robustez — desconexão/reconexão, carga sem 5xx, assistente respondendo

**Uso:**
```bash
node tools/bateria-simulacao-real.js
node tools/bateria-simulacao-real.js --usuarios 10 --passos 40
node tools/bateria-simulacao-real.js --url https://servidor.onrender.com
node tools/bateria-simulacao-real.js --local          # backend local
node tools/bateria-simulacao-real.js --manter         # não limpa o banco
```

## tools/bateria-duas-contas.js
Usa duas contas reais (celular + PC/emulador) com o mesmo caminho que o app.

**15 Cenários:**
1. Duas contas online e se vendo no radar
2. Fotos de perfil diferentes
3. Chat nos dois sentidos + histórico no servidor
4. Chat privado só para o destino
5. Reação por emoji
6. Sinal de estrada criado no celular chega no PC
7. Grupo (comboio) com as duas contas
8. Convite de grupo
9. Compartilhamento de ponto de encontro
10. Segurança (token, identidade, payload hostil)
11. 450 requisições sem erro 5xx
12. App aberto nos dois aparelhos
13. Rota compartilhada no grupo chega e fica salva
14. Acompanhar rota (seguidor recebe estado; dono é avisado)
15. Progresso ao vivo (parada muda para "chegou" e "entregue" em tempo real)

**Uso:**
```bash
node tools/bateria-duas-contas.js --criar
node tools/bateria-duas-contas.js --url http://127.0.0.1:3000 --celular-email a@b.com --pc-email c@d.com --senha 123456
```

## tools/observador-v2x.js
Observador independente que grava tudo que passa no socket (posições, chat, reações, rotas, alertas, convites). Serve de prova de que o que apareceu na tela realmente viajou pela rede.

**Uso:**
```bash
node tools/observador-v2x.js --segundos 300
```

## tools/rodar-baterias.ps1
Runner único de todas as baterias.
