# Diccionario de datos — Tarea 6: arquitectura híbrida (relacional + JSONB + IoT)

Esquema `red_social` · PostgreSQL 16. Este diccionario documenta los **6 objetos nuevos** y la columna añadida a `perfil`; las 25 tablas base están en el diccionario de la Tarea 5.

Convenciones: **PK** clave primaria, **FK** clave foránea, **UQ** único, **NN** no admite NULL. Las columnas **JSONB** son las semiestructuradas.


## tipo_dispositivo

Catálogo relacional de tipos de sensor del campus.

| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| `id_tipo` | INTEGER | NN | Identificador autonumérico del tipo. |
| `nombre_tipo` | CHARACTER VARYING(40) | NN | Nombre del tipo (AMBIENTAL, OCUPACION, ACCESO). |
| `descripcion` | CHARACTER VARYING(255) | NULL | Texto breve del tipo de sensor. |
| `esquema_lectura` | JSONB | NN | JSONB: contrato de las claves y tipos que trae el payload de ese sensor. |

**Restricciones**

- `uq_tipo_dispositivo_nombre (UQ): UNIQUE (nombre_tipo)`
- `pk_tipo_dispositivo (PK): PRIMARY KEY (id_tipo)`
- `ck_tipo_dispositivo_esquema (CHECK): CHECK ((jsonb_typeof(esquema_lectura) = 'object'::text))`

**Índices**

- `CREATE UNIQUE INDEX uq_tipo_dispositivo_nombre ON tipo_dispositivo USING btree (nombre_tipo)`

## dispositivo_iot

Sensores instalados en espacios del campus.

| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| `id_dispositivo` | INTEGER | NN | Identificador autonumérico del sensor. |
| `id_tipo` | INTEGER | NN | Tipo de sensor (FK a tipo_dispositivo). |
| `id_espacio` | INTEGER | NN | Espacio donde está instalado (FK a espacio). |
| `codigo_serie` | CHARACTER VARYING(30) | NN | Código de serie único (AMB-001, OCU-001…). |
| `estado` | CHARACTER VARYING(15) | NN | ACTIVO, INACTIVO o MANTENIMIENTO. |
| `fecha_instalacion` | DATE | NN | Fecha de instalación. |
| `configuracion` | JSONB | NN | JSONB: firmware, intervalo de muestreo y umbrales de alerta (co2_ppm, temperatura_c). |

**Restricciones**

- `uq_dispositivo_iot_serie (UQ): UNIQUE (codigo_serie)`
- `pk_dispositivo_iot (PK): PRIMARY KEY (id_dispositivo)`
- `fk_dispositivo_iot_espacio (FK): FOREIGN KEY (id_espacio) REFERENCES red_social.espacio(id_espacio) ON UPDATE CASCADE ON DELETE RESTRICT`
- `fk_dispositivo_iot_tipo (FK): FOREIGN KEY (id_tipo) REFERENCES red_social.tipo_dispositivo(id_tipo) ON UPDATE CASCADE ON DELETE RESTRICT`
- `ck_dispositivo_iot_config (CHECK): CHECK ((jsonb_typeof(configuracion) = 'object'::text))`
- `ck_dispositivo_iot_estado (CHECK): CHECK (((estado)::text = ANY ((ARRAY['ACTIVO'::character varying, 'INACTIVO'::character varying, 'MANTENIMIENTO'::character varying])::text[])))`

**Índices**

- `CREATE INDEX idx_dispositivo_iot_espacio ON dispositivo_iot USING btree (id_espacio)`
- `CREATE INDEX idx_dispositivo_iot_tipo ON dispositivo_iot USING btree (id_tipo)`
- `CREATE UNIQUE INDEX uq_dispositivo_iot_serie ON dispositivo_iot USING btree (codigo_serie)`

## lectura_iot

Flujo de lecturas de los sensores (big data). Tabla particionada por mes sobre fecha_lectura.

| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| `id_lectura` | BIGINT | NN | Identificador autonumérico (BIGINT) de la lectura. |
| `id_dispositivo` | INTEGER | NN | Sensor que generó la lectura (FK). |
| `fecha_lectura` | TIMESTAMP WITHOUT TIME ZONE | NN | Fecha y hora de la medición (clave de partición). |
| `payload` | JSONB | NN | JSONB: medidas del sensor (temperatura_c, humedad_pct, co2_ppm, personas, aforo_pct, id_estudiante, accion). |
| `ocupacion` | INTEGER | NULL | Columna GENERADA: payload->>'personas' como entero; NULL si el sensor no mide personas. |

**Restricciones**

- `pk_lectura_iot (PK): PRIMARY KEY (id_lectura, fecha_lectura)`
- `fk_lectura_iot_dispositivo (FK): FOREIGN KEY (id_dispositivo) REFERENCES red_social.dispositivo_iot(id_dispositivo) ON UPDATE CASCADE ON DELETE CASCADE`
- `ck_lectura_iot_payload (CHECK): CHECK ((jsonb_typeof(payload) = 'object'::text))`

**Índices**

- `CREATE INDEX idx_lectura_iot_disp_fecha ON ONLY lectura_iot USING btree (id_dispositivo, fecha_lectura)`
- `CREATE INDEX idx_lectura_iot_fecha_brin ON ONLY lectura_iot USING brin (fecha_lectura)`
- `CREATE INDEX idx_lectura_iot_ocupacion ON ONLY lectura_iot USING btree (ocupacion) WHERE (ocupacion IS NOT NULL)`
- `CREATE INDEX idx_lectura_iot_payload_gin ON ONLY lectura_iot USING gin (payload jsonb_path_ops)`

## alerta_iot

Alertas generadas por el trigger cuando una lectura supera umbrales.

| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| `id_alerta` | BIGINT | NN | Identificador autonumérico (BIGINT). |
| `id_dispositivo` | INTEGER | NN | Sensor que originó la alerta (FK). |
| `fecha_alerta` | TIMESTAMP WITHOUT TIME ZONE | NN | Fecha de la lectura que causó la alerta. |
| `tipo_alerta` | CHARACTER VARYING(20) | NN | CO2_ALTO, TEMPERATURA_ALTA o AFORO_EXCEDIDO. |
| `severidad` | CHARACTER VARYING(10) | NN | MEDIA o ALTA. |
| `detalle` | JSONB | NN | JSONB: valor medido y umbral (o personas y capacidad). |

**Restricciones**

- `pk_alerta_iot (PK): PRIMARY KEY (id_alerta)`
- `fk_alerta_iot_dispositivo (FK): FOREIGN KEY (id_dispositivo) REFERENCES red_social.dispositivo_iot(id_dispositivo) ON UPDATE CASCADE ON DELETE CASCADE`
- `ck_alerta_iot_severidad (CHECK): CHECK (((severidad)::text = ANY ((ARRAY['MEDIA'::character varying, 'ALTA'::character varying])::text[])))`
- `ck_alerta_iot_tipo (CHECK): CHECK (((tipo_alerta)::text = ANY ((ARRAY['CO2_ALTO'::character varying, 'TEMPERATURA_ALTA'::character varying, 'AFORO_EXCEDIDO'::character varying])::text[])))`

**Índices**

- `CREATE INDEX idx_alerta_iot_dispositivo ON alerta_iot USING btree (id_dispositivo)`
- `CREATE INDEX idx_alerta_iot_fecha ON alerta_iot USING btree (fecha_alerta)`

## log_actividad

Registro de acciones de los usuarios en la plataforma.

| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| `id_log` | BIGINT | NN | Identificador autonumérico (BIGINT). |
| `id_estudiante` | INTEGER | NULL | Estudiante que realizó la acción (FK, NULL si es visita anónima). |
| `fecha_evento` | TIMESTAMP WITHOUT TIME ZONE | NN | Momento del evento. |
| `tipo_evento` | CHARACTER VARYING(30) | NN | login, vista_publicacion, busqueda, descarga_recurso, reserva_espacio o reaccion. |
| `detalle` | JSONB | NN | JSONB: dispositivo, navegador y campos propios de cada tipo de evento. |

