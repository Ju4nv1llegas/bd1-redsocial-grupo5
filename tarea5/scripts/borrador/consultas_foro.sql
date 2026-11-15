/* ============================================================================
   Foro: Trabajando en la implementación de la red social estudiantil pascualina
   Motor: PostgreSQL 16 - Esquema: red_social
   Participante: Juan Camilo Villegas Ocampo (trabajo individual)

   Ejecutar primero 01_datos_ejemplo.sql. Luego seleccionar UNA consulta
   con el ratón y pulsar F5 para ver su resultado y tomar la captura.
   ============================================================================ */

SET search_path TO red_social;  -- usar el esquema red_social sin escribir el prefijo en cada tabla

/* ----------------------------------------------------------------------------
   CONSULTA 1: con tres o más tablas (7 tablas)
   Enunciado: "Como estudiante quiero ver, para el periodo 2026-2, a qué cursos
   está matriculado cada estudiante: la materia, el grupo, el profesor, el aula
   y la sede, para encontrar a mis compañeros de clase."
   ---------------------------------------------------------------------------- */
SELECT                                                  -- SELECT: columnas que se mostrarán
    e.codigo_estudiante,                                -- código institucional del estudiante
    e.nombre || ' ' || e.apellido AS estudiante,        -- nombre completo (|| concatena textos)
    m.nombre_materia AS materia,                        -- nombre de la materia matriculada
    c.codigo_grupo AS grupo,                            -- grupo del curso (G100, G200...)
    p.nombre || ' ' || p.apellido AS profesor,          -- nombre completo del profesor
    s.nombre_espacio AS aula,                           -- aula donde se dicta el curso
    sd.nombre_sede AS sede                              -- sede donde queda el aula
FROM matricula mt                                       -- FROM: tabla base, une al estudiante con el curso
JOIN estudiante e ON e.id_estudiante = mt.id_estudiante -- JOIN 1: datos del estudiante (clave id_estudiante)
JOIN curso c      ON c.id_curso = mt.id_curso           -- JOIN 2: datos del curso (clave id_curso)
JOIN materia m    ON m.id_materia = c.id_materia        -- JOIN 3: nombre de la materia del curso
JOIN profesor p   ON p.id_profesor = c.id_profesor      -- JOIN 4: profesor que dicta el curso
JOIN espacio s    ON s.id_espacio = c.id_espacio        -- JOIN 5: aula asignada al curso
JOIN sede sd      ON sd.id_sede = s.id_sede             -- JOIN 6: sede donde está el aula
WHERE c.periodo = '2026-2'                              -- WHERE: solo cursos del periodo 2026-2
ORDER BY m.nombre_materia, e.apellido;                  -- ORDER BY: agrupa por materia y ordena por apellido

/* ----------------------------------------------------------------------------
   CONSULTA 2: de diferencia (EXCEPT)
   Enunciado: "Como administrador quiero conocer a los estudiantes que participan
   en eventos pero nunca han hecho una publicación, para invitarlos a escribir
   en el muro."
   ---------------------------------------------------------------------------- */
SELECT e.id_estudiante, e.nombre, e.apellido            -- conjunto A: datos de los estudiantes que van a eventos
FROM estudiante e                                       -- tabla de estudiantes
JOIN participacion_evento pe                            -- une con las inscripciones a eventos
     ON pe.id_estudiante = e.id_estudiante              -- condición de unión: mismo estudiante
WHERE pe.estado <> 'CANCELADO'                          -- se ignoran las inscripciones canceladas
EXCEPT                                                  -- EXCEPT: resta B de A (A - B), sin repetidos
SELECT e.id_estudiante, e.nombre, e.apellido            -- conjunto B: mismas columnas que A (requisito de EXCEPT)
FROM estudiante e                                       -- tabla de estudiantes
JOIN publicacion p                                      -- une con las publicaciones
     ON p.id_autor = e.id_estudiante                    -- condición de unión: el autor es el estudiante
