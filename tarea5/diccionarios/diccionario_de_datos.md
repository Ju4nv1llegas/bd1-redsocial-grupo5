# Diccionario de datos — Red social estudiantil pascualina

Esquema `red_social` · PostgreSQL 16 · 25 tablas, 118 columnas (2 de tipo JSONB), 34 claves foráneas.
Generado a partir del catálogo de la base de datos creada con `scripts/final/01_ddl_postgresql.sql` (modelo físico de la Tarea 4).

Convenciones: **PK** clave primaria, **FK** clave foránea, **UQ** valor único, **NN** no admite NULL, **ID** autonumérica (`GENERATED ALWAYS AS IDENTITY`).

## facultad

Facultades de la institución.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_facultad` | INTEGER (ID) | NN | PK |  | Identificador autonumérico de la facultad. |
| `nombre_facultad` | VARCHAR(100) | NN | UQ |  | Nombre de la facultad (único). |

## sede

Sedes físicas donde se realizan clases y eventos.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_sede` | INTEGER (ID) | NN | PK |  | Identificador autonumérico de la sede. |
| `nombre_sede` | VARCHAR(80) | NN | UQ |  | Nombre de la sede (único). |
| `direccion` | VARCHAR(150) | NN |  |  | Dirección de la sede. |

## interes

Catálogo de intereses que los estudiantes pueden marcar en su perfil.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_interes` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del interés. |
| `nombre_interes` | VARCHAR(60) | NN | UQ |  | Nombre del interés (único). |
| `tipo` | VARCHAR(20) | NN |  |  | Clasificación: ACADEMICO, DEPORTIVO, CULTURAL, TECNOLOGICO u OCIO. |
| `descripcion` | VARCHAR(255) | NULL |  |  | Texto breve que explica el interés. |

**Restricciones adicionales**

- CHECK `ck_interes_tipo`: tipo IN ('ACADEMICO', 'DEPORTIVO', 'CULTURAL', 'TECNOLOGICO', 'OCIO')

## habilidad

Catálogo de habilidades que un estudiante puede declarar.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_habilidad` | INTEGER (ID) | NN | PK |  | Identificador autonumérico de la habilidad. |
| `nombre_habilidad` | VARCHAR(60) | NN | UQ |  | Nombre de la habilidad (único). |
| `descripcion` | VARCHAR(255) | NULL |  |  | Texto breve que explica la habilidad. |

## materia

Asignaturas del plan de estudios.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_materia` | INTEGER (ID) | NN | PK |  | Identificador autonumérico de la materia. |
| `codigo_materia` | VARCHAR(15) | NN | UQ |  | Código institucional de la materia (único), por ejemplo SD1006. |
| `nombre_materia` | VARCHAR(100) | NN |  |  | Nombre de la materia. |
| `creditos` | INTEGER | NN |  |  | Créditos académicos (de 1 a 10). |

**Restricciones adicionales**

- CHECK `ck_materia_creditos`: ((creditos >= 1) AND (creditos <= 10))

## profesor

Docentes que dictan los cursos.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_profesor` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del profesor. |
| `nombre` | VARCHAR(50) | NN |  |  | Nombres del profesor. |
| `apellido` | VARCHAR(50) | NN |  |  | Apellidos del profesor. |
| `email` | VARCHAR(100) | NN | UQ |  | Correo del profesor (único). |

## recurso_academico

Material de estudio compartido en la red.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_recurso` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del recurso. |
| `titulo` | VARCHAR(150) | NN |  |  | Título del recurso. |
| `url` | VARCHAR(255) | NN | UQ |  | Dirección donde se consulta el recurso (única). |
| `tipo_archivo` | VARCHAR(10) | NN |  |  | Formato: PDF, DOC, VIDEO, ENLACE o IMAGEN. |

**Restricciones adicionales**

- CHECK `ck_recurso_academico_tipo`: tipo_archivo IN ('PDF', 'DOC', 'VIDEO', 'ENLACE', 'IMAGEN')

## programa

Programas académicos, cada uno adscrito a una facultad.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_programa` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del programa. |
| `id_facultad` | INTEGER | NN | FK | facultad.id_facultad | Facultad a la que pertenece el programa. |
| `nombre_programa` | VARCHAR(100) | NN | UQ |  | Nombre del programa (único). |

## espacio

