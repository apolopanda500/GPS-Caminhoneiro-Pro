-- GPS Caminhoneiro Pro - Banco de Dados Espacial Completo (PostGIS)
-- Execute no Supabase ou PostgreSQL com extensão PostGIS

-- 1. Ativar extensão obrigatória
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Tabela de motoristas / controle de acesso Premium
CREATE TABLE IF NOT EXISTS drivers (
    driver_id VARCHAR(50) PRIMARY KEY,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(64) NOT NULL,
    name VARCHAR(100),
    is_premium BOOLEAN DEFAULT FALSE,
    truck_height NUMERIC(4,2) DEFAULT 4.40,
    truck_width NUMERIC(4,2) DEFAULT 2.50,
    truck_length NUMERIC(5,2) DEFAULT 13.50,
    truck_weight NUMERIC(5,2) DEFAULT 45.00,
    axle_count INT DEFAULT 2,
    hazmat BOOLEAN DEFAULT FALSE,
    avatar_url TEXT DEFAULT 'https://placehold.co/150',
    truck_photo_url TEXT DEFAULT 'https://placehold.co/300x200',
    truck_model VARCHAR(50) DEFAULT 'Não Informado',
    cargo_type VARCHAR(100) DEFAULT 'Carga Geral',
    email_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2.1 Codigos de confirmacao de conta (e-mail)
CREATE TABLE IF NOT EXISTS verification_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(100) NOT NULL,
    code VARCHAR(6) NOT NULL,
    purpose VARCHAR(20) NOT NULL DEFAULT 'signup',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    consumed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_verification_codes_email
    ON verification_codes(email);

-- 2.2 Grupos (comboios) de motoristas e ajudantes
CREATE TABLE IF NOT EXISTS convoy_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(80) NOT NULL,
    owner_driver_id VARCHAR(50) REFERENCES drivers(driver_id) ON DELETE CASCADE,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS convoy_members (
    group_id UUID REFERENCES convoy_groups(id) ON DELETE CASCADE,
    driver_id VARCHAR(50) REFERENCES drivers(driver_id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'motorista',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, driver_id)
);

CREATE TABLE IF NOT EXISTS group_shared_routes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES convoy_groups(id) ON DELETE CASCADE,
    driver_id VARCHAR(50) REFERENCES drivers(driver_id) ON DELETE CASCADE,
    driver_name VARCHAR(100) NOT NULL DEFAULT '',
    payload JSONB NOT NULL,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_convoy_members_driver_id ON convoy_members(driver_id);
CREATE INDEX IF NOT EXISTS idx_group_routes_group_id ON group_shared_routes(group_id);

-- 3. Tabela de alertas de estrada criados por motoristas
CREATE TABLE IF NOT EXISTS road_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id VARCHAR(50) REFERENCES drivers(driver_id) ON DELETE SET NULL,
    alert_type VARCHAR(30) NOT NULL,
    message TEXT,
    max_height_allowed NUMERIC(4,2),
    max_weight_allowed NUMERIC(5,2),
    geom GEOMETRY(Point, 4326) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '12 hours')
);

-- 4. Tabela de mensagens do chat da rodovia (limpa automaticamente após 24h)
CREATE TABLE IF NOT EXISTS truck_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id VARCHAR(50) REFERENCES drivers(driver_id) ON DELETE CASCADE,
    driver_name VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    geom GEOMETRY(Point, 4326) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Índices espaciais para buscas rápidas de proximidade
CREATE INDEX IF NOT EXISTS idx_road_alerts_geom ON road_alerts USING gist(geom);
CREATE INDEX IF NOT EXISTS idx_road_alerts_type ON road_alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_truck_messages_geom ON truck_messages USING gist(geom);
CREATE INDEX IF NOT EXISTS idx_truck_messages_created_at ON truck_messages(created_at);

-- 6. Função para buscar alertas num raio de X metros do caminhão (uso em tempo real)
CREATE OR REPLACE FUNCTION verify_road_safety(
    p_lon NUMERIC,
    p_lat NUMERIC,
    p_radius_meters INT DEFAULT 2000
)
RETURNS TABLE (
    id UUID,
    driver_id VARCHAR(50),
    alert_type VARCHAR,
    message TEXT,
    max_height NUMERIC,
    max_weight NUMERIC,
    longitude NUMERIC,
    latitude NUMERIC,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ra.id,
        ra.driver_id,
        ra.alert_type,
        ra.message,
        ra.max_height_allowed::NUMERIC,
        ra.max_weight_allowed::NUMERIC,
        ST_X(ra.geom)::NUMERIC,
        ST_Y(ra.geom)::NUMERIC,
        ra.created_at
    FROM road_alerts ra
    WHERE ST_DWithin(
        ra.geom,
        ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326)::geography,
        p_radius_meters
    )
    AND (ra.expires_at IS NULL OR ra.expires_at > NOW());
END;
$$ LANGUAGE plpgsql;

-- 7. Tabela de Histórico de Viagens Concluídas
CREATE TABLE IF NOT EXISTS travel_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id VARCHAR(50) REFERENCES drivers(driver_id) ON DELETE CASCADE,
    origin_name TEXT NOT NULL,
    destination_name TEXT NOT NULL,
    distance_km NUMERIC(6,2) NOT NULL,
    travel_time_minutes INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. Tabela de Contatos e Amigos Caminhoneiros
CREATE TABLE IF NOT EXISTS driver_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id VARCHAR(50) REFERENCES drivers(driver_id) ON DELETE CASCADE,
    contact_driver_id VARCHAR(50) REFERENCES drivers(driver_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(driver_id, contact_driver_id)
);

-- 9. Índices para histórico e contatos
CREATE INDEX IF NOT EXISTS idx_travel_history_driver_id ON travel_history(driver_id);
CREATE INDEX IF NOT EXISTS idx_travel_history_created_at ON travel_history(created_at);
CREATE INDEX IF NOT EXISTS idx_driver_contacts_driver_id ON driver_contacts(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_contacts_contact_id ON driver_contacts(contact_driver_id);

-- 10. Tabela de Pagamentos (assinatura Premium via PIX)
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id VARCHAR(50) REFERENCES drivers(driver_id) ON DELETE CASCADE,
    gateway_id VARCHAR(100) UNIQUE NOT NULL,
    amount NUMERIC(10,2) NOT NULL DEFAULT 29.90,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_payments_driver_id ON payments(driver_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
