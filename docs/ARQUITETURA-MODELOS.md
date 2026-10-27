# 📊 Modelos de Dados

### DriverModel
- driverId, email, name, isPremium
- truckHeight, truckWeight, axleCount, hazmat
- avatarUrl, truckPhotoUrl, truckModel, cargoType, truckIcon
- role ('motorista' | 'ajudante'), helpType
- companyName, companyLat, companyLon

### AlertModel
- id, driverId, type (texto_livre, radar, ponte_baixa, policia, balanca, perigo, pedagio, acidente, obstrucao, zmrc, descanso, estacionamento, combustivel, restaurante, borracharia, ponto_apoio, serra, curva, fiscalizacao)
- message, maxHeight, maxWeight, latitude, longitude, createdAt

### MapMarkerModel (sinal/emoji no mapa)
- id, emoji, type, label, latitude, longitude, driverId, createdAt
- TTL: 12 horas (expiração automática)

### TripModel (histórico de viagens)
- id, startedAt, endedAt, distanceMeters, averageSpeedKmh, maxSpeedKmh
- startLat, startLon, endLat, endLon

### TruckConfig
- driverId, height, width, length, weight, axleCount, hazmat

### RouteStopEntry
- label, point (LatLng), neighborhood, customer, note, radiusMeters, orderLabel

### SharedRoute (rota compartilhada de grupo)
- shareId, groupId, ownerDriverId, ownerName, nome, stops, progress (map<int, status>)
- Status: pendente, chegou, entregue