Salones, laboratorios y áreas de una sede.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_espacio` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del espacio. |
| `id_sede` | INTEGER | NN | FK | sede.id_sede | Sede donde está el espacio. |
| `nombre_espacio` | VARCHAR(60) | NN |  |  | Nombre del espacio. |
| `bloque` | VARCHAR(10) | NN |  |  | Bloque o zona de la sede. |
| `capacidad` | INTEGER | NN |  |  | Número máximo de personas (mayor que 0). |
| `datos_iot` | JSONB | NULL |  |  | Última lectura de los sensores IoT del espacio en JSON (ocupación, temperatura, CO2); NULL si no tiene sensor. |

**Restricciones adicionales**

- UNIQUE `uq_espacio_sede_nombre_bloque` (id_sede, nombre_espacio, bloque)
- CHECK `ck_espacio_capacidad`: (capacidad > 0)
- CHECK `ck_espacio_datos_iot_json`: (jsonb_typeof(datos_iot) = 'object')

## curso

Oferta de una materia en un periodo y grupo, con su profesor y espacio.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_curso` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del curso. |
| `id_materia` | INTEGER | NN | FK | materia.id_materia | Materia que se dicta. |
| `id_profesor` | INTEGER | NN | FK | profesor.id_profesor | Profesor responsable. |
| `id_espacio` | INTEGER | NN | FK | espacio.id_espacio | Espacio donde se dicta. |
| `periodo` | VARCHAR(6) | NN |  |  | Periodo académico con formato AAAA-1 o AAAA-2. |
| `codigo_grupo` | VARCHAR(10) | NN |  |  | Código del grupo, por ejemplo G100. |

**Restricciones adicionales**

- UNIQUE `uq_curso_materia_periodo_grupo` (id_materia, periodo, codigo_grupo)
- CHECK `ck_curso_periodo`: ((periodo) ~ '^[0-9]{4}-[12]$')

## estudiante

Cuenta de cada estudiante de la red social.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_estudiante` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del estudiante. |
| `id_programa` | INTEGER | NN | FK | programa.id_programa | Programa en el que está matriculado. |
| `codigo_estudiante` | VARCHAR(15) | NN | UQ |  | Código institucional del estudiante (único). |
| `nombre` | VARCHAR(50) | NN |  |  | Nombres. |
| `apellido` | VARCHAR(50) | NN |  |  | Apellidos. |
| `email` | VARCHAR(100) | NN | UQ |  | Correo de la cuenta (único). |
| `contrasena_hash` | VARCHAR(255) | NN |  |  | Hash de la contraseña; nunca se guarda en texto plano. |
| `semestre` | INTEGER | NN |  |  | Semestre que cursa (de 1 a 12). |
| `fecha_registro` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento en que se creó la cuenta. |
| `ultima_actividad` | TIMESTAMP | NULL |  |  | Última vez que el estudiante hizo algo en la red (NULL si nunca). |
| `estado` | VARCHAR(10) (DEFAULT 'ACTIVO') | NN |  |  | ACTIVO, INACTIVO o SUSPENDIDO. |

**Restricciones adicionales**

- CHECK `ck_estudiante_estado`: estado IN ('ACTIVO', 'INACTIVO', 'SUSPENDIDO')
- CHECK `ck_estudiante_semestre`: ((semestre >= 1) AND (semestre <= 12))

## perfil

Datos públicos del estudiante (relación 1:1).

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_perfil` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del perfil. |
| `id_estudiante` | INTEGER | NN | FK UQ | estudiante.id_estudiante | Estudiante dueño del perfil (único). |
| `biografia` | VARCHAR(500) | NULL |  |  | Presentación personal (hasta 500 caracteres). |
| `foto_perfil` | VARCHAR(255) | NULL |  |  | Dirección de la foto de perfil. |
| `ciudad` | VARCHAR(60) | NULL |  |  | Ciudad de residencia. |
| `fecha_actualizacion` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Última modificación del perfil. |

## estudiante_interes

Intereses de cada estudiante (relación N:M).

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_estudiante` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante que declara el interés. |
| `id_interes` | INTEGER | NN | PK FK | interes.id_interes | Interés declarado. |
| `fecha_agregado` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento en que se agregó. |

**Restricciones adicionales**

- Clave primaria compuesta `(id_estudiante, id_interes)`

## estudiante_habilidad

Habilidades de cada estudiante con su nivel (relación N:M).

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_estudiante` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante que declara la habilidad. |
| `id_habilidad` | INTEGER | NN | PK FK | habilidad.id_habilidad | Habilidad declarada. |
| `nivel` | VARCHAR(12) | NN |  |  | BASICO, INTERMEDIO o AVANZADO. |
| `fecha_agregado` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento en que se agregó. |

**Restricciones adicionales**

