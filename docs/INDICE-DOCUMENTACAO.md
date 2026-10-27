# 📚 Índice da Documentação — GPS Caminhoneiro Pro

> Toda a documentação do projeto está nesta pasta `docs/`. Este índice serve como ponto de entrada para trabalhos futuros, apresentações e manutenção.

---

## 📋 Arquivos de Documentação

| Arquivo | Conteúdo |
|---------|----------|
| `ARQUITETURA-VISAO.md` | Visão geral, stack tecnológica, frontend e backend |
| `ARQUITETURA-ESTRUTURA.md` | Estrutura de pastas e arquivos detalhada |
| `ARQUITETURA-PROVIDERS.md` | Providers (gerenciamento de estado) e responsabilidades |
| `ARQUITETURA-MODELOS.md` | Modelos de dados (Driver, Alert, Marker, Trip, Truck, Route, SharedRoute) |
| `ARQUITETURA-REDE.md` | Serviços de rede (Socket.io V2X, REST API, autenticação) |
| `ARQUITETURA-AUDIO.md` | Áudio e voz (perfis, slots de som, TTS, regras de áudio) |
| `ARQUITETURA-MAPA.md` | Mapa e rota (camadas, câmera 3D, rota com paradas, camadas ambientais) |
| `ARQUITETURA-PREMIUM.md` | Política Premium e PIX (recursos, preço, geração BR Code) |
| `TESTES.md` | Todos os testes Flutter e backend existentes |
| `BATERIAS-SIMULACAO.md` | Baterias de simulação Node.js (cenários, uso, resultados) |
| `DEPLOY-RESUMO.md` | Guia de deploy (Supabase, Render, Flutter, variáveis de ambiente) |
| `PENDENCIAS.md` | Pendências conhecidas (críticas e opcionais) + SHA-1 certificados |
| `COMANDOS.md` | Comandos essenciais (Flutter, backend, baterias, emulador, git) |
| `REGRAS.md` | Regras do projeto (colaboração, código, uso real) |
| `ESTADO-ATUAL.md` | Estado atual (métricas, recursos implementados, pendências, credenciais) |

---

## 🎯 Como Usar Esta Documentação

### Para apresentações do projeto
- Ler `ARQUITETURA-VISAO.md` + `ESTADO-ATUAL.md` + `RESUMO-FINAL.md` (raiz)

### Para novo desenvolvedor
- Ler `ARQUITETURA-ESTRUTURA.md` + `ARQUITETURA-PROVIDERS.md` + `COMANDOS.md`

### Para deploy
- Ler `DEPLOY-RESUMO.md` + `DEPLOY.md` (raiz) + `GUIA-ANDROID.md` (raiz)

### Para correção de falhas
- Ler `PENDENCIAS.md` + `TESTES.md` + `BATERIAS-SIMULACAO.md`

### Para entender a rede V2X
- Ler `ARQUITETURA-REDE.md` + `ARQUITETURA-AUDIO.md`

---

## 📂 Documentação na Raiz do Projeto

| Arquivo | Conteúdo |
|---------|----------|
| `README.md` | Visão geral do projeto, estrutura, recursos, comandos |
| `RESUMO-FINAL.md` | Resumo executivo (100% completo) |
| `DEPLOY.md` | Guia de deploy passo a passo |
| `GUIA-ANDROID.md` | Como rodar no Android |
| `GUIA-MAPA.md` | Guia do mapa (MapLibre GL) |
| `GUIA-PLAY-STORE.md` | Publicar na Google Play Store |
| `AGENTS.md` | Guia para agentes de IA |
| `COORDENACAO-AGENTES.md` | Coordenação multiagente (log append-only) |

---

## 🏁 Estado Atual (26/10/2026)

- **App:** 100% implementado, pronto para uso real
- **Testes:** Flutter + backend todos verdes
- **Baterias:** 10/10 e 15/15 contra produção (nota 10.0)
- **Pendências críticas:** 4 itens (ver `PENDENCIAS.md`)
- **Aguardando:** Celular físico conectado via USB para teste final

---

> **Este índice deve ser atualizado sempre que novos arquivos de documentação forem criados.**
