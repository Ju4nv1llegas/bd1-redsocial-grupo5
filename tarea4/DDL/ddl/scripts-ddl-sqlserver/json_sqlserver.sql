/* Demostración de los tipos semiestructurados (JSON) - SQL Server
   Ejecutar DESPUÉS de crear la estructura con el script DDL de SQL Server.
   Caso de uso: IoT (sensores de ocupación y clima por aula) y metadatos flexibles de publicaciones (big data). */
USE red_social_pascualina;
GO

-- 1. Datos mínimos para poder insertar (claves foráneas)
INSERT INTO red_social.facultad (nombre_facultad) VALUES ('Facultad de Ingeniería');
INSERT INTO red_social.programa (id_facultad, nombre_programa) VALUES (1, 'Tecnología en Desarrollo de Software');
INSERT INTO red_social.estudiante (id_programa, codigo_estudiante, nombre, apellido, email, contrasena_hash, semestre)
VALUES (1, '20261001', 'Juan Camilo', 'Villegas Ocampo', 'juan@pascualbravo.edu.co', 'hash_de_ejemplo', 3);
INSERT INTO red_social.sede (nombre_sede, direccion) VALUES ('Sede Robledo', 'Calle 73 # 73A-226, Medellín');

-- 2. IoT: el aula guarda la última lectura de sus sensores como documento JSON
INSERT INTO red_social.espacio (id_sede, nombre_espacio, bloque, capacidad, datos_iot)
VALUES (1, 'Aula 301', '7A', 40, N'{"sensor_id":"ESP32-301","lectura":"2026-10-20T10:15:00","temperatura_c":24.5,"humedad_pct":58,"co2_ppm":612,"ocupacion":{"personas":18,"aforo_pct":45},"alertas":[]}');

-- 3. Big data: la publicación guarda metadatos de forma flexible (etiquetas, adjuntos, geoubicación GeoJSON)
INSERT INTO red_social.publicacion (id_autor, contenido, tipo_publicacion, metadatos)
VALUES (1, 'Comparto la guía de normalización', 'RECURSO', N'{"etiquetas":["sql","normalizacion"],"adjuntos":[{"tipo":"PDF","url":"https://ejemplo.edu.co/guia.pdf","kb":820}],"geoubicacion":{"type":"Point","coordinates":[-75.5905,6.2796]}}');
GO

-- 4. Consultas sobre el contenido JSON
SELECT nombre_espacio,
       JSON_VALUE(datos_iot, '$.temperatura_c')                   AS temperatura_c,
       CAST(JSON_VALUE(datos_iot, '$.ocupacion.personas') AS INT) AS personas
FROM red_social.espacio;

-- publicaciones con la etiqueta "sql"
SELECT id_publicacion, contenido
FROM red_social.publicacion
WHERE EXISTS (SELECT 1 FROM OPENJSON(metadatos, '$.etiquetas') WHERE value = 'sql');

-- modificar una sola clave del documento
UPDATE red_social.espacio SET datos_iot = JSON_MODIFY(datos_iot, '$.ocupacion.personas', 25) WHERE nombre_espacio = 'Aula 301';
SELECT JSON_QUERY(datos_iot, '$.ocupacion') AS ocupacion FROM red_social.espacio;
GO
