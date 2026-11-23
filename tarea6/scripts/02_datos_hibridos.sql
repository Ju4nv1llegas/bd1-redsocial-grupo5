/* ============================================================================
   Red Social Estudiantil Pascualina - Tarea 6: Datos de demostración (DML)
   Bases de Datos I - G100 (SD1006) - Autor: Juan Camilo Villegas Ocampo

   Todos los datos son SINTÉTICOS (generados con generate_series y random()).
   setseed() fija la semilla para que cada ejecución produzca los mismos datos.
   Volumen aproximado: ~100 000 lecturas IoT, 20 000 logs, ~70 archivos multimedia.
   Requiere haber ejecutado 01_ddl_hibrido.sql.
   ============================================================================ */

SET search_path TO red_social;
SELECT setseed(0.42);

-- Limpieza para poder re-ejecutar el script
TRUNCATE alerta_iot, lectura_iot, dispositivo_iot, tipo_dispositivo,
         log_actividad, contenido_multimedia RESTART IDENTITY CASCADE;

/* ---------------------------------------------------------------------------
   1. Catálogo de tipos de dispositivo (esquema_lectura = contrato del payload)
   --------------------------------------------------------------------------- */
INSERT INTO tipo_dispositivo (nombre_tipo, descripcion, esquema_lectura) VALUES
 ('AMBIENTAL',  'Sensor de temperatura, humedad y CO2',
   '{"temperatura_c":"numeric","humedad_pct":"numeric","co2_ppm":"integer"}'),
 ('OCUPACION',  'Contador de personas por cámara de infrarrojos',
   '{"personas":"integer","aforo_pct":"numeric"}'),
 ('ACCESO',     'Lector RFID de carné para asistencia automatizada',
   '{"id_estudiante":"integer","accion":"ENTRADA|SALIDA"}');

/* ---------------------------------------------------------------------------
   2. Dispositivos: un sensor AMBIENTAL y uno de OCUPACION por cada espacio,
      más un lector ACCESO en los 3 primeros espacios.
   --------------------------------------------------------------------------- */
INSERT INTO dispositivo_iot (id_tipo, id_espacio, codigo_serie, estado, fecha_instalacion, configuracion)
SELECT 1, e.id_espacio, 'AMB-' || LPAD(e.id_espacio::text, 3, '0'), 'ACTIVO', DATE '2026-08-01',
       jsonb_build_object('firmware', 'v2.3.1', 'intervalo_seg', 300,
                          'umbrales', jsonb_build_object('co2_ppm', 1000, 'temperatura_c', 30))
  FROM espacio e;

INSERT INTO dispositivo_iot (id_tipo, id_espacio, codigo_serie, estado, fecha_instalacion, configuracion)
SELECT 2, e.id_espacio, 'OCU-' || LPAD(e.id_espacio::text, 3, '0'),
       CASE WHEN e.id_espacio = 8 THEN 'MANTENIMIENTO' ELSE 'ACTIVO' END, DATE '2026-08-01',
       jsonb_build_object('firmware', 'v1.9.0', 'intervalo_seg', 300, 'camara', jsonb_build_object('fps', 5))
  FROM espacio e;

INSERT INTO dispositivo_iot (id_tipo, id_espacio, codigo_serie, estado, fecha_instalacion, configuracion)
SELECT 3, e.id_espacio, 'ACC-' || LPAD(e.id_espacio::text, 3, '0'), 'ACTIVO', DATE '2026-09-01',
       '{"firmware":"v1.2.0","tecnologia":"RFID 13.56MHz"}'::jsonb
  FROM espacio e WHERE e.id_espacio <= 3;

/* ---------------------------------------------------------------------------
   3. Lecturas masivas (big data). Se desactiva el trigger durante la carga
      masiva (evita ~116 000 UPDATE sobre espacio) y se reactiva después.
      Horario 06:00-21:55 (lun-sáb), una lectura cada 5 min, del 15-oct al 21-nov-2026.
      La ocupación sigue una campana diaria (pico a mediodía) y el CO2 sube con
      la ocupación, de modo que los datos tengan relación entre sí.
   --------------------------------------------------------------------------- */
ALTER TABLE lectura_iot DISABLE TRIGGER trg_lectura_iot_procesar;