ORDER BY id_estudiante;                                 -- ordena el resultado final por id

/* ----------------------------------------------------------------------------
   CONSULTA 3: con todas las cláusulas
   (SELECT, FROM, JOIN, WHERE, GROUP BY, HAVING, ORDER BY, LIMIT)
   Enunciado: "Como coordinadora quiero ver los 3 programas con más preguntas y
   recursos publicados, solo si tienen al menos 2, con la facultad, el total y
   el semestre promedio de sus autores, para saber dónde hay más colaboración."
   ---------------------------------------------------------------------------- */
SELECT                                                  -- SELECT: columnas y cálculos del resultado
    f.nombre_facultad AS facultad,                      -- facultad del programa
    pr.nombre_programa AS programa,                     -- nombre del programa
    COUNT(p.id_publicacion) AS total_publicaciones,     -- cuenta las publicaciones de cada programa
    ROUND(AVG(e.semestre), 1) AS semestre_promedio      -- promedio de semestre, con 1 decimal
FROM publicacion p                                      -- FROM: tabla base, cada fila es una publicación
JOIN estudiante e ON e.id_estudiante = p.id_autor       -- JOIN: autor de la publicación
JOIN programa pr  ON pr.id_programa = e.id_programa     -- JOIN: programa del autor
JOIN facultad f   ON f.id_facultad = pr.id_facultad     -- JOIN: facultad del programa
WHERE p.tipo_publicacion IN ('PREGUNTA', 'RECURSO')     -- WHERE: filtra filas ANTES de agrupar
GROUP BY f.nombre_facultad, pr.nombre_programa          -- GROUP BY: una fila por programa
HAVING COUNT(p.id_publicacion) >= 2                     -- HAVING: filtra grupos DESPUÉS de agrupar
ORDER BY total_publicaciones DESC, pr.nombre_programa   -- ORDER BY: primero el que más publicó
LIMIT 3;                                                -- LIMIT: muestra solo los 3 primeros

/* ----------------------------------------------------------------------------
   CONSULTA 4: con subconsulta que NO se puede resolver con JOIN
   Enunciado: "Como moderador quiero ver las publicaciones que tienen más
   reacciones que el promedio de reacciones por publicación, para destacarlas."
   Por qué no se resuelve con JOIN: hay que comparar cada fila con un valor
   calculado sobre TODA la tabla (el promedio), y un JOIN solo combina filas.
   ---------------------------------------------------------------------------- */
SELECT                                                  -- SELECT: columnas del resultado
    p.id_publicacion,                                   -- identificador de la publicación
    p.tipo_publicacion,                                 -- tipo (PREGUNTA, RECURSO, MEME...)
    p.contenido,                                        -- texto de la publicación
    (SELECT COUNT(*)                                    -- subconsulta 1 (correlacionada): cuenta reacciones
       FROM reaccion r                                  -- tabla de reacciones
      WHERE r.id_publicacion = p.id_publicacion)        -- solo las de ESTA publicación (fila actual)
      AS reacciones                                     -- nombre de la columna calculada
FROM publicacion p                                      -- FROM: tabla de publicaciones
WHERE (SELECT COUNT(*)                                  -- subconsulta 2: reacciones de la publicación actual
         FROM reaccion r2                               -- tabla de reacciones
        WHERE r2.id_publicacion = p.id_publicacion)     -- solo las de ESTA publicación
      >                                                 -- se compara con el promedio general:
      (SELECT COUNT(*)::numeric                         -- subconsulta 3: total de reacciones (a decimal)
         FROM reaccion)                                 -- de todas las publicaciones
      /                                                 -- dividido entre
      (SELECT COUNT(*)                                  -- subconsulta 4: total de publicaciones
         FROM publicacion)                              -- de la red social
ORDER BY reacciones DESC, p.id_publicacion;             -- ORDER BY: primero las más reaccionadas
