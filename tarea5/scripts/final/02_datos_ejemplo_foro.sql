/* ============================================================================
   Red Social Estudiantil Pascualina - Datos de ejemplo para el foro (PostgreSQL)
   Bases de Datos I - G100 (SD1006) - Autor: Juan Camilo Villegas Ocampo

   ATENCION: este script VACIA las 25 tablas del esquema red_social (TRUNCATE) y
   luego inserta datos de ejemplo inventados (nombres, correos y publicaciones
   ficticios). Sirve solo para probar consultas. Ejecutar con F5 sin seleccionar.
   ============================================================================ */

SET search_path TO red_social;

-- 0. Vaciar todas las tablas y reiniciar los contadores (ids desde 1)
TRUNCATE facultad, sede, interes, habilidad, materia, profesor, recurso_academico,
         programa, espacio, curso, estudiante, perfil, estudiante_interes,
         estudiante_habilidad, seguimiento, mentoria, publicacion, comentario,
         reaccion, grupo_estudio, miembro_grupo, evento, participacion_evento,
         acceso_recurso, matricula
RESTART IDENTITY CASCADE;

-- 1. Catalogos academicos
INSERT INTO facultad (nombre_facultad) VALUES
 ('Facultad de Ingeniería'), ('Facultad de Producción y Diseño'), ('Facultad de Administración');

INSERT INTO programa (id_facultad, nombre_programa) VALUES
 (1, 'Tecnología en Desarrollo de Software'),
 (1, 'Ingeniería Informática'),
 (2, 'Diseño Industrial'),
 (3, 'Administración de Empresas');

INSERT INTO sede (nombre_sede, direccion) VALUES
 ('Sede Robledo', 'Calle 73 # 73A-226, Medellín'),
 ('Sede Centro',  'Carrera 50 # 40-20, Medellín');

INSERT INTO espacio (id_sede, nombre_espacio, bloque, capacidad, datos_iot) VALUES
 (1, 'Aula 301',   '7A', 40, '{"sensor_id":"ESP32-301","temperatura_c":24.5,"co2_ppm":612,"ocupacion":{"personas":18,"aforo_pct":45}}'::jsonb),
 (1, 'Laboratorio 205', '3B', 30, NULL),
 (2, 'Auditorio Central', '1A', 120, NULL);

INSERT INTO materia (codigo_materia, nombre_materia, creditos) VALUES
 ('SD1006', 'Bases de Datos I', 3),
 ('SD1001', 'Programación I', 4),
 ('SD2003', 'Ingeniería de Software', 3),
 ('MA1001', 'Cálculo Diferencial', 3);

INSERT INTO profesor (nombre, apellido, email) VALUES
 ('Oralia', 'Cortez Grajales', 'ocortez@ejemplo.edu.co'),
 ('Ricardo', 'Montoya Vélez', 'rmontoya@ejemplo.edu.co'),
 ('Diana', 'Arbeláez Cano', 'darbelaez@ejemplo.edu.co');

INSERT INTO curso (id_materia, id_profesor, id_espacio, periodo, codigo_grupo) VALUES
 (1, 1, 1, '2026-2', 'G100'),
 (2, 2, 2, '2026-2', 'G200'),
 (3, 3, 1, '2026-2', 'G100'),
 (4, 2, 3, '2026-2', 'G300'),
 (1, 1, 2, '2026-1', 'G100');

-- 2. Estudiantes (datos ficticios)
INSERT INTO estudiante (id_programa, codigo_estudiante, nombre, apellido, email, contrasena_hash, semestre, estado) VALUES
 (1, '20261001', 'Juan Camilo',  'Villegas Ocampo', 'juan@pascualbravo.edu.co',     'hash_ejemplo_1', 3, 'ACTIVO'),
 (1, '20261002', 'Laura',        'Gómez Restrepo',  'laura.gomez@ejemplo.edu.co',   'hash_ejemplo_2', 5, 'ACTIVO'),
 (2, '20261003', 'Andrés',       'Pérez Londoño',   'andres.perez@ejemplo.edu.co',  'hash_ejemplo_3', 7, 'ACTIVO'),
 (2, '20261004', 'Valentina',    'Ríos Mejía',      'valentina.rios@ejemplo.edu.co','hash_ejemplo_4', 2, 'ACTIVO'),
 (3, '20261005', 'Santiago',     'Henao Zapata',    'santiago.henao@ejemplo.edu.co','hash_ejemplo_5', 4, 'ACTIVO'),
 (3, '20261006', 'Camila',       'Torres Arango',   'camila.torres@ejemplo.edu.co', 'hash_ejemplo_6', 6, 'ACTIVO'),
 (4, '20261007', 'Mateo',        'Cardona Salazar', 'mateo.cardona@ejemplo.edu.co', 'hash_ejemplo_7', 1, 'ACTIVO'),
 (4, '20261008', 'Sofía',        'Duque Marín',     'sofia.duque@ejemplo.edu.co',   'hash_ejemplo_8', 8, 'ACTIVO');