-- 3.1 Sensores de OCUPACION
INSERT INTO lectura_iot (id_dispositivo, fecha_lectura, payload)
SELECT d.id_dispositivo, t.ts,
       jsonb_build_object('personas', p.personas,
                          'aforo_pct', ROUND(100.0 * p.personas / e.capacidad, 1))
  FROM dispositivo_iot d
  JOIN espacio e ON e.id_espacio = d.id_espacio
 CROSS JOIN LATERAL generate_series(TIMESTAMP '2026-10-15 06:00', TIMESTAMP '2026-11-21 21:55', INTERVAL '5 minutes') AS t(ts)
 CROSS JOIN LATERAL (
        SELECT GREATEST(0, LEAST(ROUND(e.capacidad * 1.03 *
                 exp(-power(EXTRACT(hour FROM t.ts) + EXTRACT(minute FROM t.ts) / 60.0 - 13, 2) / 18.0)
                 * (0.55 + 0.45 * random()))::int,
                 ROUND(e.capacidad * 1.2)::int)) AS personas
 ) p
 WHERE d.id_tipo = 2 AND d.estado = 'ACTIVO'
   AND EXTRACT(isodow FROM t.ts) <> 7                -- sin domingos
   AND EXTRACT(hour FROM t.ts) BETWEEN 6 AND 21;     -- solo horario de campus

-- 3.2 Sensores AMBIENTALES (el CO2 depende de la ocupación del mismo espacio y minuto)
INSERT INTO lectura_iot (id_dispositivo, fecha_lectura, payload)
SELECT d.id_dispositivo, t.ts,
       jsonb_build_object(
           'temperatura_c', ROUND((21 + 5 * exp(-power(EXTRACT(hour FROM t.ts) - 14, 2) / 30.0) + 2 * random())::numeric, 1),
           'humedad_pct',   ROUND((55 + 15 * random())::numeric, 1),
           'co2_ppm',       (420 + o.ocup * (900.0 / e.capacidad) * (0.6 + 0.8 * random()))::int)
  FROM dispositivo_iot d
  JOIN espacio e ON e.id_espacio = d.id_espacio
 CROSS JOIN LATERAL generate_series(TIMESTAMP '2026-10-15 06:00', TIMESTAMP '2026-11-21 21:55', INTERVAL '5 minutes') AS t(ts)
 CROSS JOIN LATERAL (
        SELECT COALESCE(MAX(l.ocupacion), 0) AS ocup
          FROM lectura_iot l
          JOIN dispositivo_iot d2 ON d2.id_dispositivo = l.id_dispositivo
         WHERE d2.id_espacio = d.id_espacio AND d2.id_tipo = 2
           AND l.fecha_lectura = t.ts
 ) o
 WHERE d.id_tipo = 1 AND EXTRACT(isodow FROM t.ts) <> 7
   AND EXTRACT(hour FROM t.ts) BETWEEN 6 AND 21;

-- 3.3 Lectores de ACCESO (asistencia): ~3 000 pasadas de carné
INSERT INTO lectura_iot (id_dispositivo, fecha_lectura, payload)
SELECT d.id_dispositivo,
       TIMESTAMP '2026-10-15 06:30' + (random() * 37) * INTERVAL '1 day' + (random() * 14) * INTERVAL '1 hour',
       jsonb_build_object('id_estudiante', 1 + floor(random() * 40)::int,
                          'accion', CASE WHEN random() < 0.5 THEN 'ENTRADA' ELSE 'SALIDA' END)
  FROM dispositivo_iot d
 CROSS JOIN generate_series(1, 1000)
 WHERE d.id_tipo = 3;

ALTER TABLE lectura_iot ENABLE TRIGGER trg_lectura_iot_procesar;

-- 3.4 Estado inicial de espacio.datos_iot: última lectura de cada sensor (ambiental y ocupación)
UPDATE espacio e
   SET datos_iot = COALESCE(e.datos_iot, '{}'::jsonb) || u.payload
                   || jsonb_build_object('ultima_lectura', u.fecha_lectura)
  FROM (SELECT DISTINCT ON (d.id_dispositivo) d.id_espacio, l.payload, l.fecha_lectura
          FROM lectura_iot l JOIN dispositivo_iot d ON d.id_dispositivo = l.id_dispositivo
         WHERE d.id_tipo IN (1, 2)
         ORDER BY d.id_dispositivo, l.fecha_lectura DESC) u
 WHERE u.id_espacio = e.id_espacio;

