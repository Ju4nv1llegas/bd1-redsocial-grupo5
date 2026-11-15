/* =============================================================================
   Red Social Estudiantil Pascualina - Sistema de consultas (DML) y vistas
   SGBD ........ PostgreSQL 16 (compatible con 13 o superior)
   Curso ....... Bases de Datos I - G100 (SD1006) - Tarea S1, Unidad 3
   Autor ....... Juan Camilo Villegas Ocampo (Grupo 5)
   Version ..... FINAL. Parte de las 4 consultas del foro (scripts/borrador/consultas_foro.sql)
                 y las amplia a 11 consultas, 6 vistas y 3 operaciones de escritura.
   Requiere .... 01_ddl_postgresql.sql (modelo fisico de la Tarea 4), 02_datos_ejemplo_foro.sql
                 y 03_datos_ampliados.sql ya ejecutados, en ese orden.

   Contenido
     A. Vistas ........... V1 a V6 (CREATE OR REPLACE VIEW)
     B. Consultas ........ C1 a C11 (SELECT sobre las tablas del modelo fisico; C9 y C10
                           consultan las columnas JSONB de la Tarea 4)
     C. Uso de las vistas  U1 y U2 (consultas que reutilizan las vistas)
     D. Escritura ........ E1 a E3 (INSERT, UPDATE y DELETE dentro de una
                           transaccion que termina en ROLLBACK: no alteran los datos)

   Reglas de nomenclatura para los datos calculados (ALIAS)
     R1. Todo alias se escribe con AS y sin comillas dobles.
     R2. minusculas, snake_case, sin tildes, enie ni espacios (igual que el DDL).
     R3. El prefijo indica el tipo de calculo:
           total_     conteos y sumas ............ total_publicaciones
           promedio_  promedios .................. promedio_miembros_grupo
           pct_       porcentajes de 0 a 100 ..... pct_asistencia
           dias_      diferencias en dias ........ dias_sin_actividad
           lista_     textos concatenados ........ lista_intereses
           puntaje_   indices compuestos ......... puntaje_participacion
           posicion_  resultado de funciones de ventana ... posicion_ranking
           categoria_ clasificaciones con CASE ... categoria_interaccion
           nombre_    concatenacion de nombres ... nombre_completo
           medida_    lecturas de sensores (JSON) .. medida_co2_ppm
     R4. Un alias nunca repite el nombre de una columna de las tablas consultadas.
     R5. Un alias no supera 30 caracteres y dice QUE se calcula, no COMO.
     R6. Alias de tabla: abreviatura de 1 a 3 letras (e = estudiante, pu = publicacion).
     R7. Textos derivados o renombrados: sustantivo + rol (programa_autor,
         lugar_evento, materia_asociada). Parametros de CTE: nombre del parametro
         (fecha_corte, id_referencia).
     R8. En una subconsulta de apoyo el conteo se llama total; la consulta externa
         lo renombra con su alias definitivo segun R3.

   Fecha de corte: las consultas con tiempo usan DATE '2026-11-14' (fecha de la
   entrega) en lugar de CURRENT_DATE para que los resultados sean reproducibles.
   ============================================================================= */

SET client_encoding = 'UTF8';                                 -- el cliente envia y recibe texto en UTF-8 (tildes y enes)
SET search_path TO red_social;                                -- usa el esquema red_social sin escribir el prefijo en cada tabla

/* NOTA SOBRE pgAdmin: el Query Tool envia el script completo como UN SOLO LOTE, y PostgreSQL
   lo ejecuta como una sola transaccion. Si mas abajo un ROLLBACK (secciones E1 a E3) encuentra
   las vistas y el SET anteriores en esa misma transaccion, tambien los deshace. Por eso hay un
   COMMIT aqui y otro justo antes de cada BEGIN. En psql, o con el script ya confirmado, cada
   COMMIT solo genera un aviso inofensivo ("no hay una transaccion en curso"). */
COMMIT;                                                       -- confirma lo anterior (ver la nota sobre pgAdmin)


/* #############################################################################
   A. VISTAS
   ############################################################################# */

/* -----------------------------------------------------------------------------
   V1. v_perfil_estudiante
   Objetivo ..... Consolidar el perfil publico de cada estudiante con su programa,
                  facultad, ciudad, intereses y habilidades. Facilita buscar
                  companeros o mentores sin repetir cinco JOIN en cada consulta.
   Tablas ....... estudiante, programa, facultad, perfil, estudiante_interes,
                  interes, estudiante_habilidad, habilidad
   Nota ......... No expone contrasena_hash (la vista tambien protege datos).
   ----------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW v_perfil_estudiante AS                                                   -- crea (o reemplaza) la vista del perfil consolidado del estudiante
SELECT e.id_estudiante,                                                                         -- identificador del estudiante
       e.codigo_estudiante,                                                                     -- codigo institucional (la vista no expone la contrasena)
       e.nombre || ' ' || e.apellido                       AS nombre_completo,                  -- nombre y apellido unidos con un espacio (R3: nombre_)
       p.nombre_programa,                                                                       -- programa academico del estudiante
       f.nombre_facultad,                                                                       -- facultad a la que pertenece el programa
       e.semestre,                                                                              -- semestre que cursa
       e.estado,                                                                                -- estado de la cuenta: ACTIVO, INACTIVO o SUSPENDIDO
       pf.ciudad,                                                                               -- ciudad del perfil (NULL si todavia no lo llena)
       COALESCE(ei.total_intereses, 0)                     AS total_intereses,                  -- cantidad de intereses; COALESCE cambia el NULL por 0
       COALESCE(ei.lista_intereses, 'Sin intereses')       AS lista_intereses,                  -- intereses en una sola celda; 'Sin intereses' si no tiene
       COALESCE(eh.total_habilidades, 0)                   AS total_habilidades,                -- cantidad de habilidades; 0 si no tiene
       COALESCE(eh.total_avanzadas, 0)                     AS total_habilidades_avanzadas,      -- cuantas habilidades tiene en nivel AVANZADO
       COALESCE(eh.lista_habilidades, 'Sin habilidades')   AS lista_habilidades                 -- habilidades con su nivel entre parentesis; texto fijo si no tiene
FROM estudiante AS e                                                                            -- tabla base: una fila por estudiante
JOIN programa AS p ON p.id_programa = e.id_programa                                             -- programa del estudiante (JOIN interno: siempre existe)
JOIN facultad AS f ON f.id_facultad = p.id_facultad                                             -- facultad del programa
LEFT JOIN perfil AS pf ON pf.id_estudiante = e.id_estudiante                                    -- perfil opcional: el LEFT JOIN conserva a quien no lo ha llenado
LEFT JOIN (SELECT x.id_estudiante,                                                              -- subconsulta de intereses: una fila por estudiante (evita multiplicar filas)
                  COUNT(*)                                          AS total_intereses,         -- total de intereses del estudiante
                  STRING_AGG(i.nombre_interes, ', '                                             -- une los nombres de los intereses separados por coma...
                             ORDER BY i.nombre_interes)             AS lista_intereses          -- ...en orden alfabetico
           FROM estudiante_interes AS x                                                         -- tabla intermedia estudiante-interes
           JOIN interes AS i ON i.id_interes = x.id_interes                                     -- nombre de cada interes
           GROUP BY x.id_estudiante) AS ei ON ei.id_estudiante = e.id_estudiante                -- agrupa por estudiante y une la subconsulta con la principal
LEFT JOIN (SELECT y.id_estudiante,                                                              -- subconsulta de habilidades: tambien una fila por estudiante
                  COUNT(*)                                          AS total_habilidades,       -- total de habilidades
                  COUNT(*) FILTER (WHERE y.nivel = 'AVANZADO')      AS total_avanzadas,         -- cuenta solo las de nivel AVANZADO
                  STRING_AGG(h.nombre_habilidad || ' (' || LOWER(y.nivel) || ')', ', '          -- lista 'Habilidad (nivel)' separada por coma...
                             ORDER BY h.nombre_habilidad)           AS lista_habilidades        -- ...en orden alfabetico
           FROM estudiante_habilidad AS y                                                       -- tabla intermedia estudiante-habilidad
           JOIN habilidad AS h ON h.id_habilidad = y.id_habilidad                               -- nombre de cada habilidad
           GROUP BY y.id_estudiante) AS eh ON eh.id_estudiante = e.id_estudiante;               -- agrupa por estudiante y une la subconsulta con la principal

COMMENT ON VIEW v_perfil_estudiante IS                                                          -- documenta la vista dentro del catalogo de PostgreSQL
    'Perfil consolidado: programa, facultad, ciudad, intereses y habilidades por estudiante.';  -- texto de la descripcion de la vista

/* Consulta de comprobacion de V1: perfiles de estudiantes con una habilidad avanzada */
SELECT id_estudiante, nombre_completo, semestre,                                                -- identificacion, nombre y semestre
       total_habilidades_avanzadas, lista_habilidades                                           -- habilidades avanzadas y lista completa de habilidades