- Clave primaria compuesta `(id_estudiante, id_habilidad)`
- CHECK `ck_estudiante_habilidad_nivel`: nivel IN ('BASICO', 'INTERMEDIO', 'AVANZADO')

## seguimiento

Quién sigue a quién (relación N:M reflexiva).

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_seguidor` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante que sigue. |
| `id_seguido` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante seguido (distinto del seguidor). |
| `fecha_seguimiento` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento en que empezó a seguirlo. |

**Restricciones adicionales**

- Clave primaria compuesta `(id_seguidor, id_seguido)`
- CHECK `ck_seguimiento_distintos`: (id_seguidor <> id_seguido)

## mentoria

Relación de mentoría entre un mentor y un aprendiz (N:M reflexiva).

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_mentor` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante que orienta. |
| `id_aprendiz` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante que recibe la orientación. |
| `id_materia` | INTEGER | NULL | FK | materia.id_materia | Materia sobre la que versa la mentoría (opcional). |
| `fecha_inicio` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento en que se solicitó o inició. |
| `estado` | VARCHAR(12) (DEFAULT 'SOLICITADA') | NN |  |  | SOLICITADA, ACTIVA o FINALIZADA. |

**Restricciones adicionales**

- Clave primaria compuesta `(id_mentor, id_aprendiz)`
- CHECK `ck_mentoria_distintos`: (id_mentor <> id_aprendiz)
- CHECK `ck_mentoria_estado`: estado IN ('SOLICITADA', 'ACTIVA', 'FINALIZADA')

## publicacion

Publicaciones del muro de la red social.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_publicacion` | INTEGER (ID) | NN | PK |  | Identificador autonumérico de la publicación. |
| `id_autor` | INTEGER | NN | FK | estudiante.id_estudiante | Estudiante que publica. |
| `contenido` | TEXT | NN |  |  | Texto de la publicación. |
| `tipo_publicacion` | VARCHAR(20) | NN |  |  | PREGUNTA, RECURSO, NOTICIA, AVISO o MEME. |
| `fecha_creacion` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento de la publicación. |
| `metadatos` | JSONB | NULL |  |  | Metadatos flexibles de la publicación en JSON (etiquetas, adjuntos, geoubicación); NULL si no tiene. |

**Restricciones adicionales**

- CHECK `ck_publicacion_metadatos_json`: (jsonb_typeof(metadatos) = 'object')
- CHECK `ck_publicacion_tipo`: tipo_publicacion IN ('PREGUNTA', 'RECURSO', 'NOTICIA', 'AVISO', 'MEME')

## comentario

Comentarios sobre las publicaciones.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_comentario` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del comentario. |
| `id_publicacion` | INTEGER | NN | FK | publicacion.id_publicacion | Publicación comentada. |
| `id_autor` | INTEGER | NN | FK | estudiante.id_estudiante | Estudiante que comenta. |
| `contenido` | VARCHAR(1000) | NN |  |  | Texto del comentario (hasta 1000 caracteres). |
| `fecha_comentario` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento del comentario. |

## reaccion

Reacción de un estudiante a una publicación (una por estudiante y publicación).

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_estudiante` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante que reacciona. |
| `id_publicacion` | INTEGER | NN | PK FK | publicacion.id_publicacion | Publicación a la que reacciona. |
| `tipo_reaccion` | VARCHAR(15) | NN |  |  | ME_GUSTA, ME_ENCANTA, ME_DIVIERTE o UTIL. |
| `fecha_reaccion` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento de la reacción. |

**Restricciones adicionales**

- Clave primaria compuesta `(id_estudiante, id_publicacion)`
- CHECK `ck_reaccion_tipo`: tipo_reaccion IN ('ME_GUSTA', 'ME_ENCANTA', 'ME_DIVIERTE', 'UTIL')

## grupo_estudio

Grupos de estudio, clubes, semilleros y equipos de hackatón.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_grupo` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del grupo. |
| `id_creador` | INTEGER | NN | FK | estudiante.id_estudiante | Estudiante que creó el grupo. |
| `id_materia` | INTEGER | NULL | FK | materia.id_materia | Materia asociada (opcional). |
| `nombre_grupo` | VARCHAR(80) | NN |  |  | Nombre del grupo. |
| `descripcion` | VARCHAR(500) | NULL |  |  | Propósito del grupo. |
| `tipo` | VARCHAR(20) | NN |  |  | ESTUDIO, HACKATON, CLUB o SEMILLERO. |
| `es_privado` | BOOLEAN (DEFAULT false) | NN |  |  | Verdadero si solo se entra por invitación. |
| `estado` | VARCHAR(10) (DEFAULT 'ACTIVO') | NN |  |  | ACTIVO o ARCHIVADO. |
| `fecha_creacion` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento de creación. |

