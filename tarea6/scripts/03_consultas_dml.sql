/* ============================================================================
   Red Social Estudiantil Pascualina - Tarea 6: Consultas DML sobre datos
   semiestructurados (JSONB) e IoT
   Bases de Datos I - G100 (SD1006) - Autor: Juan Camilo Villegas Ocampo

   Operadores JSONB usados:
     ->   extrae un campo como JSONB          ->>  extrae un campo como TEXTO
     @>   "contiene" (usa índice GIN)         ?    ¿existe la clave? (usa GIN)
     ||   concatena/fusiona documentos        -    elimina una clave
     jsonb_set, jsonb_build_object, jsonb_array_elements_text, jsonb_path_exists
   Cada consulta indica: objetivo de negocio, tablas/campos JSON y técnicas usadas.
   Requiere 01_ddl_hibrido.sql y 02_datos_hibridos.sql.
   ============================================================================ */

SET search_path TO red_social;

/* ============================================================================
   BLOQUE A - Analítica IoT del campus (big data)
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- C1. Estado actual de cada espacio (última lectura guardada por el trigger)
-- Objetivo: mostrar en la app qué aulas están libres y cómo está el aire.
-- Técnica: JOIN sede-espacio, extracción ->> con casteo, filtro por clave (?).
-- ---------------------------------------------------------------------------
SELECT s.nombre_sede,
       e.nombre_espacio,
       e.capacidad,
       (e.datos_iot ->> 'ultima_lectura')::timestamp        AS ultima_lectura,
       (e.datos_iot ->> 'personas')::int                    AS personas,
       (e.datos_iot ->> 'co2_ppm')::int                     AS co2_ppm,
       (e.datos_iot ->> 'temperatura_c')::numeric           AS temperatura_c
  FROM espacio e
  JOIN sede s ON s.id_sede = e.id_sede
 WHERE e.datos_iot ? 'ultima_lectura'
 ORDER BY s.nombre_sede, e.nombre_espacio;

-- ---------------------------------------------------------------------------
-- C2. Perfil horario de ocupación por espacio (últimos 30 días de datos)
-- Objetivo: recomendar a qué hora ir a la sala de estudio de la biblioteca.
-- Técnica: columna generada "ocupacion" (extraída del JSON), filtro por fecha
--          (poda de particiones), JOIN x2, AVG/MAX/COUNT y GROUP BY.
-- ---------------------------------------------------------------------------
SELECT e.nombre_espacio,
       EXTRACT(hour FROM l.fecha_lectura)::int      AS hora,
       COUNT(*)                                     AS lecturas,
       ROUND(AVG(l.ocupacion), 1)                   AS ocupacion_prom,
       MAX(l.ocupacion)                             AS ocupacion_max,
       ROUND(100.0 * AVG(l.ocupacion) / e.capacidad, 1) AS aforo_prom_pct
  FROM lectura_iot l
  JOIN dispositivo_iot d ON d.id_dispositivo = l.id_dispositivo
  JOIN espacio e         ON e.id_espacio = d.id_espacio
 WHERE l.fecha_lectura >= TIMESTAMP '2026-10-22' AND l.fecha_lectura < TIMESTAMP '2026-11-22'
   AND l.ocupacion IS NOT NULL
   AND e.id_espacio = 6                              -- Sala de Estudio Biblioteca
 GROUP BY e.nombre_espacio, e.capacidad, EXTRACT(hour FROM l.fecha_lectura)
 ORDER BY hora;

-- ---------------------------------------------------------------------------
-- C3. Relación entre aforo y calidad del aire (CO2)
-- Objetivo: demostrar con datos que más personas => más CO2 y definir cuándo ventilar.
-- Técnica: CTE que cruza dos sensores del MISMO espacio y minuto, width_bucket
--          para formar rangos de aforo, AVG/COUNT/GROUP BY.
-- ---------------------------------------------------------------------------
WITH cruce AS (
    SELECT dc.id_espacio,
           lo.ocupacion,
           (la.payload ->> 'co2_ppm')::int AS co2
      FROM lectura_iot lo
      JOIN dispositivo_iot do_ ON do_.id_dispositivo = lo.id_dispositivo AND do_.id_tipo = 2
      JOIN dispositivo_iot dc  ON dc.id_espacio = do_.id_espacio        AND dc.id_tipo = 1
      JOIN lectura_iot la      ON la.id_dispositivo = dc.id_dispositivo AND la.fecha_lectura = lo.fecha_lectura
     WHERE lo.fecha_lectura >= '2026-11-01' AND lo.fecha_lectura < '2026-11-22'
)
SELECT e.nombre_espacio,
       width_bucket(c.ocupacion::numeric / e.capacidad, 0, 1.2, 6) AS rango_aforo,   -- 6 rangos de 0 a 120 %
       COUNT(*)                     AS muestras,
       ROUND(AVG(c.co2), 0)         AS co2_promedio,
       MAX(c.co2)                   AS co2_maximo
  FROM cruce c
  JOIN espacio e ON e.id_espacio = c.id_espacio
 WHERE e.id_espacio IN (1, 6)
 GROUP BY e.nombre_espacio, rango_aforo
 ORDER BY e.nombre_espacio, rango_aforo;

-- ---------------------------------------------------------------------------
-- C4. Espacios con más alertas ambientales y de aforo
-- Objetivo: priorizar mantenimiento y ventilación.
-- Técnica: JOIN x3, COUNT con FILTER, SUM, HAVING y lectura del detalle JSONB (->>).
-- ---------------------------------------------------------------------------
SELECT e.nombre_espacio,
       COUNT(*)                                                         AS total_alertas,
       COUNT(*) FILTER (WHERE a.tipo_alerta = 'CO2_ALTO')               AS co2_alto,
       COUNT(*) FILTER (WHERE a.tipo_alerta = 'AFORO_EXCEDIDO')         AS aforo_excedido,
       COUNT(*) FILTER (WHERE a.severidad = 'ALTA')                     AS severidad_alta,
       MAX((a.detalle ->> 'valor')::numeric) FILTER (WHERE a.tipo_alerta = 'CO2_ALTO') AS co2_pico
  FROM alerta_iot a
  JOIN dispositivo_iot d ON d.id_dispositivo = a.id_dispositivo
  JOIN espacio e         ON e.id_espacio = d.id_espacio
 GROUP BY e.nombre_espacio
HAVING COUNT(*) >= 5
 ORDER BY total_alertas DESC;

-- ---------------------------------------------------------------------------
-- C5. Asistencia automatizada por programa académico (lectores RFID)
-- Objetivo: medir el uso real del campus por programa.
-- Técnica: filtro @> (usa índice GIN), JOIN de 4 tablas relacionales con el
--          id_estudiante guardado DENTRO del JSON, COUNT(DISTINCT), GROUP BY.
-- ---------------------------------------------------------------------------
SELECT f.nombre_facultad,
       pr.nombre_programa,
       COUNT(*)                          AS entradas,
       COUNT(DISTINCT est.id_estudiante) AS estudiantes_distintos
  FROM lectura_iot l
  JOIN estudiante est ON est.id_estudiante = (l.payload ->> 'id_estudiante')::int
  JOIN programa pr    ON pr.id_programa = est.id_programa
  JOIN facultad f     ON f.id_facultad = pr.id_facultad
 WHERE l.payload @> '{"accion":"ENTRADA"}'
 GROUP BY f.nombre_facultad, pr.nombre_programa
 ORDER BY entradas DESC;

-- ---------------------------------------------------------------------------
-- C6. Día de mayor ocupación de cada espacio (función de ventana)
-- Objetivo: identificar picos de demanda para planear aulas.
-- Técnica: vista materializada (datos ya agregados), RANK() OVER (PARTITION BY ...).
-- ---------------------------------------------------------------------------
SELECT nombre_espacio, hora, ocupacion_max, co2_prom, posicion
  FROM (
        SELECT e.nombre_espacio, m.hora, m.ocupacion_max, m.co2_prom,
               RANK() OVER (PARTITION BY m.id_espacio ORDER BY m.ocupacion_max DESC NULLS LAST, m.hora) AS posicion
          FROM mv_ocupacion_hora m
          JOIN espacio e ON e.id_espacio = m.id_espacio
       ) t
 WHERE posicion <= 2
 ORDER BY nombre_espacio, posicion;

/* ============================================================================
   BLOQUE B - Logs de actividad (semiestructurado)
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- C7. Términos más buscados en la red social
-- Objetivo: saber qué busca la comunidad para crear contenido y grupos.
-- Técnica: filtro por tipo, ->> sobre el detalle, COUNT, AVG y GROUP BY.
-- ---------------------------------------------------------------------------
SELECT detalle ->> 'termino'                     AS termino,
       COUNT(*)                                  AS busquedas,
       ROUND(AVG((detalle ->> 'resultados')::int), 1) AS resultados_prom,
       COUNT(*) FILTER (WHERE (detalle ->> 'resultados')::int = 0) AS sin_resultados
  FROM log_actividad
 WHERE tipo_evento = 'busqueda'
 GROUP BY detalle ->> 'termino'
 ORDER BY busquedas DESC
 LIMIT 10;

-- ---------------------------------------------------------------------------
-- C8. Tasa de inicios de sesión fallidos por dispositivo
-- Objetivo: detectar problemas de acceso o intentos sospechosos.
-- Técnica: @> con booleano JSON, FILTER, división con NULLIF, GROUP BY.
-- ---------------------------------------------------------------------------
SELECT detalle ->> 'dispositivo'                                   AS dispositivo,
       COUNT(*)                                                    AS intentos,
       COUNT(*) FILTER (WHERE detalle @> '{"exitoso": false}')     AS fallidos,
       ROUND(100.0 * COUNT(*) FILTER (WHERE detalle @> '{"exitoso": false}') / NULLIF(COUNT(*), 0), 2) AS pct_fallidos
  FROM log_actividad
 WHERE tipo_evento = 'login'
 GROUP BY detalle ->> 'dispositivo'
 ORDER BY pct_fallidos DESC;

-- ---------------------------------------------------------------------------
-- C9. Estudiantes más activos y cuánto publican (relacional + log JSON)
-- Objetivo: combinar el comportamiento (logs) con la producción de contenido.
-- Técnica: dos subconsultas agregadas unidas por JOIN/LEFT JOIN, SUM de campo
--          JSON casteado, COUNT, ORDER BY y LIMIT.
-- ---------------------------------------------------------------------------
SELECT est.codigo_estudiante,
       est.nombre || ' ' || est.apellido      AS estudiante,
       pr.nombre_programa,
       act.eventos,
       act.segundos_leyendo,
       COALESCE(pub.publicaciones, 0)         AS publicaciones
  FROM (
        SELECT id_estudiante,
               COUNT(*)                                                      AS eventos,
               COALESCE(SUM((detalle ->> 'segundos')::int) FILTER (WHERE tipo_evento = 'vista_publicacion'), 0) AS segundos_leyendo
          FROM log_actividad
         WHERE id_estudiante IS NOT NULL
         GROUP BY id_estudiante
       ) act
  JOIN estudiante est ON est.id_estudiante = act.id_estudiante
  JOIN programa pr    ON pr.id_programa = est.id_programa
  LEFT JOIN (SELECT id_autor, COUNT(*) AS publicaciones FROM publicacion GROUP BY id_autor) pub
         ON pub.id_autor = est.id_estudiante
 ORDER BY act.eventos DESC
 LIMIT 10;

-- ---------------------------------------------------------------------------
-- C10. Publicaciones más leídas del mes (vistas registradas en el log)
-- Objetivo: ranking de contenido para la portada.
-- Técnica: JOIN entre el id guardado en el JSON y publicacion, filtro de rango
--          de fechas, SUM/COUNT/AVG y GROUP BY.
-- ---------------------------------------------------------------------------
SELECT p.id_publicacion,
       p.tipo_publicacion,
       LEFT(p.contenido, 45)                         AS inicio_contenido,
       COUNT(*)                                      AS vistas,
       SUM((l.detalle ->> 'segundos')::int)          AS segundos_totales,
       ROUND(AVG((l.detalle ->> 'segundos')::int), 1) AS segundos_prom
  FROM log_actividad l
  JOIN publicacion p ON p.id_publicacion = (l.detalle ->> 'id_publicacion')::int
 WHERE l.tipo_evento = 'vista_publicacion'
   AND l.fecha_evento >= '2026-11-01' AND l.fecha_evento < '2026-12-01'
 GROUP BY p.id_publicacion, p.tipo_publicacion, p.contenido
 ORDER BY vistas DESC, segundos_totales DESC
 LIMIT 10;

/* ============================================================================
   BLOQUE C - Multimedia y preferencias (semiestructurado)
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- C11. Peso y características del contenido multimedia por tipo de publicación
-- Objetivo: dimensionar el almacenamiento y ver qué formatos se usan.
-- Técnica: JOIN, SUM/COUNT/AVG, campo JSON opcional (duracion_seg solo existe
--          en video y audio: AVG ignora los NULL), GROUP BY.
-- ---------------------------------------------------------------------------
SELECT p.tipo_publicacion,
       c.tipo_contenido,
       COUNT(*)                                          AS archivos,
       ROUND(SUM(c.tamano_kb) / 1024.0, 1)               AS total_mb,
       ROUND(AVG((c.metadatos ->> 'duracion_seg')::numeric), 0) AS duracion_prom_seg
  FROM contenido_multimedia c
  JOIN publicacion p ON p.id_publicacion = c.id_publicacion
 GROUP BY p.tipo_publicacion, c.tipo_contenido
 ORDER BY total_mb DESC;

-- ---------------------------------------------------------------------------
-- C12. Videos 1080p con subtítulos en inglés y su autor
-- Objetivo: ofrecer filtros de calidad/idioma en la biblioteca multimedia.
-- Técnica: @> sobre metadatos (GIN), LIKE sobre un campo JSON, JOIN x2.
-- ---------------------------------------------------------------------------
SELECT c.id_contenido, est.nombre || ' ' || est.apellido AS autor,
       c.metadatos ->> 'resolucion' AS resolucion,
       c.metadatos ->> 'subtitulos' AS subtitulos,
       (c.metadatos ->> 'duracion_seg')::int AS duracion_seg
  FROM contenido_multimedia c
  JOIN publicacion p  ON p.id_publicacion = c.id_publicacion
  JOIN estudiante est ON est.id_estudiante = p.id_autor
 WHERE c.tipo_contenido = 'VIDEO'
   AND c.metadatos @> '{"resolucion":"1080p"}'
   AND c.metadatos ->> 'subtitulos' LIKE '%en%'
 ORDER BY duracion_seg DESC;

-- ---------------------------------------------------------------------------
-- C13. Etiquetas de imágenes más usadas (arreglo JSON dentro del documento)
-- Objetivo: nube de etiquetas / temas populares.
-- Técnica: jsonb_array_elements_text (desanida el arreglo), COUNT, GROUP BY.
-- ---------------------------------------------------------------------------
SELECT t.etiqueta, COUNT(*) AS veces
  FROM contenido_multimedia c
 CROSS JOIN LATERAL jsonb_array_elements_text(c.metadatos -> 'etiquetas') AS t(etiqueta)
 WHERE c.tipo_contenido = 'IMAGEN'
 GROUP BY t.etiqueta
 ORDER BY veces DESC, t.etiqueta;

-- ---------------------------------------------------------------------------
-- C14. Estudiantes a quienes enviar el resumen semanal por correo
-- Objetivo: segmentar notificaciones según preferencias JSON anidadas.
-- Técnica: @> con objeto anidado, jsonb_path_exists, JOIN x3, COUNT por programa.
-- ---------------------------------------------------------------------------
SELECT pr.nombre_programa,
       COUNT(*) AS destinatarios,
       COUNT(*) FILTER (WHERE pf.preferencias ->> 'tema' = 'oscuro') AS con_tema_oscuro
  FROM perfil pf
  JOIN estudiante est ON est.id_estudiante = pf.id_estudiante
  JOIN programa pr    ON pr.id_programa = est.id_programa
 WHERE pf.preferencias @> '{"notificaciones":{"resumen_semanal":true}}'
   AND NOT jsonb_path_exists(pf.preferencias, '$.privacidad ? (@.perfil_publico == false)')
 GROUP BY pr.nombre_programa
 ORDER BY destinatarios DESC;

/* ============================================================================
   BLOQUE D - Modificación de datos JSON (INSERT / UPDATE / DELETE)
   Se ejecuta dentro de una transacción con ROLLBACK para no alterar la demo.
   ============================================================================ */