FROM v_perfil_estudiante                                                                        -- consulta a la vista, no a las ocho tablas de origen
WHERE total_habilidades_avanzadas > 0                                                           -- solo quienes tienen al menos una habilidad avanzada
ORDER BY total_habilidades_avanzadas DESC, id_estudiante                                        -- primero quienes tienen mas habilidades avanzadas
LIMIT 8;                                                                                        -- muestra solo 8 filas


/* -----------------------------------------------------------------------------
   V2. v_actividad_publicacion
   Objetivo ..... Medir cuanta interaccion genera cada publicacion (reacciones y
                  comentarios) y clasificarla. Es la base para saber que tipo de
                  contenido funciona mejor en la red.
   Tablas ....... publicacion, estudiante, programa, reaccion, comentario
   Nota ......... Reacciones y comentarios se agregan por separado y luego se
                  unen: un JOIN directo de ambas multiplicaria los conteos.
   ----------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW v_actividad_publicacion AS                                                     -- crea (o reemplaza) la vista con la interaccion de cada publicacion
SELECT pu.id_publicacion,                                                                             -- identificador de la publicacion
       pu.tipo_publicacion,                                                                           -- tipo: PREGUNTA, RECURSO, NOTICIA, AVISO o MEME
       pu.fecha_creacion,                                                                             -- momento en que se publico
       a.id_estudiante                                           AS id_autor_publicacion,             -- id del autor (alias R7: id + rol, para no repetir id_estudiante)
       a.nombre || ' ' || a.apellido                             AS nombre_autor,                     -- nombre completo del autor
       p.nombre_programa                                         AS programa_autor,                   -- programa academico del autor
       COALESCE(r.total_reacciones, 0)                           AS total_reacciones,                 -- reacciones recibidas; 0 si no tiene
       COALESCE(r.total_reacciones_utiles, 0)                    AS total_reacciones_utiles,          -- reacciones de tipo UTIL; 0 si no tiene
       COALESCE(c.total_comentarios, 0)                          AS total_comentarios,                -- comentarios recibidos; 0 si no tiene
       COALESCE(r.total_reacciones, 0)                                                                -- interacciones = reacciones + comentarios (primer sumando)...
         + COALESCE(c.total_comentarios, 0)                      AS total_interacciones,              -- ...(segundo sumando)
       CASE                                                                                           -- clasifica la publicacion segun sus interacciones
           WHEN COALESCE(r.total_reacciones, 0) + COALESCE(c.total_comentarios, 0) >= 8 THEN 'ALTA'   -- 8 o mas interacciones: ALTA
           WHEN COALESCE(r.total_reacciones, 0) + COALESCE(c.total_comentarios, 0) >= 3 THEN 'MEDIA'  -- de 3 a 7: MEDIA
           ELSE 'BAJA'                                                                                -- menos de 3: BAJA
       END                                                       AS categoria_interaccion             -- fin del CASE; la columna se llama categoria_interaccion
FROM publicacion AS pu                                                                                -- tabla base: una fila por publicacion
JOIN estudiante AS a ON a.id_estudiante = pu.id_autor                                                 -- autor de la publicacion
JOIN programa AS p ON p.id_programa = a.id_programa                                                   -- programa del autor
LEFT JOIN (SELECT id_publicacion,                                                                     -- subconsulta de reacciones: una fila por publicacion (evita multiplicar filas)
                  COUNT(*)                                       AS total_reacciones,                 -- total de reacciones
                  COUNT(*) FILTER (WHERE tipo_reaccion = 'UTIL') AS total_reacciones_utiles           -- total de reacciones de tipo UTIL
           FROM reaccion                                                                              -- tabla de reacciones
           GROUP BY id_publicacion) AS r ON r.id_publicacion = pu.id_publicacion                      -- agrupa por publicacion y une con la consulta principal
LEFT JOIN (SELECT id_publicacion, COUNT(*) AS total_comentarios                                       -- subconsulta de comentarios: una fila por publicacion
           FROM comentario                                                                            -- tabla de comentarios
           GROUP BY id_publicacion) AS c ON c.id_publicacion = pu.id_publicacion;                     -- agrupa por publicacion y une con la consulta principal

COMMENT ON VIEW v_actividad_publicacion IS                                                            -- documenta la vista dentro del catalogo de PostgreSQL
    'Reacciones, comentarios y categoria de interaccion de cada publicacion.';                        -- texto de la descripcion de la vista

/* Consulta de comprobacion de V2: cuantas publicaciones hay por categoria */
SELECT categoria_interaccion,                                                                         -- categoria de interaccion que entrega la vista
       COUNT(*)                          AS total_publicaciones,                                      -- cuantas publicaciones hay en cada categoria
       ROUND(AVG(total_interacciones), 1) AS promedio_interacciones                                   -- interacciones promedio, con un decimal
FROM v_actividad_publicacion                                                                          -- consulta a la vista
GROUP BY categoria_interaccion                                                                        -- una fila por categoria
ORDER BY promedio_interacciones DESC;                                                                 -- primero la categoria con mas interaccion