**Restricciones**

- `pk_log_actividad (PK): PRIMARY KEY (id_log)`
- `fk_log_actividad_estudiante (FK): FOREIGN KEY (id_estudiante) REFERENCES red_social.estudiante(id_estudiante) ON UPDATE CASCADE ON DELETE SET NULL`
- `ck_log_actividad_detalle (CHECK): CHECK ((jsonb_typeof(detalle) = 'object'::text))`

**Índices**

- `CREATE INDEX idx_log_actividad_detalle_gin ON log_actividad USING gin (detalle jsonb_path_ops)`
- `CREATE INDEX idx_log_actividad_estudiante ON log_actividad USING btree (id_estudiante)`
- `CREATE INDEX idx_log_actividad_fecha_brin ON log_actividad USING brin (fecha_evento)`
- `CREATE INDEX idx_log_actividad_tipo ON log_actividad USING btree (tipo_evento)`

## contenido_multimedia

Archivos (imagen, video, audio, documento) adjuntos a publicaciones.

| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| `id_contenido` | INTEGER | NN | Identificador autonumérico. |
| `id_publicacion` | INTEGER | NN | Publicación a la que pertenece (FK). |
| `tipo_contenido` | CHARACTER VARYING(10) | NN | IMAGEN, VIDEO, AUDIO o DOCUMENTO. |
| `url` | CHARACTER VARYING(255) | NN | Ubicación del archivo (única). |
| `tamano_kb` | INTEGER | NN | Tamaño en kilobytes (> 0). |
| `metadatos` | JSONB | NN | JSONB: propiedades técnicas que varían por tipo (resolución, duración, subtítulos, etiquetas, páginas…). |

**Restricciones**

- `uq_contenido_multimedia_url (UQ): UNIQUE (url)`
- `pk_contenido_multimedia (PK): PRIMARY KEY (id_contenido)`
- `fk_contenido_multimedia_publicacion (FK): FOREIGN KEY (id_publicacion) REFERENCES red_social.publicacion(id_publicacion) ON UPDATE CASCADE ON DELETE CASCADE`
- `ck_contenido_multimedia_meta (CHECK): CHECK ((jsonb_typeof(metadatos) = 'object'::text))`
- `ck_contenido_multimedia_tamano (CHECK): CHECK ((tamano_kb > 0))`
- `ck_contenido_multimedia_tipo (CHECK): CHECK (((tipo_contenido)::text = ANY ((ARRAY['IMAGEN'::character varying, 'VIDEO'::character varying, 'AUDIO'::character varying, 'DOCUMENTO'::character varying])::text[])))`

**Índices**

- `CREATE INDEX idx_contenido_multimedia_meta_gin ON contenido_multimedia USING gin (metadatos)`
- `CREATE INDEX idx_contenido_multimedia_pub ON contenido_multimedia USING btree (id_publicacion)`
- `CREATE UNIQUE INDEX uq_contenido_multimedia_url ON contenido_multimedia USING btree (url)`

## perfil (columna añadida)

| Columna | Tipo | Nulo | Descripción |
|---|---|---|---|
| `preferencias` | JSONB | NN | Ajustes flexibles del usuario: tema, idioma, notificaciones, privacidad, accesibilidad. Índice GIN `idx_perfil_preferencias_gin`. |

## Objetos adicionales

- **Particiones** de `lectura_iot`: `lectura_iot_2026_09`, `_10`, `_11`, `_12` y `lectura_iot_otras` (DEFAULT).
- **Función/trigger** `fn_procesar_lectura_iot()` / `trg_lectura_iot_procesar`: tras cada lectura actualiza `espacio.datos_iot` y crea alertas.
- **Vista materializada** `mv_ocupacion_hora`: ocupación, CO2 y temperatura promedio por espacio y hora.