INSERT INTO perfil (id_estudiante, biografia, ciudad) VALUES
 (1, 'Estudiante de software, me gustan las bases de datos.', 'Medellín'),
 (2, 'Monitora de programación.', 'Bello'),
 (3, 'Me interesa la inteligencia artificial.', 'Envigado');

INSERT INTO matricula (id_estudiante, id_curso, fecha_matricula) VALUES
 (1, 1, '2026-07-20'), (1, 2, '2026-07-20'), (1, 5, '2026-01-22'),
 (2, 1, '2026-07-21'), (2, 3, '2026-07-21'),
 (3, 3, '2026-07-21'), (3, 4, '2026-07-22'),
 (4, 2, '2026-07-22'), (4, 4, '2026-07-22'),
 (5, 1, '2026-07-23'), (5, 4, '2026-07-23'),
 (6, 3, '2026-07-23'),
 (7, 2, '2026-07-24'),
 (8, 4, '2026-07-24');

-- 3. Intereses, habilidades, seguimiento y mentoria
INSERT INTO interes (nombre_interes, tipo, descripcion) VALUES
 ('Fútbol', 'DEPORTIVO', 'Partidos y torneos'), ('Videojuegos', 'OCIO', NULL),
 ('Programación', 'TECNOLOGICO', 'Desarrollo de software'), ('Música', 'CULTURAL', NULL);
INSERT INTO estudiante_interes (id_estudiante, id_interes) VALUES
 (1, 3), (1, 2), (2, 3), (3, 3), (3, 1), (5, 4), (6, 4);

INSERT INTO habilidad (nombre_habilidad, descripcion) VALUES
 ('SQL', 'Consultas y modelado'), ('Python', NULL), ('Diseño gráfico', NULL), ('Excel', NULL);
INSERT INTO estudiante_habilidad (id_estudiante, id_habilidad, nivel) VALUES
 (1, 1, 'INTERMEDIO'), (2, 1, 'AVANZADO'), (3, 2, 'AVANZADO'), (3, 1, 'INTERMEDIO'), (6, 3, 'AVANZADO');

INSERT INTO seguimiento (id_seguidor, id_seguido) VALUES (1, 2), (1, 3), (2, 1), (4, 2), (5, 6);
INSERT INTO mentoria (id_mentor, id_aprendiz, id_materia, estado) VALUES
 (2, 1, 1, 'ACTIVA'), (3, 4, 2, 'SOLICITADA');

-- 4. Publicaciones, comentarios y reacciones
INSERT INTO publicacion (id_autor, contenido, tipo_publicacion, metadatos) VALUES
 (1, 'Comparto la guía de normalización',                 'RECURSO',  '{"etiquetas":["sql","normalizacion"]}'::jsonb),
 (2, '¿Alguien tiene resueltos los ejercicios de joins?', 'PREGUNTA', NULL),
 (3, 'Abrieron inscripciones al hackatón',                'NOTICIA',  NULL),
 (2, 'Resumen de claves primarias y foráneas',            'RECURSO',  NULL),
 (1, '¿Cómo se usa GROUP BY con HAVING?',                 'PREGUNTA', NULL),
 (6, 'Se cambió el salón de la tutoría del jueves',       'AVISO',    NULL),
 (3, 'Tutorial de PostgreSQL para principiantes',         'RECURSO',  NULL),
 (5, 'Cuando olvidas el WHERE en un DELETE',              'MEME',     NULL),
 (2, '¿Quién forma grupo para el parcial?',               'PREGUNTA', NULL),
 (3, '¿Qué diferencia hay entre JSON y JSONB?',           'PREGUNTA', NULL),
 (6, 'Plantillas de prototipos para diseño',              'RECURSO',  NULL),
 (5, '¿Dónde consigo referencias de materiales?',         'PREGUNTA', NULL);