/* -----------------------------------------------------------------------------
   V3. v_evento_asistencia
   Objetivo ..... Resumir cada evento: quien lo organiza, a que grupo pertenece,
                  donde se realiza, cuantos se inscribieron y cuantos asistieron.
                  Permite planear espacios y medir el exito de las actividades.
   Tablas ....... evento, estudiante, grupo_estudio, espacio, sede,
                  participacion_evento
   Nota ......... estado_evento usa CURRENT_TIMESTAMP, asi que la vista siempre
                  refleja el momento en que se consulta.
   ----------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW v_evento_asistencia AS                                                         -- crea (o reemplaza) la vista con el resumen de cada evento
SELECT ev.id_evento,                                                                                  -- identificador del evento
       ev.titulo,                                                                                     -- titulo del evento
       ev.modalidad,                                                                                  -- PRESENCIAL, VIRTUAL o HIBRIDA
       ev.fecha_inicio,                                                                               -- cuando empieza el evento
       o.nombre || ' ' || o.apellido                              AS nombre_organizador,              -- nombre completo del organizador
       COALESCE(g.nombre_grupo, 'Sin grupo')                      AS grupo_organizador,               -- grupo organizador, o 'Sin grupo' si el evento es abierto
       COALESCE(se.nombre_sede || ' - ' || es.nombre_espacio, 'Virtual') AS lugar_evento,             -- 'sede - espacio', o 'Virtual' si el evento no tiene espacio
       es.capacidad                                               AS capacidad_espacio,               -- capacidad del espacio (NULL si es virtual)
       CASE WHEN ev.fecha_cierre < CURRENT_TIMESTAMP THEN 'FINALIZADO'                                -- si ya cerro (fecha y hora actuales), el estado es FINALIZADO...
            ELSE 'PROGRAMADO' END                                 AS estado_evento,                   -- ...y si no, PROGRAMADO
       COUNT(pe.id_estudiante) FILTER (WHERE pe.estado <> 'CANCELADO')  AS total_inscritos_vigentes,  -- inscritos que no cancelaron
       COUNT(pe.id_estudiante) FILTER (WHERE pe.estado = 'ASISTIO')     AS total_asistentes,          -- inscritos que asistieron
       COUNT(pe.id_estudiante) FILTER (WHERE pe.estado = 'CANCELADO')   AS total_cancelados,          -- inscripciones canceladas
       CASE WHEN ev.fecha_cierre < CURRENT_TIMESTAMP                                                  -- el porcentaje solo se calcula en eventos finalizados
            THEN ROUND(100.0 * COUNT(pe.id_estudiante) FILTER (WHERE pe.estado = 'ASISTIO')           -- asistentes entre inscritos vigentes, por 100 (primera parte)...
                 / NULLIF(COUNT(pe.id_estudiante) FILTER (WHERE pe.estado <> 'CANCELADO'), 0), 1)     -- ...NULLIF evita dividir por cero; un decimal
       END                                                        AS pct_asistencia                   -- fin del CASE; en eventos futuros queda NULL
FROM evento AS ev                                                                                     -- tabla base: una fila por evento
JOIN estudiante AS o ON o.id_estudiante = ev.id_organizador                                           -- organizador del evento
LEFT JOIN grupo_estudio AS g ON g.id_grupo = ev.id_grupo                                              -- grupo opcional: LEFT JOIN conserva eventos sin grupo
LEFT JOIN espacio AS es ON es.id_espacio = ev.id_espacio                                              -- espacio opcional: los eventos virtuales no tienen
LEFT JOIN sede AS se ON se.id_sede = es.id_sede                                                       -- sede del espacio
LEFT JOIN participacion_evento AS pe ON pe.id_evento = ev.id_evento                                   -- inscripciones; LEFT JOIN conserva eventos sin inscritos
GROUP BY ev.id_evento, ev.titulo, ev.modalidad, ev.fecha_inicio, ev.fecha_cierre,                     -- agrupa por evento (las columnas no agregadas del SELECT)...
         o.nombre, o.apellido, g.nombre_grupo, se.nombre_sede, es.nombre_espacio,                     -- ...(continua la lista de agrupacion)...
         es.capacidad;                                                                                -- ...(fin de la lista)

COMMENT ON VIEW v_evento_asistencia IS                                                                -- documenta la vista dentro del catalogo de PostgreSQL
    'Eventos con organizador, lugar, inscritos, asistentes y porcentaje de asistencia.';              -- texto de la descripcion de la vista

/* Consulta de comprobacion de V3: eventos programados y su inscripcion actual */
SELECT id_evento, titulo, modalidad, lugar_evento,                                                    -- datos generales del evento
       total_inscritos_vigentes, capacidad_espacio                                                    -- inscritos actuales frente a la capacidad
FROM v_evento_asistencia                                                                              -- consulta a la vista
WHERE estado_evento = 'PROGRAMADO'                                                                    -- solo eventos que todavia no ocurren
ORDER BY fecha_inicio;                                                                                -- del mas proximo al mas lejano


/* -----------------------------------------------------------------------------
   V4. v_participacion_estudiante
   Objetivo ..... Medir el nivel de participacion de cada estudiante: lo que
                  publica, comenta, reacciona, sus seguidores, sus grupos y los
                  eventos a los que asiste, resumido en un puntaje.
   Puntaje ...... 3 x publicaciones + 2 x comentarios + 1 x reacciones
                  + 5 x eventos asistidos  (el peso refleja el esfuerzo).
   Tablas ....... estudiante, publicacion, comentario, reaccion, seguimiento,
                  miembro_grupo, participacion_evento
   ----------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW v_participacion_estudiante AS                                                       -- crea (o reemplaza) la vista con los indicadores de participacion
SELECT e.id_estudiante,                                                                                    -- identificador del estudiante
       e.nombre || ' ' || e.apellido                      AS nombre_completo,                              -- nombre completo
       e.id_programa,                                                                                      -- programa (se usa para agrupar en v_resumen_programa)
       e.semestre,                                                                                         -- semestre que cursa
       e.estado,                                                                                           -- estado de la cuenta
       COALESCE(pu.total, 0)                              AS total_publicaciones,                          -- publicaciones escritas; 0 si no tiene
       COALESCE(co.total, 0)                              AS total_comentarios,                            -- comentarios escritos
       COALESCE(re.total, 0)                              AS total_reacciones_dadas,                       -- reacciones que dio a publicaciones
       COALESCE(sr.total, 0)                              AS total_seguidores,                             -- seguidores: cuantos estudiantes lo siguen
       COALESCE(sg.total, 0)                              AS total_siguiendo,                              -- siguiendo: a cuantos estudiantes sigue
       COALESCE(mg.total, 0)                              AS total_grupos,                                 -- grupos a los que pertenece
       COALESCE(pe.total, 0)                              AS total_eventos_asistidos,                      -- eventos a los que asistio
       3 * COALESCE(pu.total, 0) + 2 * COALESCE(co.total, 0)                                               -- puntaje: 3 por publicacion y 2 por comentario...
         + COALESCE(re.total, 0) + 5 * COALESCE(pe.total, 0) AS puntaje_participacion                      -- ...1 por reaccion y 5 por evento asistido
FROM estudiante AS e                                                                                       -- tabla base: una fila por estudiante (incluye a quien no participa)
LEFT JOIN (SELECT id_autor AS id, COUNT(*) AS total FROM publicacion GROUP BY id_autor) AS pu              -- subconsulta: publicaciones por autor
       ON pu.id = e.id_estudiante                                                                          -- une el conteo con el estudiante
LEFT JOIN (SELECT id_autor AS id, COUNT(*) AS total FROM comentario GROUP BY id_autor) AS co               -- subconsulta: comentarios por autor
       ON co.id = e.id_estudiante                                                                          -- une el conteo con el estudiante
LEFT JOIN (SELECT id_estudiante AS id, COUNT(*) AS total FROM reaccion GROUP BY id_estudiante) AS re       -- subconsulta: reacciones dadas por estudiante
       ON re.id = e.id_estudiante                                                                          -- une el conteo con el estudiante
LEFT JOIN (SELECT id_seguido AS id, COUNT(*) AS total FROM seguimiento GROUP BY id_seguido) AS sr          -- subconsulta: seguidores (veces que aparece como seguido)
       ON sr.id = e.id_estudiante                                                                          -- une el conteo con el estudiante
LEFT JOIN (SELECT id_seguidor AS id, COUNT(*) AS total FROM seguimiento GROUP BY id_seguidor) AS sg        -- subconsulta: a cuantos sigue (veces que aparece como seguidor)
       ON sg.id = e.id_estudiante                                                                          -- une el conteo con el estudiante
LEFT JOIN (SELECT id_estudiante AS id, COUNT(*) AS total FROM miembro_grupo GROUP BY id_estudiante) AS mg  -- subconsulta: grupos por estudiante
       ON mg.id = e.id_estudiante                                                                          -- une el conteo con el estudiante
LEFT JOIN (SELECT id_estudiante AS id, COUNT(*) AS total FROM participacion_evento                         -- subconsulta: eventos con estado ASISTIO...
           WHERE estado = 'ASISTIO' GROUP BY id_estudiante) AS pe                                          -- ...agrupados por estudiante
       ON pe.id = e.id_estudiante;                                                                         -- une el conteo con el estudiante

COMMENT ON VIEW v_participacion_estudiante IS                                                              -- documenta la vista dentro del catalogo de PostgreSQL
    'Indicadores de participacion por estudiante y puntaje compuesto.';                                    -- texto de la descripcion de la vista

/* Consulta de comprobacion de V4: los 5 estudiantes con mas seguidores */
SELECT id_estudiante, nombre_completo, total_seguidores, total_siguiendo,                                  -- estudiante y sus seguidores
       puntaje_participacion                                                                               -- puntaje compuesto
FROM v_participacion_estudiante                                                                            -- consulta a la vista
ORDER BY total_seguidores DESC, id_estudiante                                                              -- primero los mas seguidos
LIMIT 5;                                                                                                   -- solo los 5 primeros


