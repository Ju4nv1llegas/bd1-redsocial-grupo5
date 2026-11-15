# Borrador: tablas, campos, tipos de datos y alias de las consultas del foro

Complementa `consultas_foro.sql` (las 4 consultas publicadas en el foro, con un comentario por línea). Identifica, para cada una, las tablas, los campos y sus tipos de datos (tomados del catálogo de PostgreSQL) y empieza a aplicar las reglas de nomenclatura de ALIAS (R1 a R8, ver `diccionarios/diccionario_de_alias.md`).

## Consulta 1 · cursos matriculados (7 tablas)

**Tablas y campos (tipo de dato)**

- matricula (id_estudiante INTEGER; id_curso INTEGER)
- estudiante (codigo_estudiante VARCHAR(15); nombre VARCHAR(50); apellido VARCHAR(50))
- curso (periodo VARCHAR(6); codigo_grupo VARCHAR(10))
- materia (nombre_materia VARCHAR(100))
- profesor (nombre VARCHAR(50); apellido VARCHAR(50))
- espacio (nombre_espacio VARCHAR(60))
- sede (nombre_sede VARCHAR(80))

- **Alias del borrador:** `estudiante`, `materia`, `grupo`, `profesor`, `aula`, `sede`
- **Alias según las reglas:** `nombre_completo` y `nombre_profesor` (R3). Materia, grupo, aula y sede se muestran con el nombre de su columna (R4).

## Consulta 2 · EXCEPT

**Tablas y campos (tipo de dato)**

- estudiante (id_estudiante INTEGER; nombre VARCHAR(50); apellido VARCHAR(50))
- participacion_evento (estado VARCHAR(12))
- publicacion (id_autor INTEGER)

- **Alias del borrador:** Ninguno de columna. Alias de tabla `e`, `pe` y `p`.
- **Alias según las reglas:** Sin alias de columna. El alias de tabla `p` pasa a `pu` (R6).

## Consulta 3 · programas con más preguntas y recursos

**Tablas y campos (tipo de dato)**

- publicacion (id_publicacion INTEGER; tipo_publicacion VARCHAR(20))
- estudiante (semestre INTEGER)
- programa (nombre_programa VARCHAR(100))
- facultad (nombre_facultad VARCHAR(100))

- **Alias del borrador:** `facultad`, `programa`, `total_publicaciones`, `semestre_promedio`
- **Alias según las reglas:** `total_publicaciones` se conserva (R3); `semestre_promedio` pasa a `promedio_semestre` (R3); facultad y programa con el nombre de su columna (R4).

## Consulta 4 · publicaciones sobre el promedio

**Tablas y campos (tipo de dato)**

- publicacion (id_publicacion INTEGER; tipo_publicacion VARCHAR(20); contenido TEXT)
- reaccion (id_publicacion INTEGER)

- **Alias del borrador:** `reacciones`
- **Alias según las reglas:** `total_reacciones` (R3).
