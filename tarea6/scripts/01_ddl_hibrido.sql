/* ============================================================================
   Red Social Estudiantil Pascualina - Tarea 6: Arquitectura híbrida (DDL)
   SGBD ........ PostgreSQL 16
   Curso ....... Bases de Datos I - G100 (SD1006) - Grupo 5
   Autor ....... Juan Camilo Villegas Ocampo

   QUÉ HACE ESTE SCRIPT
   Extiende el esquema relacional red_social (Tarea 5, 25 tablas) con elementos
   NO relacionales dentro del mismo motor, usando JSONB:
     - dispositivo_iot / tipo_dispositivo : catálogo RELACIONAL de sensores del campus.
     - lectura_iot       : flujo IoT (big data) PARTICIONADO por mes, payload JSONB.
     - log_actividad     : logs de actividad de usuarios, detalle JSONB (semiestructurado).
     - contenido_multimedia : archivos de publicaciones, metadatos técnicos JSONB.
     - alerta_iot        : alertas generadas por trigger a partir del flujo IoT.
     - perfil.preferencias : columna JSONB nueva (ajustes flexibles por usuario).

   PRERREQUISITO: haber cargado el esquema base (tarea5/scripts/final/01 a 03).
   Cada objeto se crea con restricciones nombradas (pk_, fk_, ck_, idx_).
   ============================================================================ */

SET search_path TO red_social;

-- Re-ejecutable: se eliminan primero los objetos de esta tarea (no toca las 25 tablas base)
DROP MATERIALIZED VIEW IF EXISTS mv_ocupacion_hora;
DROP TABLE IF EXISTS alerta_iot, lectura_iot, dispositivo_iot, tipo_dispositivo,
                     log_actividad, contenido_multimedia CASCADE;
DROP FUNCTION IF EXISTS fn_procesar_lectura_iot();
ALTER TABLE perfil DROP COLUMN IF EXISTS preferencias;

/* ----------------------------------------------------------------------------
   1. perfil.preferencias (JSONB)
   Ajustes que cambian con frecuencia (tema, idioma, notificaciones). En un modelo
   100% relacional exigirían una columna nueva por cada ajuste (ALTER TABLE);
   con JSONB se agregan claves sin migrar el esquema.
   ---------------------------------------------------------------------------- */
ALTER TABLE perfil
    ADD COLUMN preferencias JSONB DEFAULT '{}'::jsonb NOT NULL,
    ADD CONSTRAINT ck_perfil_preferencias_json CHECK (jsonb_typeof(preferencias) = 'object');

CREATE INDEX idx_perfil_preferencias_gin ON perfil USING GIN (preferencias jsonb_path_ops);

/* ----------------------------------------------------------------------------
   2. tipo_dispositivo (relacional)
   Catálogo de tipos de sensor. esquema_lectura documenta, en JSONB, qué claves
   trae el payload de ese tipo (contrato de datos para quien inserta lecturas).
   ---------------------------------------------------------------------------- */
CREATE TABLE tipo_dispositivo (
    id_tipo           INTEGER GENERATED ALWAYS AS IDENTITY NOT NULL,
    nombre_tipo       VARCHAR(40) NOT NULL,
    descripcion       VARCHAR(255) NULL,
    esquema_lectura   JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT pk_tipo_dispositivo PRIMARY KEY (id_tipo),
    CONSTRAINT uq_tipo_dispositivo_nombre UNIQUE (nombre_tipo),
    CONSTRAINT ck_tipo_dispositivo_esquema CHECK (jsonb_typeof(esquema_lectura) = 'object')
);

/* ----------------------------------------------------------------------------
   3. dispositivo_iot (relacional + configuración JSONB)
   Cada sensor está instalado en un espacio del campus (FK a espacio).
   ---------------------------------------------------------------------------- */
