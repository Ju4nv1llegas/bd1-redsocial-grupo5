/* Demostración de los tipos semiestructurados (JSON) - MySQL
   Ejecutar DESPUÉS de crear la estructura con el script DDL de MySQL.
   Caso de uso: IoT (sensores de ocupación y clima por aula) y metadatos flexibles de publicaciones (big data). */
USE red_social_pascualina;

-- 1. Datos mínimos para poder insertar (claves foráneas)
INSERT INTO facultad (nombre_facultad) VALUES ('Facultad de Ingeniería');
INSERT INTO programa (id_facultad, nombre_programa) VALUES (1, 'Tecnología en Desarrollo de Software');
INSERT INTO estudiante (id_programa, codigo_estudiante, nombre, apellido, email, contrasena_hash, semestre)
VALUES (1, '20261001', 'Juan Camilo', 'Villegas Ocampo', 'juan@pascualbravo.edu.co', 'hash_de_ejemplo', 3);
INSERT INTO sede (nombre_sede, direccion) VALUES ('Sede Robledo', 'Calle 73 # 73A-226, Medellín');

-- 2. IoT: el aula guarda la última lectura de sus sensores como documento JSON
INSERT INTO espacio (id_sede, nombre_espacio, bloque, capacidad, datos_iot)
VALUES (1, 'Aula 301', '7A', 40, '{"sensor_id":"ESP32-301","lectura":"2026-10-20T10:15:00","temperatura_c":24.5,"humedad_pct":58,"co2_ppm":612,"ocupacion":{"personas":18,"aforo_pct":45},"alertas":[]}');

-- 3. Big data: la publicación guarda metadatos de forma flexible (etiquetas, adjuntos, geoubicación GeoJSON)
INSERT INTO publicacion (id_autor, contenido, tipo_publicacion, metadatos)
VALUES (1, 'Comparto la guía de normalización', 'RECURSO', '{"etiquetas":["sql","normalizacion"],"adjuntos":[{"tipo":"PDF","url":"https://ejemplo.edu.co/guia.pdf","kb":820}],"geoubicacion":{"type":"Point","coordinates":[-75.5905,6.2796]}}');

-- 4. Consultas sobre el contenido JSON
SELECT nombre_espacio,
       datos_iot->>'$.temperatura_c'                       AS temperatura_c,
       CAST(datos_iot->>'$.ocupacion.personas' AS UNSIGNED) AS personas
FROM espacio;

-- publicaciones con la etiqueta "sql"
SELECT id_publicacion, contenido FROM publicacion WHERE JSON_CONTAINS(metadatos->'$.etiquetas', '"sql"');

-- modificar una sola clave del documento
UPDATE espacio SET datos_iot = JSON_SET(datos_iot, '$.ocupacion.personas', 25) WHERE id_espacio = 1;
SELECT datos_iot->'$.ocupacion' AS ocupacion FROM espacio;