/* -----------------------------------------------------------------------------
   V5. v_resumen_programa   (vista construida sobre otra vista)
   Objetivo ..... Entregar a la direccion de cada programa y facultad un resumen
                  de su comunidad: estudiantes, actividad y participacion media.
                  Reutiliza v_participacion_estudiante en lugar de recalcular.
   Tablas ....... programa, facultad y la vista v_participacion_estudiante
   ----------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW v_resumen_programa AS                                                          -- crea (o reemplaza) la vista: resumen por programa, construida sobre V4
SELECT p.id_programa,                                                                                 -- identificador del programa
       f.nombre_facultad,                                                                             -- facultad del programa
       p.nombre_programa,                                                                             -- nombre del programa
       COUNT(vpt.id_estudiante)                                  AS total_estudiantes,                -- estudiantes del programa, en cualquier estado
       COUNT(*) FILTER (WHERE vpt.estado = 'ACTIVO')             AS total_estudiantes_activos,        -- solo los estudiantes activos
       ROUND(AVG(vpt.semestre), 1)                               AS promedio_semestre,                -- semestre promedio, con un decimal
       COALESCE(SUM(vpt.total_publicaciones), 0)                 AS total_publicaciones,              -- publicaciones de todos sus estudiantes; 0 si no hay
       COALESCE(SUM(vpt.total_eventos_asistidos), 0)             AS total_eventos_asistidos,          -- eventos asistidos entre todos sus estudiantes
       ROUND(AVG(vpt.puntaje_participacion), 1)                  AS promedio_puntaje                  -- puntaje de participacion promedio por estudiante
FROM programa AS p                                                                                    -- tabla base: una fila por programa
JOIN facultad AS f ON f.id_facultad = p.id_facultad                                                   -- facultad del programa
LEFT JOIN v_participacion_estudiante AS vpt ON vpt.id_programa = p.id_programa                        -- reutiliza la vista V4 en lugar de recalcular; LEFT JOIN conserva programas sin estudiantes
GROUP BY p.id_programa, f.nombre_facultad, p.nombre_programa;                                         -- agrupa por programa

COMMENT ON VIEW v_resumen_programa IS                                                                 -- documenta la vista dentro del catalogo de PostgreSQL
    'Resumen de comunidad y participacion por programa academico (usa v_participacion_estudiante).';  -- texto de la descripcion de la vista

/* Consulta de comprobacion de V5: resumen completo ordenado por participacion */
SELECT nombre_programa, total_estudiantes_activos,                                                    -- programa y sus estudiantes activos
       promedio_semestre, total_publicaciones, promedio_puntaje                                       -- semestre, publicaciones y puntaje promedio
FROM v_resumen_programa                                                                               -- consulta a la vista
ORDER BY promedio_puntaje DESC, id_programa;                                                          -- primero el programa con mas participacion


/* -----------------------------------------------------------------------------
   V6. v_matricula_curso   (nace de la consulta 1 del foro)
   Objetivo ..... Mostrar, para cada matricula, el estudiante, la materia, el grupo, el
                  profesor, el aula y la sede. Es la consulta de siete tablas del foro,
                  guardada como vista para encontrar companeros de clase sin repetir los
                  seis JOIN; se filtra por periodo al consultarla.
   Tablas ....... matricula, estudiante, curso, materia, profesor, espacio, sede
   ----------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW v_matricula_curso AS                                         -- crea (o reemplaza) la vista de cursos matriculados (consulta 1 del foro)
SELECT mt.id_estudiante,                                                            -- identificador del estudiante
       e.codigo_estudiante,                                                         -- codigo institucional
       e.nombre || ' ' || e.apellido     AS nombre_completo,                        -- nombre completo del estudiante
       c.periodo,                                                                   -- periodo del curso (por ejemplo 2026-2)
       m.nombre_materia,                                                            -- materia del curso
       c.codigo_grupo,                                                              -- grupo del curso (G100, G101...)
       pf.nombre || ' ' || pf.apellido   AS nombre_profesor,                        -- nombre completo del profesor
       es.nombre_espacio,                                                           -- aula donde se dicta el curso
       se.nombre_sede,                                                              -- sede del aula
       mt.fecha_matricula                                                           -- fecha de la matricula
FROM matricula AS mt                                                                -- tabla base: una fila por matricula
JOIN estudiante AS e ON e.id_estudiante = mt.id_estudiante                          -- datos del estudiante
JOIN curso AS c ON c.id_curso = mt.id_curso                                         -- curso en el que se matricula
JOIN materia AS m ON m.id_materia = c.id_materia                                    -- materia del curso
JOIN profesor AS pf ON pf.id_profesor = c.id_profesor                               -- profesor del curso
JOIN espacio AS es ON es.id_espacio = c.id_espacio                                  -- aula del curso
JOIN sede AS se ON se.id_sede = es.id_sede;                                         -- sede del aula

COMMENT ON VIEW v_matricula_curso IS                                                -- documenta la vista dentro del catalogo de PostgreSQL
    'Cursos matriculados por estudiante: materia, grupo, profesor, aula y sede.';   -- texto de la descripcion de la vista

/* Consulta de comprobacion de V6: companeros de clase de Bases de Datos I en 2026-2 */
SELECT nombre_completo, codigo_grupo, nombre_profesor, nombre_espacio, nombre_sede  -- companeros, grupo, profesor y lugar
FROM v_matricula_curso                                                              -- consulta a la vista
WHERE periodo = '2026-2'                                                            -- solo el periodo 2026-2
  AND nombre_materia = 'Bases de Datos I'                                           -- y solo la materia Bases de Datos I
ORDER BY codigo_grupo, nombre_completo                                              -- por grupo y luego por nombre
LIMIT 8;                                                                            -- muestra solo 8 filas


/* #############################################################################
   B. CONSULTAS DML SOBRE EL MODELO FISICO
   ############################################################################# */

/* -----------------------------------------------------------------------------
   C1. Intereses mas populares
   Pregunta ..... Cuantos estudiantes activos tiene cada interes y que porcentaje
                  de la comunidad activa representa?
   Tecnicas ..... LEFT JOIN (conserva intereses sin nadie), condicion en el ON,
                  subconsulta escalar, GROUP BY, ORDER BY.
   Alias ........ total_estudiantes_interesados, pct_comunidad_activa
   ----------------------------------------------------------------------------- */
SELECT i.nombre_interes,                                                      -- nombre del interes
       i.tipo,                                                                -- tipo: TECNOLOGICO, DEPORTIVO, CULTURAL, ACADEMICO u OCIO
       COUNT(e.id_estudiante) AS total_estudiantes_interesados,               -- cuenta solo estudiantes que si tienen el interes (0 si nadie)
       ROUND(100.0 * COUNT(e.id_estudiante)                                   -- porcentaje: 100.0 evita la division entera...
             / (SELECT COUNT(*) FROM estudiante WHERE estado = 'ACTIVO'), 1)  -- ...entre el total de estudiantes activos; un decimal
                              AS pct_comunidad_activa                         -- alias del porcentaje (R3: pct_)
FROM interes AS i                                                             -- tabla base: todos los intereses del catalogo
LEFT JOIN estudiante_interes AS ei ON ei.id_interes = i.id_interes            -- LEFT JOIN: conserva los intereses que nadie ha marcado
LEFT JOIN estudiante AS e ON e.id_estudiante = ei.id_estudiante               -- une con el estudiante...
                         AND e.estado = 'ACTIVO'                              -- ...la condicion va en el ON (no en el WHERE) para no perder intereses vacios
GROUP BY i.id_interes, i.nombre_interes, i.tipo                               -- una fila por interes
ORDER BY total_estudiantes_interesados DESC, i.nombre_interes;                -- primero el mas popular; desempata por nombre


/* -----------------------------------------------------------------------------
   C2. Mentores disponibles
   Pregunta ..... Que estudiantes activos de semestre 6 o superior tienen alguna
                  habilidad en nivel AVANZADO y cuantas mentorias activas llevan?
                  (los de menor carga son los mejores candidatos).
   Tecnicas ..... JOIN de cuatro tablas, subconsulta agregada en el LEFT JOIN
                  (evita multiplicar filas), COALESCE, STRING_AGG, GROUP BY.
   Alias ........ nombre_completo, total_habilidades_avanzadas,
                  lista_habilidades_avanzadas, total_mentorias_activas
   ----------------------------------------------------------------------------- */