CREATE TABLE dispositivo_iot (
    id_dispositivo     INTEGER GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_tipo            INTEGER NOT NULL,
    id_espacio         INTEGER NOT NULL,
    codigo_serie       VARCHAR(30) NOT NULL,
    estado             VARCHAR(15) DEFAULT 'ACTIVO' NOT NULL,
    fecha_instalacion  DATE DEFAULT CURRENT_DATE NOT NULL,
    configuracion      JSONB DEFAULT '{}'::jsonb NOT NULL,  -- umbrales, intervalo de muestreo, firmware
    CONSTRAINT pk_dispositivo_iot PRIMARY KEY (id_dispositivo),
    CONSTRAINT uq_dispositivo_iot_serie UNIQUE (codigo_serie),
    CONSTRAINT ck_dispositivo_iot_estado CHECK (estado IN ('ACTIVO', 'INACTIVO', 'MANTENIMIENTO')),
    CONSTRAINT ck_dispositivo_iot_config CHECK (jsonb_typeof(configuracion) = 'object'),
    CONSTRAINT fk_dispositivo_iot_tipo FOREIGN KEY (id_tipo)
        REFERENCES tipo_dispositivo (id_tipo) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_dispositivo_iot_espacio FOREIGN KEY (id_espacio)
        REFERENCES espacio (id_espacio) ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX idx_dispositivo_iot_tipo    ON dispositivo_iot (id_tipo);
CREATE INDEX idx_dispositivo_iot_espacio ON dispositivo_iot (id_espacio);

/* ----------------------------------------------------------------------------
   4. lectura_iot  (BIG DATA: flujo continuo de sensores)
   Decisiones de diseño para volumen alto:
   - PARTICIONADO por rango de fecha (un mes por partición): las consultas con
     filtro de fecha leen solo las particiones necesarias (partition pruning) y
     las particiones antiguas se pueden archivar o borrar (DROP) sin VACUUM.
   - payload JSONB: cada tipo de sensor envía claves distintas sin cambiar la tabla.
   - ocupacion: columna GENERADA extraída del JSON; la clave más consultada se
     "promueve" a columna relacional con tipo e índice propios.
   - Índices: BRIN en fecha (diminuto, ideal para datos que llegan en orden),
     B-tree (dispositivo, fecha) para series por sensor y GIN (jsonb_path_ops)
     para búsquedas por contenido con @>.
   ---------------------------------------------------------------------------- */
CREATE TABLE lectura_iot (
    id_lectura      BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_dispositivo  INTEGER NOT NULL,
    fecha_lectura   TIMESTAMP NOT NULL,
    payload         JSONB NOT NULL,
    ocupacion       INTEGER GENERATED ALWAYS AS ((payload ->> 'personas')::integer) STORED,
    CONSTRAINT pk_lectura_iot PRIMARY KEY (id_lectura, fecha_lectura),
    CONSTRAINT ck_lectura_iot_payload CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT fk_lectura_iot_dispositivo FOREIGN KEY (id_dispositivo)
        REFERENCES dispositivo_iot (id_dispositivo) ON DELETE CASCADE ON UPDATE CASCADE
) PARTITION BY RANGE (fecha_lectura);

CREATE TABLE lectura_iot_2026_09 PARTITION OF lectura_iot FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE lectura_iot_2026_10 PARTITION OF lectura_iot FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE lectura_iot_2026_11 PARTITION OF lectura_iot FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE lectura_iot_2026_12 PARTITION OF lectura_iot FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE lectura_iot_otras   PARTITION OF lectura_iot DEFAULT;  -- red de seguridad para fechas fuera de rango

CREATE INDEX idx_lectura_iot_fecha_brin ON lectura_iot USING BRIN (fecha_lectura);
CREATE INDEX idx_lectura_iot_disp_fecha ON lectura_iot (id_dispositivo, fecha_lectura);
CREATE INDEX idx_lectura_iot_payload_gin ON lectura_iot USING GIN (payload jsonb_path_ops);
CREATE INDEX idx_lectura_iot_ocupacion   ON lectura_iot (ocupacion) WHERE ocupacion IS NOT NULL;

/* ----------------------------------------------------------------------------
   5. alerta_iot (relacional, alimentada por trigger)
   ---------------------------------------------------------------------------- */
CREATE TABLE alerta_iot (
    id_alerta       BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_dispositivo  INTEGER NOT NULL,
    fecha_alerta    TIMESTAMP NOT NULL,
    tipo_alerta     VARCHAR(20) NOT NULL,
    severidad       VARCHAR(10) NOT NULL,
    detalle         JSONB NOT NULL,
    CONSTRAINT pk_alerta_iot PRIMARY KEY (id_alerta),
    CONSTRAINT ck_alerta_iot_tipo CHECK (tipo_alerta IN ('CO2_ALTO', 'TEMPERATURA_ALTA', 'AFORO_EXCEDIDO')),
    CONSTRAINT ck_alerta_iot_severidad CHECK (severidad IN ('MEDIA', 'ALTA')),
    CONSTRAINT fk_alerta_iot_dispositivo FOREIGN KEY (id_dispositivo)
        REFERENCES dispositivo_iot (id_dispositivo) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_alerta_iot_dispositivo ON alerta_iot (id_dispositivo);
CREATE INDEX idx_alerta_iot_fecha       ON alerta_iot (fecha_alerta);

/* ----------------------------------------------------------------------------
   6. Trigger: cada lectura nueva (a) refresca espacio.datos_iot (última lectura,
   que ya existía en la Tarea 5) y (b) genera alertas si supera los umbrales
   definidos en dispositivo_iot.configuracion. Une la parte IoT con la relacional.
   ---------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION fn_procesar_lectura_iot() RETURNS trigger AS $$
DECLARE
    v_espacio   INTEGER;
    v_capacidad INTEGER;
    v_cfg       JSONB;
    v_co2_max   NUMERIC;
    v_temp_max  NUMERIC;
BEGIN
    SELECT d.id_espacio, e.capacidad, d.configuracion
      INTO v_espacio, v_capacidad, v_cfg
      FROM dispositivo_iot d JOIN espacio e ON e.id_espacio = d.id_espacio
     WHERE d.id_dispositivo = NEW.id_dispositivo;

    -- (a) última lectura conocida del espacio (solo si la lectura es la más reciente)
    UPDATE espacio
       SET datos_iot = COALESCE(datos_iot, '{}'::jsonb) || NEW.payload
                       || jsonb_build_object('ultima_lectura', NEW.fecha_lectura)
     WHERE id_espacio = v_espacio
       AND COALESCE((datos_iot ->> 'ultima_lectura')::timestamp, '-infinity') <= NEW.fecha_lectura;

    -- (b) alertas por umbral (valores por defecto si el sensor no los configura)
    v_co2_max  := COALESCE((v_cfg -> 'umbrales' ->> 'co2_ppm')::numeric, 1000);
    v_temp_max := COALESCE((v_cfg -> 'umbrales' ->> 'temperatura_c')::numeric, 30);

    IF (NEW.payload ->> 'co2_ppm')::numeric > v_co2_max THEN
        INSERT INTO alerta_iot (id_dispositivo, fecha_alerta, tipo_alerta, severidad, detalle)
        VALUES (NEW.id_dispositivo, NEW.fecha_lectura, 'CO2_ALTO',
                CASE WHEN (NEW.payload ->> 'co2_ppm')::numeric > v_co2_max * 1.5 THEN 'ALTA' ELSE 'MEDIA' END,
                jsonb_build_object('valor', NEW.payload -> 'co2_ppm', 'umbral', v_co2_max));
    END IF;
    IF (NEW.payload ->> 'temperatura_c')::numeric > v_temp_max THEN
        INSERT INTO alerta_iot (id_dispositivo, fecha_alerta, tipo_alerta, severidad, detalle)
        VALUES (NEW.id_dispositivo, NEW.fecha_lectura, 'TEMPERATURA_ALTA', 'MEDIA',
                jsonb_build_object('valor', NEW.payload -> 'temperatura_c', 'umbral', v_temp_max));
    END IF;
    IF NEW.ocupacion > v_capacidad THEN
        INSERT INTO alerta_iot (id_dispositivo, fecha_alerta, tipo_alerta, severidad, detalle)
        VALUES (NEW.id_dispositivo, NEW.fecha_lectura, 'AFORO_EXCEDIDO', 'ALTA',
                jsonb_build_object('personas', NEW.ocupacion, 'capacidad', v_capacidad));
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_lectura_iot_procesar
    AFTER INSERT ON lectura_iot
    FOR EACH ROW EXECUTE FUNCTION fn_procesar_lectura_iot();

/* ----------------------------------------------------------------------------
   7. log_actividad (semiestructurado)
   Un registro por acción del usuario en la plataforma. detalle cambia según
   tipo_evento (login, vista_publicacion, busqueda, descarga_recurso…), por eso JSONB.
   id_estudiante admite NULL (visitas anónimas) y se conserva el log si el
   estudiante se elimina (ON DELETE SET NULL).
   ---------------------------------------------------------------------------- */
CREATE TABLE log_actividad (
    id_log          BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_estudiante   INTEGER NULL,
    fecha_evento    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_evento     VARCHAR(30) NOT NULL,
    detalle         JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT pk_log_actividad PRIMARY KEY (id_log),
    CONSTRAINT ck_log_actividad_detalle CHECK (jsonb_typeof(detalle) = 'object'),
    CONSTRAINT fk_log_actividad_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_log_actividad_estudiante ON log_actividad (id_estudiante);
CREATE INDEX idx_log_actividad_fecha_brin ON log_actividad USING BRIN (fecha_evento);
CREATE INDEX idx_log_actividad_tipo       ON log_actividad (tipo_evento);
CREATE INDEX idx_log_actividad_detalle_gin ON log_actividad USING GIN (detalle jsonb_path_ops);

/* ----------------------------------------------------------------------------
   8. contenido_multimedia (semiestructurado)
   Un archivo adjunto a una publicación. metadatos varía por tipo (resolución e
   idioma de subtítulos para video; ancho/alto para imagen; duración para audio).
   ---------------------------------------------------------------------------- */
CREATE TABLE contenido_multimedia (
    id_contenido    INTEGER GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_publicacion  INTEGER NOT NULL,
    tipo_contenido  VARCHAR(10) NOT NULL,
    url             VARCHAR(255) NOT NULL,
    tamano_kb       INTEGER NOT NULL,
    metadatos       JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT pk_contenido_multimedia PRIMARY KEY (id_contenido),
    CONSTRAINT uq_contenido_multimedia_url UNIQUE (url),
    CONSTRAINT ck_contenido_multimedia_tipo CHECK (tipo_contenido IN ('IMAGEN', 'VIDEO', 'AUDIO', 'DOCUMENTO')),
    CONSTRAINT ck_contenido_multimedia_tamano CHECK (tamano_kb > 0),
    CONSTRAINT ck_contenido_multimedia_meta CHECK (jsonb_typeof(metadatos) = 'object'),
    CONSTRAINT fk_contenido_multimedia_publicacion FOREIGN KEY (id_publicacion)
        REFERENCES publicacion (id_publicacion) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX idx_contenido_multimedia_pub ON contenido_multimedia (id_publicacion);
CREATE INDEX idx_contenido_multimedia_meta_gin ON contenido_multimedia USING GIN (metadatos);

/* ----------------------------------------------------------------------------
   9. Vista materializada: agregación por espacio y hora (pre-cálculo para
   dashboards; evita recorrer millones de lecturas en cada consulta).
   Se refresca con: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ocupacion_hora;
   ---------------------------------------------------------------------------- */
CREATE MATERIALIZED VIEW mv_ocupacion_hora AS
SELECT d.id_espacio,
       date_trunc('hour', l.fecha_lectura)            AS hora,
       COUNT(*)                                       AS lecturas,
       ROUND(AVG(l.ocupacion), 1)                     AS ocupacion_prom,
       MAX(l.ocupacion)                               AS ocupacion_max,
       ROUND(AVG((l.payload ->> 'co2_ppm')::numeric), 0)       AS co2_prom,
       ROUND(AVG((l.payload ->> 'temperatura_c')::numeric), 1) AS temp_prom
  FROM lectura_iot l
  JOIN dispositivo_iot d ON d.id_dispositivo = l.id_dispositivo
 WHERE d.id_tipo IN (1, 2)             -- solo sensores ambientales y de ocupación
 GROUP BY d.id_espacio, date_trunc('hour', l.fecha_lectura)
WITH NO DATA;
CREATE UNIQUE INDEX idx_mv_ocupacion_hora ON mv_ocupacion_hora (id_espacio, hora);