BEGIN;

-- D1. Agregar una clave nueva al JSON sin cambiar el esquema (jsonb_set y ||)
UPDATE perfil
   SET preferencias = jsonb_set(preferencias, '{notificaciones,push}', 'false'::jsonb)
                      || '{"accesibilidad":{"alto_contraste":true}}'::jsonb
 WHERE id_estudiante = 1
RETURNING id_estudiante, preferencias;

-- D2. Cambiar el umbral de CO2 de un sensor (modifica solo esa clave anidada)
UPDATE dispositivo_iot
   SET configuracion = jsonb_set(configuracion, '{umbrales,co2_ppm}', '800')
 WHERE codigo_serie = 'AMB-006'
RETURNING codigo_serie, configuracion -> 'umbrales' AS umbrales;

-- D3. Eliminar una clave del JSON (operador -)
UPDATE perfil SET preferencias = preferencias - 'privacidad' WHERE preferencias ? 'privacidad';

-- D4. Insertar una lectura: el trigger actualiza espacio.datos_iot y crea la alerta
INSERT INTO lectura_iot (id_dispositivo, fecha_lectura, payload)
VALUES ((SELECT id_dispositivo FROM dispositivo_iot WHERE codigo_serie = 'AMB-003'),
        '2026-11-22 11:00', '{"temperatura_c":26.0,"humedad_pct":50.2,"co2_ppm":2300}')
