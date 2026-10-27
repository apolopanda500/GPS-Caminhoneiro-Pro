# 🌐 Serviços de Rede

## Socket.io (V2X - Tempo Real)

| Evento | Direção | Descrição |
|--------|---------|-----------|
| `register_driver` | → | Registra motorista na rede |
| `join_truck_network` | → | Entra na rede de caminhões |
| `update_position` | → | Envia posição GPS em tempo real |
| `trucks_radar_update` | ← | Recebe posições dos peers |
| `receive_chat_message` | ← | Chat de estrada |
| `receive_alert_realtime` | ← | Alertas em tempo real |
| `send_truck_reaction` / `receive_truck_reaction` | ↔ | Reações por emoji |
| `share_route` / `follow_route` / `unfollow_route` | ↔ | Compartilhamento de rota |
| `route_progress` | ↔ | Progresso de paradas (chegou/entregue) |
| `send_group_invite` / `receive_group_invite` | ↔ | Convites de grupo |
| `road_validation_alerts` | ← | Alertas de validação de via |

## REST API

| Endpoint | Método | Descrição | Protegido |
|----------|--------|-----------|-----------|
| `/api/auth/register` | POST | Cadastro com verificação de email | Não |
| `/api/auth/login` | POST | Login + token de sessão | Não |
| `/api/auth/verify` | POST | Verifica código de email | Não |
| `/api/auth/profile` | POST | Atualiza perfil | Sim (token) |
| `/api/auth/photo` | POST | Atualiza foto | Sim (token) |
| `/api/alerts` | POST | Cria alerta de via | Sim (token) |
| `/api/alerts/messages` | POST | Mensagem de chat | Sim (token) |
| `/api/groups` | GET/POST | Lista/cria grupos | Sim (token) |
| `/api/groups/:id/join` | POST | Entra no grupo | Sim (token) |
| `/api/groups/:id/leave` | POST | Sai do grupo | Sim (token) |
| `/api/groups/:id/members` | GET | Membros do grupo | Sim (token) |
| `/api/groups/:id/routes` | GET | Rotas compartilhadas | Sim (token) |
| `/api/payment/pix` | POST | Gera BR Code PIX | Sim (token) |
| `/status` | GET | Status do servidor + banco | Não |

## Autenticação
- Tokens JWT com HMAC-SHA256, validade 30 dias
- Middleware `requireAuth` protege rotas críticas
- `driverId` vem do token, nunca do corpo/query da requisição