**Restricciones adicionales**

- CHECK `ck_grupo_estudio_estado`: estado IN ('ACTIVO', 'ARCHIVADO')
- CHECK `ck_grupo_estudio_tipo`: tipo IN ('ESTUDIO', 'HACKATON', 'CLUB', 'SEMILLERO')

## miembro_grupo

Estudiantes que pertenecen a cada grupo (relación N:M).

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_grupo` | INTEGER | NN | PK FK | grupo_estudio.id_grupo | Grupo al que pertenece. |
| `id_estudiante` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante miembro. |
| `rol` | VARCHAR(15) (DEFAULT 'MIEMBRO') | NN |  |  | ADMIN, MODERADOR o MIEMBRO. |
| `fecha_ingreso` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento en que ingresó al grupo. |

**Restricciones adicionales**

- Clave primaria compuesta `(id_grupo, id_estudiante)`
- CHECK `ck_miembro_grupo_rol`: rol IN ('ADMIN', 'MODERADOR', 'MIEMBRO')

## evento

Reuniones, talleres y actividades; el espacio es obligatorio si no es virtual.

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_evento` | INTEGER (ID) | NN | PK |  | Identificador autonumérico del evento. |
| `id_organizador` | INTEGER | NN | FK | estudiante.id_estudiante | Estudiante que organiza. |
| `id_grupo` | INTEGER | NULL | FK | grupo_estudio.id_grupo | Grupo que lo organiza (opcional). |
| `id_espacio` | INTEGER | NULL | FK | espacio.id_espacio | Espacio físico (NULL si es virtual). |
| `titulo` | VARCHAR(100) | NN |  |  | Título del evento. |
| `descripcion` | VARCHAR(1000) | NULL |  |  | Detalle del evento. |
| `fecha_inicio` | TIMESTAMP | NN |  |  | Inicio del evento. |
| `fecha_cierre` | TIMESTAMP | NN |  |  | Cierre del evento (no anterior al inicio). |
| `modalidad` | VARCHAR(10) | NN |  |  | PRESENCIAL, VIRTUAL o HIBRIDA. |

**Restricciones adicionales**

- CHECK `ck_evento_espacio`: (((modalidad) = 'VIRTUAL') OR (id_espacio IS NOT NULL))
- CHECK `ck_evento_fechas`: (fecha_cierre >= fecha_inicio)
- CHECK `ck_evento_modalidad`: modalidad IN ('PRESENCIAL', 'VIRTUAL', 'HIBRIDA')

## participacion_evento

Inscripción y asistencia de los estudiantes a los eventos (N:M).

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_estudiante` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante inscrito. |
| `id_evento` | INTEGER | NN | PK FK | evento.id_evento | Evento al que se inscribe. |
| `estado` | VARCHAR(12) (DEFAULT 'INSCRITO') | NN |  |  | INSCRITO, ASISTIO o CANCELADO. |
| `fecha_inscripcion` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Momento de la inscripción. |

**Restricciones adicionales**

- Clave primaria compuesta `(id_estudiante, id_evento)`
- CHECK `ck_participacion_evento_estado`: estado IN ('INSCRITO', 'ASISTIO', 'CANCELADO')

## acceso_recurso

Último acceso de un estudiante a un recurso académico (N:M).

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_estudiante` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante que consulta. |
| `id_recurso` | INTEGER | NN | PK FK | recurso_academico.id_recurso | Recurso consultado. |
| `fecha_ultimo_acceso` | TIMESTAMP (DEFAULT CURRENT_TIMESTAMP) | NN |  |  | Última consulta. |

**Restricciones adicionales**

- Clave primaria compuesta `(id_estudiante, id_recurso)`

## matricula

Cursos en los que está matriculado cada estudiante (N:M).

| Columna | Tipo | Nulo | Clave | Referencia | Descripción |
|---|---|---|---|---|---|
| `id_estudiante` | INTEGER | NN | PK FK | estudiante.id_estudiante | Estudiante matriculado. |
| `id_curso` | INTEGER | NN | PK FK | curso.id_curso | Curso en el que se matricula. |
| `fecha_matricula` | DATE (DEFAULT CURRENT_DATE) | NN |  |  | Fecha de la matrícula. |

**Restricciones adicionales**

- Clave primaria compuesta `(id_estudiante, id_curso)`