SELECT e.id_estudiante,                                                                       -- identificador del estudiante
       e.nombre || ' ' || e.apellido                         AS nombre_completo,              -- nombre completo
       p.nombre_programa,                                                                     -- programa del estudiante
       e.semestre,                                                                            -- semestre
       COUNT(*)                                              AS total_habilidades_avanzadas,  -- cuantas habilidades avanzadas tiene (filas del grupo)
       STRING_AGG(h.nombre_habilidad, ', ' ORDER BY h.nombre_habilidad)                       -- une los nombres de esas habilidades, en orden alfabetico...
                                                             AS lista_habilidades_avanzadas,  -- ...alias de la lista (R3: lista_)
       COALESCE(m.total, 0)                                  AS total_mentorias_activas       -- mentorias activas; 0 si nunca ha sido mentor
FROM estudiante AS e                                                                          -- tabla base
JOIN programa AS p ON p.id_programa = e.id_programa                                           -- programa del estudiante
JOIN estudiante_habilidad AS eh ON eh.id_estudiante = e.id_estudiante                         -- habilidades del estudiante...
                               AND eh.nivel = 'AVANZADO'                                      -- ...solo las de nivel AVANZADO
JOIN habilidad AS h ON h.id_habilidad = eh.id_habilidad                                       -- nombre de la habilidad
LEFT JOIN (SELECT id_mentor, COUNT(*) AS total                                                -- subconsulta: mentorias por mentor (evita multiplicar filas)
           FROM mentoria                                                                      -- tabla de mentorias
           WHERE estado = 'ACTIVA'                                                            -- solo las activas
           GROUP BY id_mentor) AS m ON m.id_mentor = e.id_estudiante                          -- una fila por mentor; se une con el estudiante
WHERE e.estado = 'ACTIVO'                                                                     -- solo estudiantes activos
  AND e.semestre >= 6                                                                         -- de semestre 6 o superior
GROUP BY e.id_estudiante, e.nombre, e.apellido, p.nombre_programa,                            -- una fila por estudiante...
         e.semestre, m.total                                                                  -- ...(continua la lista de agrupacion)
ORDER BY total_mentorias_activas, e.semestre DESC, nombre_completo;                           -- primero los de menor carga; luego mayor semestre y nombre


/* -----------------------------------------------------------------------------
   C3. Companeros recomendados por intereses en comun
   Pregunta ..... A que companeros deberia seguir el estudiante 1 (Juan Camilo) porque
                  comparten con el al menos 2 intereses y todavia no los sigue?
   Tecnicas ..... CTE como parametro, auto-relacion sobre estudiante_interes,
                  NOT EXISTS (anti-join), STRING_AGG, HAVING.
   Alias ........ total_intereses_comunes, lista_intereses_comunes
   Parametro .... cambiar el 1 de la CTE "referencia" por otro id_estudiante.
   ----------------------------------------------------------------------------- */
WITH referencia AS (                                                                    -- CTE de un solo parametro: el estudiante de referencia
    SELECT 1 AS id_referencia                                                           -- cambiar el 1 por otro id_estudiante
)                                                                                       -- fin de la CTE
SELECT c.id_estudiante,                                                                 -- companero recomendado
       c.nombre || ' ' || c.apellido                       AS nombre_completo,          -- su nombre completo
       p.nombre_programa,                                                               -- su programa
       COUNT(*)                                            AS total_intereses_comunes,  -- cuantos intereses comparten
       STRING_AGG(i.nombre_interes, ', ' ORDER BY i.nombre_interes)                     -- nombres de los intereses compartidos, en orden alfabetico...
                                                           AS lista_intereses_comunes   -- ...alias de la lista (R3: lista_)
FROM referencia AS ref                                                                  -- parte del estudiante de referencia
JOIN estudiante_interes AS ei1 ON ei1.id_estudiante = ref.id_referencia                 -- sus intereses (ei1)
JOIN estudiante_interes AS ei2 ON ei2.id_interes = ei1.id_interes                       -- otros estudiantes con el mismo interes (ei2)...
                              AND ei2.id_estudiante <> ref.id_referencia                -- ...que no sean el de referencia
JOIN interes AS i ON i.id_interes = ei1.id_interes                                      -- nombre del interes compartido
JOIN estudiante AS c ON c.id_estudiante = ei2.id_estudiante                             -- datos del companero...
                    AND c.estado = 'ACTIVO'                                             -- ...solo companeros activos
JOIN programa AS p ON p.id_programa = c.id_programa                                     -- programa del companero
WHERE NOT EXISTS (SELECT 1                                                              -- excluye a quienes ya sigue (anti-join)
                  FROM seguimiento AS s                                                 -- tabla de seguimientos
                  WHERE s.id_seguidor = ref.id_referencia                               -- el de referencia es quien sigue...
                    AND s.id_seguido = c.id_estudiante)                                 -- ...a este companero
GROUP BY c.id_estudiante, c.nombre, c.apellido, p.nombre_programa                       -- una fila por companero
HAVING COUNT(*) >= 2                                                                    -- solo con 2 o mas intereses en comun (filtro posterior al agrupar)
ORDER BY total_intereses_comunes DESC, nombre_completo;                                 -- primero quien comparte mas intereses


/* -----------------------------------------------------------------------------
   C4. Publicaciones con mayor interaccion
   Pregunta ..... Cuales son las 10 publicaciones que mas reacciones y
                  comentarios generaron y quien las escribio?
   Tecnicas ..... Subconsultas agregadas en el FROM (evitan multiplicar filas),
                  LEFT JOIN, COALESCE, LEFT() para resumir el texto, LIMIT.
   Alias ........ nombre_autor, resumen_contenido, total_reacciones,
                  total_comentarios, total_interacciones
   ----------------------------------------------------------------------------- */
SELECT pu.id_publicacion,                                                         -- identificador de la publicacion
       a.nombre || ' ' || a.apellido                  AS nombre_autor,            -- nombre completo del autor
       pu.tipo_publicacion,                                                       -- tipo de publicacion
       LEFT(pu.contenido, 40) || '...'                AS resumen_contenido,       -- primeros 40 caracteres del texto, con puntos suspensivos
       COALESCE(r.total, 0)                           AS total_reacciones,        -- reacciones recibidas; 0 si no tiene
       COALESCE(c.total, 0)                           AS total_comentarios,       -- comentarios recibidos; 0 si no tiene
       COALESCE(r.total, 0) + COALESCE(c.total, 0)    AS total_interacciones      -- interaccion total = reacciones + comentarios
FROM publicacion AS pu                                                            -- tabla base
JOIN estudiante AS a ON a.id_estudiante = pu.id_autor                             -- autor de la publicacion
LEFT JOIN (SELECT id_publicacion, COUNT(*) AS total                               -- subconsulta de reacciones: una fila por publicacion
           FROM reaccion                                                          -- tabla de reacciones
           GROUP BY id_publicacion) AS r ON r.id_publicacion = pu.id_publicacion  -- agrupa y une con la publicacion
LEFT JOIN (SELECT id_publicacion, COUNT(*) AS total                               -- subconsulta de comentarios: una fila por publicacion
           FROM comentario                                                        -- tabla de comentarios
           GROUP BY id_publicacion) AS c ON c.id_publicacion = pu.id_publicacion  -- agrupa y une con la publicacion
ORDER BY total_interacciones DESC, pu.id_publicacion                              -- primero las de mas interaccion; desempata por id
LIMIT 10;                                                                         -- solo las 10 primeras