RETURNING id_lectura, id_dispositivo, payload;

SELECT tipo_alerta, severidad, detalle FROM alerta_iot WHERE fecha_alerta = '2026-11-22 11:00';

-- D5. Retención de datos: borrar logs anteriores a una fecha (política de 30 días)
WITH borrados AS (DELETE FROM log_actividad WHERE fecha_evento < '2026-10-22' RETURNING 1)
SELECT COUNT(*) AS logs_eliminados FROM borrados;

ROLLBACK;   -- se revierte todo lo anterior

/* ============================================================================
   BLOQUE E - Optimización: evidencia con EXPLAIN
   ============================================================================ */

-- E1. Poda de particiones: solo debe leerse lectura_iot_2026_11 (las demás aparecen
--     como "never executed" o no aparecen en el plan).
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT COUNT(*) FROM lectura_iot
 WHERE fecha_lectura >= '2026-11-10' AND fecha_lectura < '2026-11-11';

-- E2. Índice GIN: búsqueda por contenido del JSONB (con la tabla grande de lecturas).
--     El plan debe mostrar "Bitmap Index Scan ... payload_idx" en cada partición con datos.
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT COUNT(*) FROM lectura_iot
 WHERE payload @> '{"accion":"ENTRADA","id_estudiante":7}';

-- E3. Contraste: la misma condición escrita con ->> NO puede usar el índice GIN
--     y obliga a leer (Seq Scan) todas las particiones. Por eso se prefiere @>.
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT COUNT(*) FROM lectura_iot
 WHERE payload ->> 'accion' = 'ENTRADA' AND payload ->> 'id_estudiante' = '7';