INSERT INTO comentario (id_publicacion, id_autor, contenido) VALUES
 (2, 1, 'Yo tengo algunos, te los paso.'), (2, 3, 'Revisa la guía de la clase.'),
 (5, 2, 'HAVING filtra después de agrupar.'), (5, 3, 'Se usa con funciones como COUNT.'),
 (9, 1, 'Yo me apunto.'), (10, 2, 'JSONB es binario y se puede indexar.');

INSERT INTO reaccion (id_estudiante, id_publicacion, tipo_reaccion) VALUES
 (2, 1, 'UTIL'), (3, 1, 'ME_GUSTA'), (6, 1, 'UTIL'), (5, 1, 'ME_GUSTA'),            -- publicacion 1: 4
 (1, 2, 'ME_GUSTA'),                                                                 -- publicacion 2: 1
 (1, 3, 'ME_GUSTA'), (2, 3, 'ME_ENCANTA'),                                           -- publicacion 3: 2
 (1, 4, 'UTIL'), (3, 4, 'UTIL'), (6, 4, 'ME_GUSTA'),                                 -- publicacion 4: 3
 (2, 5, 'ME_GUSTA'),                                                                 -- publicacion 5: 1
 (2, 7, 'UTIL'), (1, 7, 'UTIL'), (5, 7, 'ME_GUSTA'), (6, 7, 'UTIL'), (4, 7, 'ME_GUSTA'), -- publicacion 7: 5
 (1, 8, 'ME_DIVIERTE'), (2, 8, 'ME_DIVIERTE'), (3, 8, 'ME_DIVIERTE'),
 (8, 8, 'ME_DIVIERTE'), (7, 8, 'ME_DIVIERTE'), (4, 8, 'ME_DIVIERTE');                -- publicacion 8: 6

-- 5. Grupos y eventos
INSERT INTO grupo_estudio (id_creador, id_materia, nombre_grupo, descripcion, tipo, es_privado) VALUES
 (2, 1, 'Parcial Bases de Datos I', 'Preparación del parcial', 'ESTUDIO', FALSE),
 (6, NULL, 'Club de Diseño', 'Proyectos de diseño industrial', 'CLUB', TRUE);
INSERT INTO miembro_grupo (id_grupo, id_estudiante, rol) VALUES
 (1, 2, 'ADMIN'), (1, 1, 'MIEMBRO'), (1, 5, 'MIEMBRO'), (2, 6, 'ADMIN'), (2, 5, 'MIEMBRO');

INSERT INTO evento (id_organizador, id_grupo, id_espacio, titulo, descripcion, fecha_inicio, fecha_cierre, modalidad) VALUES
 (1, 1,    1,    'Taller de SQL',           'Repaso de consultas',     '2026-11-05 14:00', '2026-11-05 16:00', 'PRESENCIAL'),
 (3, NULL, 3,    'Hackatón Pascualina',     'Maratón de programación', '2026-11-12 08:00', '2026-11-12 18:00', 'HIBRIDA'),
 (6, 2,    NULL, 'Charla de prototipado',   'Sesión virtual',          '2026-11-19 18:00', '2026-11-19 19:30', 'VIRTUAL');
INSERT INTO participacion_evento (id_estudiante, id_evento, estado) VALUES
 (1, 1, 'ASISTIO'), (2, 1, 'ASISTIO'), (4, 1, 'ASISTIO'), (7, 1, 'INSCRITO'),
 (3, 2, 'INSCRITO'), (5, 2, 'CANCELADO'), (8, 2, 'ASISTIO'),
 (2, 3, 'INSCRITO'), (6, 3, 'INSCRITO'), (4, 3, 'INSCRITO');

-- 6. Recursos
INSERT INTO recurso_academico (titulo, url, tipo_archivo) VALUES
 ('Guía de normalización', 'https://ejemplo.edu.co/normalizacion.pdf', 'PDF'),
 ('Introducción a PostgreSQL', 'https://ejemplo.edu.co/postgres', 'VIDEO');
INSERT INTO acceso_recurso (id_estudiante, id_recurso) VALUES (1, 1), (2, 1), (3, 2);
