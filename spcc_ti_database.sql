-- SPCC - Base de datos TI
-- Motor sugerido: PostgreSQL 14+

BEGIN;

CREATE SCHEMA IF NOT EXISTS spcc_ti;
SET search_path TO spcc_ti;

-- ===== Catálogos =====

CREATE TABLE sedes (
    sede_id          BIGSERIAL PRIMARY KEY,
    nombre           VARCHAR(120) NOT NULL UNIQUE,
    direccion        VARCHAR(255),
    activa           BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE areas (
    area_id          BIGSERIAL PRIMARY KEY,
    sede_id          BIGINT NOT NULL REFERENCES sedes(sede_id),
    nombre           VARCHAR(120) NOT NULL,
    descripcion      TEXT,
    UNIQUE (sede_id, nombre)
);

CREATE TABLE categorias_activo (
    categoria_id     BIGSERIAL PRIMARY KEY,
    nombre           VARCHAR(80) NOT NULL UNIQUE,
    requiere_serie   BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE tipos_camara (
    tipo_camara_id   BIGSERIAL PRIMARY KEY,
    nombre           VARCHAR(50) NOT NULL UNIQUE,
    descripcion      TEXT
);

CREATE TABLE tipos_movimiento_stock (
    tipo_movimiento_id SMALLSERIAL PRIMARY KEY,
    codigo              VARCHAR(20) NOT NULL UNIQUE,
    descripcion         VARCHAR(120) NOT NULL
);

-- ===== Personas y Accesos =====

CREATE TABLE personas (
    persona_id        BIGSERIAL PRIMARY KEY,
    codigo_empleado   VARCHAR(30) UNIQUE,
    nombres           VARCHAR(80) NOT NULL,
    apellidos         VARCHAR(80) NOT NULL,
    dni               VARCHAR(20),
    email             VARCHAR(120),
    telefono          VARCHAR(30),
    activo            BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE perfiles_acceso (
    perfil_id         BIGSERIAL PRIMARY KEY,
    nombre            VARCHAR(80) NOT NULL UNIQUE,
    nivel             SMALLINT NOT NULL CHECK (nivel BETWEEN 1 AND 10),
    descripcion       TEXT
);

CREATE TABLE persona_perfil_acceso (
    persona_id        BIGINT NOT NULL REFERENCES personas(persona_id),
    perfil_id         BIGINT NOT NULL REFERENCES perfiles_acceso(perfil_id),
    vigente_desde     DATE NOT NULL,
    vigente_hasta     DATE,
    PRIMARY KEY (persona_id, perfil_id, vigente_desde)
);

CREATE TABLE puntos_acceso (
    punto_acceso_id   BIGSERIAL PRIMARY KEY,
    sede_id           BIGINT NOT NULL REFERENCES sedes(sede_id),
    area_id           BIGINT REFERENCES areas(area_id),
    nombre            VARCHAR(120) NOT NULL,
    tipo              VARCHAR(50) NOT NULL, -- puerta, torniquete, sala de servidores, etc.
    activo            BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (sede_id, nombre)
);

CREATE TABLE eventos_acceso (
    evento_id         BIGSERIAL PRIMARY KEY,
    persona_id        BIGINT REFERENCES personas(persona_id),
    punto_acceso_id   BIGINT NOT NULL REFERENCES puntos_acceso(punto_acceso_id),
    fecha_hora        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resultado         VARCHAR(20) NOT NULL CHECK (resultado IN ('PERMITIDO','DENEGADO')),
    metodo            VARCHAR(30) NOT NULL, -- tarjeta, huella, PIN
    observacion       TEXT
);

-- ===== Inventario de Activos TI =====

CREATE TABLE activos_ti (
    activo_id           BIGSERIAL PRIMARY KEY,
    categoria_id        BIGINT NOT NULL REFERENCES categorias_activo(categoria_id),
    sede_id             BIGINT NOT NULL REFERENCES sedes(sede_id),
    area_id             BIGINT REFERENCES areas(area_id),
    codigo_interno      VARCHAR(40) NOT NULL UNIQUE,
    marca               VARCHAR(80),
    modelo              VARCHAR(80),
    numero_serie        VARCHAR(120),
    estado              VARCHAR(25) NOT NULL CHECK (estado IN ('OPERATIVO','MANTENIMIENTO','BAJA','RESERVA')),
    fecha_compra        DATE,
    garantia_hasta      DATE,
    observaciones       TEXT,
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE asignaciones_activo (
    asignacion_id       BIGSERIAL PRIMARY KEY,
    activo_id           BIGINT NOT NULL REFERENCES activos_ti(activo_id),
    persona_id          BIGINT REFERENCES personas(persona_id),
    area_id             BIGINT REFERENCES areas(area_id),
    fecha_asignacion    DATE NOT NULL,
    fecha_devolucion    DATE,
    motivo              VARCHAR(120),
    CHECK (persona_id IS NOT NULL OR area_id IS NOT NULL)
);

-- ===== Seguridad física y cámaras =====

CREATE TABLE camaras (
    camara_id             BIGSERIAL PRIMARY KEY,
    activo_id             BIGINT UNIQUE REFERENCES activos_ti(activo_id),
    tipo_camara_id        BIGINT NOT NULL REFERENCES tipos_camara(tipo_camara_id),
    sede_id               BIGINT NOT NULL REFERENCES sedes(sede_id),
    area_id               BIGINT REFERENCES areas(area_id),
    nombre                VARCHAR(120) NOT NULL,
    ubicacion_detallada   TEXT,
    ip                    INET,
    canal_dvr_nvr         VARCHAR(30),
    estado                VARCHAR(20) NOT NULL CHECK (estado IN ('ACTIVA','INACTIVA','MANTENIMIENTO')),
    UNIQUE (sede_id, nombre)
);

CREATE TABLE grabaciones_camara (
    grabacion_id          BIGSERIAL PRIMARY KEY,
    camara_id             BIGINT NOT NULL REFERENCES camaras(camara_id),
    inicio                TIMESTAMPTZ NOT NULL,
    fin                   TIMESTAMPTZ NOT NULL,
    ruta_almacenamiento   TEXT NOT NULL,
    hash_integridad       VARCHAR(128),
    CHECK (fin > inicio)
);

-- ===== Stock de productos TI =====

CREATE TABLE productos_ti (
    producto_id           BIGSERIAL PRIMARY KEY,
    sku                   VARCHAR(50) NOT NULL UNIQUE,
    nombre                VARCHAR(120) NOT NULL,
    categoria             VARCHAR(80) NOT NULL,
    unidad_medida         VARCHAR(20) NOT NULL DEFAULT 'UNIDAD',
    stock_minimo          NUMERIC(12,2) NOT NULL DEFAULT 0,
    stock_actual          NUMERIC(12,2) NOT NULL DEFAULT 0,
    costo_unitario        NUMERIC(12,2),
    activo                BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE movimientos_stock (
    movimiento_id         BIGSERIAL PRIMARY KEY,
    producto_id           BIGINT NOT NULL REFERENCES productos_ti(producto_id),
    tipo_movimiento_id    SMALLINT NOT NULL REFERENCES tipos_movimiento_stock(tipo_movimiento_id),
    cantidad              NUMERIC(12,2) NOT NULL CHECK (cantidad > 0),
    fecha_hora            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    referencia            VARCHAR(120),
    observacion           TEXT
);

-- ===== Índices =====

CREATE INDEX idx_eventos_acceso_fecha ON eventos_acceso (fecha_hora DESC);
CREATE INDEX idx_eventos_acceso_punto ON eventos_acceso (punto_acceso_id, fecha_hora DESC);
CREATE INDEX idx_activos_categoria_estado ON activos_ti (categoria_id, estado);
CREATE INDEX idx_camaras_estado ON camaras (estado);
CREATE INDEX idx_movimientos_stock_producto_fecha ON movimientos_stock (producto_id, fecha_hora DESC);

-- ===== Datos base sugeridos =====

INSERT INTO categorias_activo (nombre, requiere_serie) VALUES
('Laptop', TRUE),
('Mini PC HP', TRUE),
('Impresora', TRUE),
('Fotocopiadora', TRUE),
('Teclado', FALSE),
('Mouse', FALSE),
('Proyector', TRUE),
('Equipo de sonido', TRUE),
('Storage interno', TRUE),
('Cámara externa', TRUE);

INSERT INTO tipos_camara (nombre, descripcion) VALUES
('Digital IP', 'Cámara de red con dirección IP'),
('Analógica con cable', 'Cámara analógica conectada por cable coaxial');

INSERT INTO tipos_movimiento_stock (codigo, descripcion) VALUES
('ENTRADA', 'Ingreso al almacén'),
('SALIDA', 'Salida por consumo o asignación'),
('AJUSTE_POS', 'Ajuste positivo por regularización'),
('AJUSTE_NEG', 'Ajuste negativo por regularización');

COMMIT;