-- 3.5 Lecturas "en vivo" (22-nov-2026) con trigger ACTIVO: actualizan espacio.datos_iot
--     y generan alertas (CO2 alto, temperatura alta y aforo excedido).
INSERT INTO lectura_iot (id_dispositivo, fecha_lectura, payload) VALUES
 ((SELECT id_dispositivo FROM dispositivo_iot WHERE codigo_serie = 'AMB-001'), '2026-11-22 10:00', '{"temperatura_c":24.8,"humedad_pct":58.0,"co2_ppm":640}'),
 ((SELECT id_dispositivo FROM dispositivo_iot WHERE codigo_serie = 'AMB-001'), '2026-11-22 10:05', '{"temperatura_c":31.2,"humedad_pct":61.5,"co2_ppm":1850}'),
 ((SELECT id_dispositivo FROM dispositivo_iot WHERE codigo_serie = 'OCU-001'), '2026-11-22 10:05', '{"personas":47,"aforo_pct":117.5}'),
 ((SELECT id_dispositivo FROM dispositivo_iot WHERE codigo_serie = 'AMB-002'), '2026-11-22 10:05', '{"temperatura_c":23.1,"humedad_pct":52.0,"co2_ppm":1120}');

/* ---------------------------------------------------------------------------
   4. Alertas históricas (reconstruidas con una sola sentencia sobre el histórico)
   --------------------------------------------------------------------------- */
INSERT INTO alerta_iot (id_dispositivo, fecha_alerta, tipo_alerta, severidad, detalle)
SELECT l.id_dispositivo, l.fecha_lectura, 'CO2_ALTO',
       CASE WHEN (l.payload ->> 'co2_ppm')::int > 1500 THEN 'ALTA' ELSE 'MEDIA' END,
       jsonb_build_object('valor', l.payload -> 'co2_ppm', 'umbral', 1000)
  FROM lectura_iot l
 WHERE l.fecha_lectura < '2026-11-22'
   AND (l.payload ->> 'co2_ppm')::int > 1000;

INSERT INTO alerta_iot (id_dispositivo, fecha_alerta, tipo_alerta, severidad, detalle)
SELECT l.id_dispositivo, l.fecha_lectura, 'AFORO_EXCEDIDO', 'ALTA',
       jsonb_build_object('personas', l.ocupacion, 'capacidad', e.capacidad)
  FROM lectura_iot l
  JOIN dispositivo_iot d ON d.id_dispositivo = l.id_dispositivo
  JOIN espacio e ON e.id_espacio = d.id_espacio
 WHERE l.fecha_lectura < '2026-11-22' AND l.ocupacion > e.capacidad;

/* ---------------------------------------------------------------------------
   5. Logs de actividad (20 000 eventos con detalle distinto según el tipo)
   --------------------------------------------------------------------------- */
INSERT INTO log_actividad (id_estudiante, fecha_evento, tipo_evento, detalle)
SELECT CASE WHEN random() < 0.03 THEN NULL ELSE 1 + floor(random() * 40)::int END,
       TIMESTAMP '2026-10-15 06:00' + (random() * 38) * INTERVAL '1 day' + (random() * 16) * INTERVAL '1 hour',
       ev.tipo,
       jsonb_build_object('dispositivo', (ARRAY['Android','iOS','Windows','macOS'])[1 + floor(random() * 4)::int],
                          'navegador',   (ARRAY['Chrome','Safari','Firefox','Edge'])[1 + floor(random() * 4)::int])
       || CASE ev.tipo
            WHEN 'login'              THEN jsonb_build_object('exitoso', random() < 0.94, 'metodo', (ARRAY['password','sso_institucional'])[1 + floor(random() * 2)::int])
            WHEN 'vista_publicacion'  THEN jsonb_build_object('id_publicacion', 1 + floor(random() * 80)::int, 'segundos', 3 + floor(random() * 240)::int)
            WHEN 'busqueda'           THEN jsonb_build_object('termino', (ARRAY['sql','postgres','parcial','mentoria','grupo de estudio','python','hackaton','cancha'])[1 + floor(random() * 8)::int],
                                                              'resultados', floor(random() * 30)::int)
            WHEN 'descarga_recurso'   THEN jsonb_build_object('id_recurso', 1 + floor(random() * 8)::int, 'kb', 100 + floor(random() * 9000)::int)
            WHEN 'reserva_espacio'    THEN jsonb_build_object('id_espacio', 1 + floor(random() * 8)::int, 'minutos', (ARRAY[30,60,90,120])[1 + floor(random() * 4)::int])
            ELSE jsonb_build_object('tipo_reaccion', (ARRAY['ME_GUSTA','ME_ENCANTA','UTIL'])[1 + floor(random() * 3)::int])
          END
  FROM generate_series(1, 20000) g
 CROSS JOIN LATERAL (SELECT (ARRAY['login','vista_publicacion','vista_publicacion','busqueda','descarga_recurso','reserva_espacio','reaccion'])[1 + floor(random() * 7)::int] AS tipo WHERE g > 0) ev;