/* -----------------------------------------------------------------------------
   C5. Asistencia a los eventos ya realizados
   Pregunta ..... Que porcentaje de los inscritos asistio a cada evento
                  finalizado y que tan lleno quedo el espacio?
   Tecnicas ..... COUNT(...) FILTER, NULLIF (evita dividir por cero),
                  LEFT JOIN (eventos virtuales no tienen espacio), ROUND.
   Alias ........ total_inscritos_vigentes, total_asistentes, pct_asistencia,
                  pct_ocupacion_espacio
   ----------------------------------------------------------------------------- */
SELECT ev.id_evento,                                                                   -- identificador del evento
       ev.titulo,                                                                      -- titulo del evento
       ev.modalidad,                                                                   -- PRESENCIAL, VIRTUAL o HIBRIDA
       COUNT(*) FILTER (WHERE pe.estado <> 'CANCELADO')  AS total_inscritos_vigentes,  -- inscritos que no cancelaron
       COUNT(*) FILTER (WHERE pe.estado = 'ASISTIO')     AS total_asistentes,          -- inscritos que asistieron
       ROUND(100.0 * COUNT(*) FILTER (WHERE pe.estado = 'ASISTIO')                     -- porcentaje de asistencia: asistentes...
             / NULLIF(COUNT(*) FILTER (WHERE pe.estado <> 'CANCELADO'), 0), 1)         -- ...entre inscritos vigentes; NULLIF evita dividir por cero
                                                         AS pct_asistencia,            -- alias del porcentaje (R3: pct_)
       ROUND(100.0 * COUNT(*) FILTER (WHERE pe.estado = 'ASISTIO')                     -- porcentaje de ocupacion: asistentes...
             / es.capacidad, 1)                          AS pct_ocupacion_espacio      -- ...entre la capacidad del espacio (NULL si es virtual)
FROM evento AS ev                                                                      -- tabla base
JOIN participacion_evento AS pe ON pe.id_evento = ev.id_evento                         -- inscripciones (solo eventos con inscritos)
LEFT JOIN espacio AS es ON es.id_espacio = ev.id_espacio                               -- espacio: LEFT JOIN porque los virtuales no tienen
WHERE ev.fecha_cierre < DATE '2026-11-14'                                              -- solo eventos ya finalizados (fecha de corte)
GROUP BY ev.id_evento, ev.titulo, ev.modalidad, es.capacidad                           -- una fila por evento
ORDER BY pct_asistencia DESC, ev.id_evento;                                            -- primero el de mayor asistencia


/* -----------------------------------------------------------------------------
   C6. Grupos de estudio con mas miembros que el promedio
   Pregunta ..... Que grupos activos tienen mas miembros que el promedio de los
                  grupos activos y a que materia estan asociados?
   Tecnicas ..... CTE, LEFT JOIN (grupos sin materia), COALESCE, subconsulta
                  escalar con AVG en el WHERE.
   Alias ........ total_miembros, materia_asociada, promedio_miembros_grupo
   ----------------------------------------------------------------------------- */
WITH miembros_por_grupo AS (                                                              -- CTE: cuantos miembros tiene cada grupo activo
    SELECT g.id_grupo,                                                                    -- identificador del grupo
           g.nombre_grupo,                                                                -- nombre del grupo
           g.tipo,                                                                        -- tipo: ESTUDIO, HACKATON, CLUB o SEMILLERO
           COALESCE(m.nombre_materia, 'Sin materia asociada') AS materia_asociada,        -- materia del grupo, o un rotulo si no tiene
           COUNT(mg.id_estudiante)                            AS total_miembros           -- cuenta los miembros
    FROM grupo_estudio AS g                                                               -- tabla base
    LEFT JOIN materia AS m ON m.id_materia = g.id_materia                                 -- materia opcional
    LEFT JOIN miembro_grupo AS mg ON mg.id_grupo = g.id_grupo                             -- miembros del grupo
    WHERE g.estado = 'ACTIVO'                                                             -- solo grupos activos (no archivados)
    GROUP BY g.id_grupo, g.nombre_grupo, g.tipo, m.nombre_materia                         -- una fila por grupo
)                                                                                         -- fin de la CTE
SELECT mpg.id_grupo,                                                                      -- consulta principal sobre la CTE: identificador del grupo
       mpg.nombre_grupo,                                                                  -- nombre del grupo
       mpg.tipo,                                                                          -- tipo
       mpg.materia_asociada,                                                              -- materia asociada
       mpg.total_miembros,                                                                -- miembros del grupo
       (SELECT ROUND(AVG(total_miembros), 1) FROM miembros_por_grupo)                     -- promedio de miembros de los grupos activos (valor de comparacion)
                                                              AS promedio_miembros_grupo  -- alias del promedio (R3: promedio_)
FROM miembros_por_grupo AS mpg                                                            -- reutiliza la CTE
WHERE mpg.total_miembros > (SELECT AVG(total_miembros) FROM miembros_por_grupo)           -- solo grupos con mas miembros que el promedio
ORDER BY mpg.total_miembros DESC, mpg.nombre_grupo;                                       -- primero el grupo mas grande


/* -----------------------------------------------------------------------------
   C7. Estudiantes activos sin actividad reciente, por programa
   Pregunta ..... En cada programa, cuantos estudiantes activos llevan mas de 30
                  dias sin actividad (o nunca la han tenido) para planear una
                  campana de reactivacion?
   Tecnicas ..... CTE de parametros, CROSS JOIN, COUNT(...) FILTER, resta de
                  fechas, AVG que ignora NULL, JOIN con programa.
   Alias ........ total_estudiantes_activos, total_sin_actividad_registrada,
                  total_inactivos_30_dias, promedio_dias_sin_actividad
   Parametro .... fecha_corte de la CTE "corte".
   ----------------------------------------------------------------------------- */
WITH corte AS (                                                                                        -- CTE de parametros: la fecha de corte
    SELECT DATE '2026-11-14' AS fecha_corte                                                            -- fecha de referencia fija (resultado reproducible); se cambia aqui
)                                                                                                      -- fin de la CTE
SELECT p.nombre_programa,                                                                              -- programa academico
       COUNT(*)                                                    AS total_estudiantes_activos,       -- estudiantes activos del programa
       COUNT(*) FILTER (WHERE e.ultima_actividad IS NULL)          AS total_sin_actividad_registrada,  -- los que nunca han tenido actividad (NULL)
       COUNT(*) FILTER (WHERE c.fecha_corte - e.ultima_actividad::date > 30)                           -- los que llevan mas de 30 dias sin actividad (resta de fechas)...
                                                                   AS total_inactivos_30_dias,         -- ...alias (R3: total_)
       ROUND(AVG(c.fecha_corte - e.ultima_actividad::date), 1)     AS promedio_dias_sin_actividad      -- dias sin actividad en promedio; AVG ignora los NULL
FROM estudiante AS e                                                                                   -- tabla base
CROSS JOIN corte AS c                                                                                  -- pone la fecha de corte al alcance de cada fila
JOIN programa AS p ON p.id_programa = e.id_programa                                                    -- programa del estudiante
WHERE e.estado = 'ACTIVO'                                                                              -- solo estudiantes activos
GROUP BY p.nombre_programa                                                                             -- una fila por programa
ORDER BY total_inactivos_30_dias DESC, p.nombre_programa;                                              -- primero el programa con mas inactivos


/* -----------------------------------------------------------------------------
   C8. Ranking de participacion
   Pregunta ..... Quienes son los 10 estudiantes activos mas participativos segun
                  publicaciones, comentarios, reacciones y eventos asistidos?
   Tecnicas ..... CTE encadenadas, subconsultas correlacionadas, RANK() OVER
                  (funcion de ventana), CASE, LIMIT.
   Alias ........ total_publicaciones, total_comentarios, total_reacciones_dadas,
                  total_eventos_asistidos, puntaje_participacion,
                  posicion_ranking, categoria_participacion
   ----------------------------------------------------------------------------- */
