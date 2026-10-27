# 🏗️ Arquitetura do Sistema — GPS Caminhoneiro Pro

> Documentação técnica para trabalhos futuros, apresentações e manutenção.
> **Versão:** 1.0 — Data: 26/10/2026

---

## 1. Visão Geral

O **GPS Caminhoneiro Pro** é um app Android nativo (Flutter) para caminhoneiros com:
- Mapa renderizado **dentro do app** (sem abrir navegador)
- Rede veicular **V2X** (veículo-veículo em tempo real)
- Chat de estrada, reações por emoji, perfis com fotos
- Alertas de via em tempo real via WebSocket
- Modo offline (cache SQLite)
- Cadastro de dimensões do veículo (cubagem, peso, eixos, HAZMAT)
- Rota com paradas (Google Directions + Nominatim)
- GPS 24/7 em segundo plano
- Assinatura Premium via PIX

**Backend:** Node.js + TypeScript + Socket.io + PostgreSQL/PostGIS (Render + Supabase).

---

## 2. Stack Tecnológica

### Frontend (Flutter / Dart)

| Componente | Tecnologia | Versão | Uso |
|------------|-----------|--------|-----|
| Framework | Flutter | SDK 3.x | UI nativa Android |
| Estado | provider + ChangeNotifier | ^6.1.1 | Providers centralizados |
| Mapa | maplibre_gl | ^0.27.1 | Mapa nativo com câmera 3D |
| GPS | geolocator | ^10.1.1 | GPS nativo Android |
| Permissões | permission_handler | ^11.0.0 | GPS, notificação, bateria |
| HTTP | http | ^1.1.0 | Chamadas REST |
| Socket | socket_io_client | ^2.0.3+1 | WebSocket V2X |
| Banco local | sqflite | ^2.3.0 | Cache offline SQLite |
| Preferências | shared_preferences | 2.3.5 | Configurações persistidas |
| Áudio | just_audio | ^0.10.6 | Músicas, sinos, rádio |
| TTS (voz) | flutter_tts | ^4.2.5 | Navegação por voz |
| Arquivos | file_picker | ^13.1.0 | Importar sons |
| Conectividade | connectivity_plus | ^7.3.2 | Status de rede |
| Geometria | latlong2 | ^0.9.1 | Distância/bearing |

### Backend (Node.js / TypeScript)

| Componente | Tecnologia | Uso |
|------------|-----------|-----|
| Runtime | Node.js | Servidor 24/7 |
| WebSocket | Socket.io | Rede V2X, chat, alertas, posição |
| Banco | PostgreSQL + PostGIS | Dados espaciais |
| Driver | pg | Conexão Postgres |
| Auth | JWT (HMAC-SHA256) | Tokens de sessão (30 dias) |
| Segurança | Middleware `requireAuth` | Protege rotas críticas |
| Email | nodemailer + Brevo | Códigos de verificação |
| Pagamento PIX | Mercado Pago / Stripe | Premium |
| Hospedagem | Render | Deploy gratuito 24/7 |
| Banco nuvem | Supabase (PostGIS 3.3) | Produção |