/* ---------------------------------------------------------------------------
   6. Contenido multimedia: 1 a 2 archivos para ~60 % de las publicaciones
   --------------------------------------------------------------------------- */
INSERT INTO contenido_multimedia (id_publicacion, tipo_contenido, url, tamano_kb, metadatos)
SELECT p.id_publicacion, m.tipo,
       'https://media.pascualina.edu.co/p' || p.id_publicacion || '/f' || n.n || CASE m.tipo WHEN 'IMAGEN' THEN '.jpg' WHEN 'VIDEO' THEN '.mp4' WHEN 'AUDIO' THEN '.mp3' ELSE '.pdf' END,
       CASE m.tipo WHEN 'VIDEO' THEN 20000 + floor(random() * 90000)::int ELSE 200 + floor(random() * 5000)::int END,
       CASE m.tipo
         WHEN 'IMAGEN'    THEN jsonb_build_object('ancho', 1080, 'alto', (ARRAY[720,1080,1350])[1 + floor(random() * 3)::int],
                                                  'etiquetas', jsonb_build_array('campus', (ARRAY['meme','apuntes','evento','laboratorio'])[1 + floor(random() * 4)::int]))
         WHEN 'VIDEO'     THEN jsonb_build_object('duracion_seg', 30 + floor(random() * 900)::int, 'resolucion', (ARRAY['720p','1080p'])[1 + floor(random() * 2)::int],
                                                  'subtitulos', to_jsonb((ARRAY['es','en','es,en'])[1 + floor(random() * 3)::int]))
         WHEN 'AUDIO'     THEN jsonb_build_object('duracion_seg', 60 + floor(random() * 1800)::int, 'formato', 'mp3', 'es_podcast', random() < 0.5)
         ELSE                  jsonb_build_object('paginas', 1 + floor(random() * 60)::int, 'idioma', 'es')
       END
  FROM publicacion p
 CROSS JOIN LATERAL generate_series(1, 1 + (p.id_publicacion % 2)) AS n(n)
 CROSS JOIN LATERAL (SELECT (ARRAY['IMAGEN','IMAGEN','VIDEO','AUDIO','DOCUMENTO'])[1 + floor(random() * 5)::int] AS tipo WHERE n.n > 0) m
 WHERE p.id_publicacion % 5 <> 0;

/* ---------------------------------------------------------------------------
   7. Preferencias de usuario (JSONB flexible: no todos tienen las mismas claves)
   --------------------------------------------------------------------------- */
UPDATE perfil
   SET preferencias = jsonb_build_object(
           'tema',   (ARRAY['claro','oscuro','claro'])[1 + (id_perfil % 3)],
           'idioma', 'es',
           'notificaciones', jsonb_build_object('correo', id_perfil % 3 <> 0, 'push', id_perfil % 2 = 0, 'resumen_semanal', id_perfil % 4 = 0))
       || CASE WHEN id_perfil % 5 = 0 THEN '{"privacidad":{"perfil_publico":false}}'::jsonb ELSE '{}'::jsonb END;

-- Refrescar la vista materializada y recolectar estadísticas para el planificador
REFRESH MATERIALIZED VIEW mv_ocupacion_hora;
ANALYZE lectura_iot; ANALYZE log_actividad; ANALYZE contenido_multimedia; ANALYZE alerta_iot;