WITH actividad AS (                                                                           -- CTE 1: actividad de cada estudiante activo
    SELECT e.id_estudiante,                                                                   -- identificador del estudiante
           e.nombre || ' ' || e.apellido AS nombre_completo,                                  -- nombre completo
           (SELECT COUNT(*) FROM publicacion AS pu                                            -- subconsulta correlacionada: publicaciones del estudiante...
             WHERE pu.id_autor = e.id_estudiante) AS total_publicaciones,                     -- ...cuenta las suyas (autor = estudiante actual)
           (SELECT COUNT(*) FROM comentario AS co                                             -- subconsulta correlacionada: comentarios del estudiante...
             WHERE co.id_autor = e.id_estudiante) AS total_comentarios,                       -- ...cuenta los suyos
           (SELECT COUNT(*) FROM reaccion AS re                                               -- subconsulta correlacionada: reacciones que dio...
             WHERE re.id_estudiante = e.id_estudiante) AS total_reacciones_dadas,             -- ...cuenta las suyas
           (SELECT COUNT(*) FROM participacion_evento AS pe                                   -- subconsulta correlacionada: eventos a los que asistio...
             WHERE pe.id_estudiante = e.id_estudiante                                         -- ...del estudiante actual...
               AND pe.estado = 'ASISTIO') AS total_eventos_asistidos                          -- ...con estado ASISTIO
    FROM estudiante AS e                                                                      -- tabla base
    WHERE e.estado = 'ACTIVO'                                                                 -- solo estudiantes activos
),                                                                                            -- fin de la CTE 1
puntuada AS (                                                                                 -- CTE 2: suma el puntaje (un alias del SELECT no se puede usar en la ventana)
    SELECT a.*,                                                                               -- todas las columnas de la CTE 1
           3 * total_publicaciones + 2 * total_comentarios                                    -- puntaje: 3 por publicacion y 2 por comentario...
             + total_reacciones_dadas + 5 * total_eventos_asistidos AS puntaje_participacion  -- ...1 por reaccion y 5 por evento asistido
    FROM actividad AS a                                                                       -- reutiliza la CTE 1
)                                                                                             -- fin de la CTE 2
SELECT RANK() OVER (ORDER BY puntaje_participacion DESC) AS posicion_ranking,                 -- funcion de ventana: posicion segun el puntaje (los empates comparten posicion)
       id_estudiante,                                                                         -- identificador del estudiante
       nombre_completo,                                                                       -- nombre completo
       total_publicaciones,                                                                   -- publicaciones
       total_comentarios,                                                                     -- comentarios
       total_reacciones_dadas,                                                                -- reacciones dadas
       total_eventos_asistidos,                                                               -- eventos asistidos
       puntaje_participacion,                                                                 -- puntaje total
       CASE WHEN puntaje_participacion >= 60 THEN 'DESTACADO'                                 -- clasifica: 60 o mas, DESTACADO...
            WHEN puntaje_participacion >= 40 THEN 'ACTIVO'                                    -- ...de 40 a 59, ACTIVO...
            ELSE 'EN CRECIMIENTO' END                    AS categoria_participacion           -- ...menos de 40, EN CRECIMIENTO (R3: categoria_)
FROM puntuada                                                                                 -- usa la CTE 2
ORDER BY posicion_ranking, id_estudiante                                                      -- por posicion; desempata por id
LIMIT 10;                                                                                     -- solo los 10 primeros puestos


/* -----------------------------------------------------------------------------
   C9. Etiquetas mas usadas en las publicaciones (JSONB)
   Pregunta ..... Que etiquetas aparecen mas en las publicaciones y cuantas reacciones
                  suman las publicaciones que las llevan?
   Tecnicas ..... Columna JSONB publicacion.metadatos (Tarea 4), jsonb_array_elements_text
                  con CROSS JOIN LATERAL (un renglon por etiqueta), subconsulta agregada,
                  COALESCE, GROUP BY y LIMIT.
   Alias ........ total_publicaciones, total_reacciones
   ----------------------------------------------------------------------------- */
SELECT t.etiqueta,                                                                        -- nombre de la etiqueta (una fila por etiqueta)
       COUNT(*)                         AS total_publicaciones,                           -- publicaciones que usan la etiqueta
       COALESCE(SUM(r.total), 0)        AS total_reacciones                               -- reacciones que suman esas publicaciones; 0 si no hay
FROM publicacion AS pu                                                                    -- tabla base
CROSS JOIN LATERAL jsonb_array_elements_text(pu.metadatos -> 'etiquetas') AS t(etiqueta)  -- convierte la lista JSONB de etiquetas en filas (una por etiqueta)
LEFT JOIN (SELECT id_publicacion, COUNT(*) AS total                                       -- subconsulta: reacciones por publicacion
           FROM reaccion                                                                  -- tabla de reacciones
           GROUP BY id_publicacion) AS r ON r.id_publicacion = pu.id_publicacion          -- agrupa y une con la publicacion
WHERE jsonb_typeof(pu.metadatos -> 'etiquetas') = 'array'                                 -- solo publicaciones cuyas etiquetas son una lista JSON
GROUP BY t.etiqueta                                                                       -- una fila por etiqueta
ORDER BY total_publicaciones DESC, total_reacciones DESC, t.etiqueta                      -- la mas usada primero; desempata por reacciones y nombre
LIMIT 8;                                                                                  -- solo las 8 primeras


/* -----------------------------------------------------------------------------
   C10. Ocupacion de las aulas con sensor IoT (JSONB)
   Pregunta ..... Que aulas con sensor tienen mayor ocupacion y cuales presentan alertas
                  de calidad del aire?
   Tecnicas ..... Columna JSONB espacio.datos_iot (Tarea 4), operadores -> y ->> con
                  conversion de tipo (::int), jsonb_array_length, CASE, JOIN con sede.
   Alias ........ total_personas_actuales, pct_aforo, medida_co2_ppm, estado_ambiente
   ----------------------------------------------------------------------------- */
SELECT s.nombre_sede,                                                                  -- sede del aula
       es.nombre_espacio,                                                              -- nombre del aula
       es.capacidad,                                                                   -- capacidad del aula
       (es.datos_iot -> 'ocupacion' ->> 'personas')::int  AS total_personas_actuales,  -- personas que reporta el sensor (-> entra al objeto, ->> da texto, ::int lo convierte)
       (es.datos_iot -> 'ocupacion' ->> 'aforo_pct')::int AS pct_aforo,                -- porcentaje del aforo ocupado segun el sensor
       (es.datos_iot ->> 'co2_ppm')::int                  AS medida_co2_ppm,           -- CO2 en partes por millon
       CASE WHEN jsonb_array_length(es.datos_iot -> 'alertas') > 0                     -- cuenta las alertas del JSON (NULL si el documento no trae la clave)...
            THEN 'CON ALERTA' ELSE 'NORMAL' END           AS estado_ambiente           -- ...CON ALERTA si hay alguna; NORMAL en caso contrario
FROM espacio AS es                                                                     -- tabla base
JOIN sede AS s ON s.id_sede = es.id_sede                                               -- sede del aula
WHERE es.datos_iot IS NOT NULL                                                         -- solo aulas que tienen sensor
ORDER BY pct_aforo DESC, es.nombre_espacio;                                            -- primero las mas llenas


/* -----------------------------------------------------------------------------
   C11. Estudiantes que van a eventos pero nunca han publicado   (consulta 2 del foro)
   Pregunta ..... Que estudiantes participan en eventos (sin contar las inscripciones
                  canceladas) pero nunca han hecho una publicacion, para invitarlos a
                  escribir en el muro?
   Tecnicas ..... Operador de conjuntos EXCEPT (A - B), JOIN, columnas identicas en ambos
                  lados, ORDER BY sobre el resultado final.
   Alias ........ (ninguno: solo columnas del modelo)
   ----------------------------------------------------------------------------- */
SELECT e.id_estudiante, e.nombre, e.apellido                           -- conjunto A: estudiantes que van a eventos
FROM estudiante AS e                                                   -- tabla de estudiantes
JOIN participacion_evento AS pe ON pe.id_estudiante = e.id_estudiante  -- inscripciones a eventos
WHERE pe.estado <> 'CANCELADO'                                         -- se ignoran las inscripciones canceladas
EXCEPT                                                                 -- resta B de A (A - B), sin repetidos
SELECT e.id_estudiante, e.nombre, e.apellido                           -- conjunto B: mismas columnas que A (requisito de EXCEPT)
FROM estudiante AS e                                                   -- tabla de estudiantes
JOIN publicacion AS pu ON pu.id_autor = e.id_estudiante                -- publicaciones; el autor es el estudiante
ORDER BY id_estudiante;                                                -- ordena el resultado final por id


/* #############################################################################
   C. CONSULTAS QUE REUTILIZAN LAS VISTAS
   ############################################################################# */

/* -----------------------------------------------------------------------------
   U1. Mentores con buena participacion (une dos vistas)
   Pregunta ..... Entre los estudiantes con alguna habilidad avanzada, quienes
                  ademas son los mas participativos? Sirven como mentores
                  visibles para la comunidad.
   Vistas ....... v_perfil_estudiante y v_participacion_estudiante
   Alias ........ puntaje_participacion (viene de la vista V4)
   ----------------------------------------------------------------------------- */
SELECT vpf.id_estudiante,                                                        -- identificador (de la vista de perfil)
       vpf.nombre_completo,                                                      -- nombre completo
       vpf.nombre_programa,                                                      -- programa
       vpf.semestre,                                                             -- semestre
       vpf.total_habilidades_avanzadas,                                          -- habilidades avanzadas
       vpt.puntaje_participacion                                                 -- puntaje (de la vista de participacion)
FROM v_perfil_estudiante AS vpf                                                  -- primera vista: perfil
JOIN v_participacion_estudiante AS vpt ON vpt.id_estudiante = vpf.id_estudiante  -- segunda vista: participacion (se unen por id_estudiante)
WHERE vpf.estado = 'ACTIVO'                                                      -- solo estudiantes activos
  AND vpf.total_habilidades_avanzadas > 0                                        -- con al menos una habilidad avanzada
ORDER BY vpt.puntaje_participacion DESC, vpf.id_estudiante                       -- los mas participativos primero
LIMIT 5;                                                                         -- los 5 primeros

/* -----------------------------------------------------------------------------
   U2. Contenido que mas funciona por tipo de publicacion
   Pregunta ..... Que tipo de publicacion genera en promedio mas interaccion?
   Vista ........ v_actividad_publicacion
   Alias ........ total_publicaciones, promedio_interacciones,
                  total_categoria_alta
   ----------------------------------------------------------------------------- */
SELECT tipo_publicacion,                                                                   -- tipo de publicacion
       COUNT(*)                                                AS total_publicaciones,     -- cuantas hay de ese tipo
       ROUND(AVG(total_interacciones), 1)                      AS promedio_interacciones,  -- interacciones promedio
       COUNT(*) FILTER (WHERE categoria_interaccion = 'ALTA')  AS total_categoria_alta     -- cuantas tienen interaccion ALTA
FROM v_actividad_publicacion                                                               -- consulta a la vista
GROUP BY tipo_publicacion                                                                  -- una fila por tipo
ORDER BY promedio_interacciones DESC, tipo_publicacion;                                    -- primero el tipo con mas interaccion promedio


/* #############################################################################
   D. OPERACIONES DE ESCRITURA (INSERT, UPDATE, DELETE)
      Cada una va dentro de BEGIN ... ROLLBACK: se ejecutan de verdad y muestran
      su resultado con RETURNING, pero los datos quedan como estaban.
      Para guardar los cambios se reemplazaria ROLLBACK por COMMIT.
   ############################################################################# */

/* -----------------------------------------------------------------------------
   E1. INSERT ... SELECT con ON CONFLICT
   Pregunta ..... Como se inscribe automaticamente en el evento "Hackaton
                  Pascualina 2026" a todos los miembros del grupo que lo organiza?
   Tecnicas ..... INSERT ... SELECT, ON CONFLICT DO NOTHING (respeta la clave
                  primaria compuesta), RETURNING.
   ----------------------------------------------------------------------------- */
COMMIT;   -- confirma lo anterior antes de abrir la transaccion de prueba
BEGIN;                                                               -- abre una transaccion de prueba

INSERT INTO participacion_evento (id_estudiante, id_evento, estado)  -- inscribe filas en participacion_evento...
SELECT mg.id_estudiante, ev.id_evento, 'INSCRITO'                    -- ...cada miembro del grupo, el evento y el estado INSCRITO
FROM evento AS ev                                                    -- evento organizado por el grupo
JOIN miembro_grupo AS mg ON mg.id_grupo = ev.id_grupo                -- miembros de ese grupo
WHERE ev.id_evento = 13          -- Hackaton Pascualina 2026 (grupo 4)
ON CONFLICT (id_estudiante, id_evento) DO NOTHING                    -- si ya estaba inscrito, lo omite (clave primaria compuesta)
RETURNING id_estudiante, id_evento, estado;                          -- muestra las filas realmente insertadas

ROLLBACK;                                                            -- deshace la prueba: los datos quedan como estaban

/* -----------------------------------------------------------------------------
   E2. UPDATE con RETURNING
   Pregunta ..... Como se marcan como INACTIVOS los estudiantes activos que llevan
                  mas de 60 dias sin ninguna actividad?
   Tecnicas ..... UPDATE con condicion sobre fechas y RETURNING.
   ----------------------------------------------------------------------------- */
COMMIT;   -- confirma lo anterior antes de abrir la transaccion de prueba
BEGIN;                                                                -- abre una transaccion de prueba

UPDATE estudiante                                                     -- modifica la tabla de estudiantes
SET estado = 'INACTIVO'                                               -- nuevo estado
WHERE estado = 'ACTIVO'                                               -- solo a quienes hoy estan activos...
  AND ultima_actividad < DATE '2026-11-14' - INTERVAL '60 days'       -- ...y llevan mas de 60 dias sin actividad
RETURNING id_estudiante, nombre, apellido, ultima_actividad, estado;  -- muestra a quien afecto

ROLLBACK;                                                             -- deshace la prueba

/* -----------------------------------------------------------------------------
   E3. DELETE dentro de una CTE
   Pregunta ..... Cuantas inscripciones canceladas de eventos ya finalizados se
                  pueden depurar y de que eventos son?
   Tecnicas ..... DELETE con subconsulta, CTE de datos modificados, GROUP BY
                  sobre las filas devueltas por RETURNING.
   Alias ........ total_filas_borradas
   ----------------------------------------------------------------------------- */
COMMIT;   -- confirma lo anterior antes de abrir la transaccion de prueba
BEGIN;                                                            -- abre una transaccion de prueba

WITH borradas AS (                                                -- CTE que contiene el DELETE y lo que devuelve
    DELETE FROM participacion_evento                              -- borra de participacion_evento...
    WHERE estado = 'CANCELADO'                                    -- ...solo inscripciones canceladas...
      AND id_evento IN (SELECT id_evento                          -- ...de eventos...
                        FROM evento                               -- ...(tabla de eventos)
                        WHERE fecha_cierre < DATE '2026-11-14')   -- ...ya finalizados (fecha de corte)
    RETURNING id_evento                                           -- devuelve el evento de cada fila borrada
)                                                                 -- fin de la CTE
SELECT ev.id_evento, ev.titulo, COUNT(*) AS total_filas_borradas  -- evento y cuantas filas se borraron de cada uno
FROM borradas AS b                                                -- filas devueltas por el DELETE
JOIN evento AS ev ON ev.id_evento = b.id_evento                   -- titulo del evento
GROUP BY ev.id_evento, ev.titulo                                  -- una fila por evento
ORDER BY ev.id_evento;                                            -- por id de evento

ROLLBACK;                                                         -- deshace la prueba: las filas borradas vuelven

/* Verificacion final: las operaciones de escritura no dejaron huellas */
SELECT (SELECT COUNT(*) FROM participacion_evento) AS total_participaciones,                        -- filas de participacion_evento (igual que antes de las pruebas)
       (SELECT COUNT(*) FROM estudiante WHERE estado = 'INACTIVO') AS total_estudiantes_inactivos;  -- estudiantes inactivos (las pruebas no dejaron cambios)
