/* ============================================================================
   Red Social Estudiantil Pascualina - Script DDL (modelo físico)
   SGBD ........ Microsoft SQL Server 2022 / Express (T-SQL)  (SGBD 3 de 3)
   Curso ....... Bases de Datos I - G100 (SD1006) - Tarea 4, Grupo 5
   Autor ....... Juan Camilo Villegas Ocampo
   Contenido ... 25 tablas, 34 claves foráneas, 22 índices y 2 columnas JSON (big data / IoT)

   Notas específicas del motor
   - SQL Server: IDENTITY(1,1), esquema red_social, NVARCHAR para texto con tildes, BIT para booleanos, DATETIME2.
   - SQL Server no tiene RESTRICT: NO ACTION cumple la misma función.
   - ON UPDATE NO ACTION en todas las claves foráneas: las columnas IDENTITY no se pueden actualizar.
   - No existe tipo JSON nativo en esta versión: se guarda en NVARCHAR(MAX) y se valida con ISJSON().
   - Error 1785 (varias rutas de cascada): en seguimiento.id_seguido y mentoria.id_aprendiz se usa NO ACTION.
   ============================================================================ */

IF DB_ID(N'red_social_pascualina') IS NULL CREATE DATABASE red_social_pascualina;
GO
USE red_social_pascualina;
GO
DROP TABLE IF EXISTS red_social.matricula;
DROP TABLE IF EXISTS red_social.acceso_recurso;
DROP TABLE IF EXISTS red_social.participacion_evento;
DROP TABLE IF EXISTS red_social.evento;
DROP TABLE IF EXISTS red_social.miembro_grupo;
DROP TABLE IF EXISTS red_social.grupo_estudio;
DROP TABLE IF EXISTS red_social.reaccion;
DROP TABLE IF EXISTS red_social.comentario;
DROP TABLE IF EXISTS red_social.publicacion;
DROP TABLE IF EXISTS red_social.mentoria;
DROP TABLE IF EXISTS red_social.seguimiento;
DROP TABLE IF EXISTS red_social.estudiante_habilidad;
DROP TABLE IF EXISTS red_social.estudiante_interes;
DROP TABLE IF EXISTS red_social.perfil;
DROP TABLE IF EXISTS red_social.estudiante;
DROP TABLE IF EXISTS red_social.curso;
DROP TABLE IF EXISTS red_social.espacio;
DROP TABLE IF EXISTS red_social.programa;
DROP TABLE IF EXISTS red_social.recurso_academico;
DROP TABLE IF EXISTS red_social.profesor;
DROP TABLE IF EXISTS red_social.materia;
DROP TABLE IF EXISTS red_social.habilidad;
DROP TABLE IF EXISTS red_social.interes;
DROP TABLE IF EXISTS red_social.sede;
DROP TABLE IF EXISTS red_social.facultad;
GO
IF SCHEMA_ID(N'red_social') IS NOT NULL DROP SCHEMA red_social;
GO
CREATE SCHEMA red_social;
GO

/* ----------------------------------------------------------------------------
   Tabla facultad
   Facultades de la universidad. Se separó de programa al normalizar (3FN) para no repetir su nombre.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.facultad (
    id_facultad       INT IDENTITY(1,1) NOT NULL,
    nombre_facultad   NVARCHAR(100) NOT NULL,
    CONSTRAINT pk_facultad PRIMARY KEY (id_facultad),
    CONSTRAINT uq_facultad_nombre UNIQUE (nombre_facultad)
);
GO

/* ----------------------------------------------------------------------------
   Tabla sede
   Sedes o campus de la universidad.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.sede (
    id_sede       INT IDENTITY(1,1) NOT NULL,
    nombre_sede   NVARCHAR(80) NOT NULL,
    direccion     NVARCHAR(150) NOT NULL,
    CONSTRAINT pk_sede PRIMARY KEY (id_sede),
    CONSTRAINT uq_sede_nombre UNIQUE (nombre_sede)
);
GO

/* ----------------------------------------------------------------------------
   Tabla interes
   Catálogo de intereses y pasatiempos (deportes, videojuegos, música, programación…).
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.interes (
    id_interes       INT IDENTITY(1,1) NOT NULL,
    nombre_interes   NVARCHAR(60) NOT NULL,
    tipo             NVARCHAR(20) NOT NULL,
    descripcion      NVARCHAR(255) NULL,
    CONSTRAINT pk_interes PRIMARY KEY (id_interes),
    CONSTRAINT uq_interes_nombre UNIQUE (nombre_interes),
    CONSTRAINT ck_interes_tipo CHECK (tipo IN ('ACADEMICO', 'DEPORTIVO', 'CULTURAL', 'TECNOLOGICO', 'OCIO'))
);
GO

/* ----------------------------------------------------------------------------
   Tabla habilidad
   Catálogo de habilidades (SQL, Python, diseño, fútbol…) que el caso pide para los perfiles.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.habilidad (
    id_habilidad       INT IDENTITY(1,1) NOT NULL,
    nombre_habilidad   NVARCHAR(60) NOT NULL,
    descripcion        NVARCHAR(255) NULL,
    CONSTRAINT pk_habilidad PRIMARY KEY (id_habilidad),
    CONSTRAINT uq_habilidad_nombre UNIQUE (nombre_habilidad)
);
GO

/* ----------------------------------------------------------------------------
   Tabla materia
   Asignaturas del plan de estudios. Se separó de curso al normalizar (3FN).
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.materia (
    id_materia       INT IDENTITY(1,1) NOT NULL,
    codigo_materia   NVARCHAR(15) NOT NULL,
    nombre_materia   NVARCHAR(100) NOT NULL,
    creditos         INT NOT NULL,
    CONSTRAINT pk_materia PRIMARY KEY (id_materia),
    CONSTRAINT uq_materia_codigo UNIQUE (codigo_materia),
    CONSTRAINT ck_materia_creditos CHECK (creditos BETWEEN 1 AND 10)
);
GO

/* ----------------------------------------------------------------------------
   Tabla profesor
   Docentes que dictan los cursos.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.profesor (
    id_profesor   INT IDENTITY(1,1) NOT NULL,
    nombre        NVARCHAR(50) NOT NULL,
    apellido      NVARCHAR(50) NOT NULL,
    email         NVARCHAR(100) NOT NULL,
    CONSTRAINT pk_profesor PRIMARY KEY (id_profesor),
    CONSTRAINT uq_profesor_email UNIQUE (email)
);
GO

/* ----------------------------------------------------------------------------
   Tabla recurso_academico
   Libros, guías, videos o enlaces que se comparten con la comunidad.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.recurso_academico (
    id_recurso     INT IDENTITY(1,1) NOT NULL,
    titulo         NVARCHAR(150) NOT NULL,
    url            NVARCHAR(255) NOT NULL,
    tipo_archivo   NVARCHAR(10) NOT NULL,
    CONSTRAINT pk_recurso_academico PRIMARY KEY (id_recurso),
    CONSTRAINT uq_recurso_academico_url UNIQUE (url),
    CONSTRAINT ck_recurso_academico_tipo CHECK (tipo_archivo IN ('PDF', 'DOC', 'VIDEO', 'ENLACE', 'IMAGEN'))
);
GO

/* ----------------------------------------------------------------------------
   Tabla programa
   Programas académicos (carreras) que ofrece la universidad.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.programa (
    id_programa       INT IDENTITY(1,1) NOT NULL,
    id_facultad       INT NOT NULL,
    nombre_programa   NVARCHAR(100) NOT NULL,
    CONSTRAINT pk_programa PRIMARY KEY (id_programa),
    CONSTRAINT uq_programa_nombre UNIQUE (nombre_programa),
    CONSTRAINT fk_programa_facultad FOREIGN KEY (id_facultad)
        REFERENCES red_social.facultad (id_facultad)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla espacio
   Aulas, laboratorios y auditorios donde hay clases o eventos.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.espacio (
    id_espacio       INT IDENTITY(1,1) NOT NULL,
    id_sede          INT NOT NULL,
    nombre_espacio   NVARCHAR(60) NOT NULL,
    bloque           NVARCHAR(10) NOT NULL,
    capacidad        INT NOT NULL,
    datos_iot        NVARCHAR(MAX) NULL,  -- Última lectura de los sensores IoT del espacio: ocupación, temperatura, CO2 (JSON).
    CONSTRAINT pk_espacio PRIMARY KEY (id_espacio),
    CONSTRAINT uq_espacio_sede_nombre_bloque UNIQUE (id_sede, nombre_espacio, bloque),
    CONSTRAINT ck_espacio_capacidad CHECK (capacidad > 0),
    CONSTRAINT ck_espacio_datos_iot_json CHECK (ISJSON(datos_iot) = 1),
    CONSTRAINT fk_espacio_sede FOREIGN KEY (id_sede)
        REFERENCES red_social.sede (id_sede)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla curso
   Grupo concreto de una materia en un periodo académico, con su profesor y su aula.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.curso (
    id_curso       INT IDENTITY(1,1) NOT NULL,
    id_materia     INT NOT NULL,
    id_profesor    INT NOT NULL,
    id_espacio     INT NOT NULL,
    periodo        NVARCHAR(6) NOT NULL,
    codigo_grupo   NVARCHAR(10) NOT NULL,
    CONSTRAINT pk_curso PRIMARY KEY (id_curso),
    CONSTRAINT uq_curso_materia_periodo_grupo UNIQUE (id_materia, periodo, codigo_grupo),
    CONSTRAINT ck_curso_periodo CHECK (periodo LIKE '[0-9][0-9][0-9][0-9]-[12]'),
    CONSTRAINT fk_curso_espacio FOREIGN KEY (id_espacio)
        REFERENCES red_social.espacio (id_espacio)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_curso_materia FOREIGN KEY (id_materia)
        REFERENCES red_social.materia (id_materia)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_curso_profesor FOREIGN KEY (id_profesor)
        REFERENCES red_social.profesor (id_profesor)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla estudiante
   Cuenta de cada estudiante de la red social. Es la tabla principal: casi todas las demás se conectan con ella. Los datos visibles del perfil se guardan aparte, en la tabla perfil.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.estudiante (
    id_estudiante       INT IDENTITY(1,1) NOT NULL,
    id_programa         INT NOT NULL,
    codigo_estudiante   NVARCHAR(15) NOT NULL,
    nombre              NVARCHAR(50) NOT NULL,
    apellido            NVARCHAR(50) NOT NULL,
    email               NVARCHAR(100) NOT NULL,
    contrasena_hash     NVARCHAR(255) NOT NULL,
    semestre            INT NOT NULL,
    fecha_registro      DATETIME2(0) CONSTRAINT df_estudiante_fecha_registro DEFAULT SYSDATETIME() NOT NULL,
    ultima_actividad    DATETIME2(0) NULL,
    estado              NVARCHAR(10) CONSTRAINT df_estudiante_estado DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT pk_estudiante PRIMARY KEY (id_estudiante),
    CONSTRAINT uq_estudiante_codigo UNIQUE (codigo_estudiante),
    CONSTRAINT uq_estudiante_email UNIQUE (email),
    CONSTRAINT ck_estudiante_estado CHECK (estado IN ('ACTIVO', 'INACTIVO', 'SUSPENDIDO')),
    CONSTRAINT ck_estudiante_semestre CHECK (semestre BETWEEN 1 AND 12),
    CONSTRAINT fk_estudiante_programa FOREIGN KEY (id_programa)
        REFERENCES red_social.programa (id_programa)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla perfil
   Datos que el estudiante muestra a los demás (biografía, foto, ciudad). Cada estudiante tiene un único perfil (relación 1:1).
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.perfil (
    id_perfil             INT IDENTITY(1,1) NOT NULL,
    id_estudiante         INT NOT NULL,
    biografia             NVARCHAR(500) NULL,
    foto_perfil           NVARCHAR(255) NULL,
    ciudad                NVARCHAR(60) NULL,
    fecha_actualizacion   DATETIME2(0) CONSTRAINT df_perfil_fecha_actualizacion DEFAULT SYSDATETIME() NOT NULL,
    CONSTRAINT pk_perfil PRIMARY KEY (id_perfil),
    CONSTRAINT uq_perfil_estudiante UNIQUE (id_estudiante),
    CONSTRAINT fk_perfil_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla estudiante_interes
   Tabla intermedia N:M entre estudiante e interes.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.estudiante_interes (
    id_estudiante    INT NOT NULL,
    id_interes       INT NOT NULL,
    fecha_agregado   DATETIME2(0) CONSTRAINT df_estudiante_interes_fecha_agregado DEFAULT SYSDATETIME() NOT NULL,
    CONSTRAINT pk_estudiante_interes PRIMARY KEY (id_estudiante, id_interes),
    CONSTRAINT fk_estudiante_interes_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_estudiante_interes_interes FOREIGN KEY (id_interes)
        REFERENCES red_social.interes (id_interes)
        ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla estudiante_habilidad
   Tabla intermedia N:M entre estudiante y habilidad; guarda el nivel de dominio.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.estudiante_habilidad (
    id_estudiante    INT NOT NULL,
    id_habilidad     INT NOT NULL,
    nivel            NVARCHAR(12) NOT NULL,
    fecha_agregado   DATETIME2(0) CONSTRAINT df_estudiante_habilidad_fecha_agregado DEFAULT SYSDATETIME() NOT NULL,
    CONSTRAINT pk_estudiante_habilidad PRIMARY KEY (id_estudiante, id_habilidad),
    CONSTRAINT ck_estudiante_habilidad_nivel CHECK (nivel IN ('BASICO', 'INTERMEDIO', 'AVANZADO')),
    CONSTRAINT fk_estudiante_habilidad_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_estudiante_habilidad_habilidad FOREIGN KEY (id_habilidad)
        REFERENCES red_social.habilidad (id_habilidad)
        ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla seguimiento
   Relación reflexiva N:M: un estudiante sigue a otro. Las dos columnas apuntan a estudiante.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.seguimiento (
    id_seguidor         INT NOT NULL,
    id_seguido          INT NOT NULL,
    fecha_seguimiento   DATETIME2(0) CONSTRAINT df_seguimiento_fecha_seguimiento DEFAULT SYSDATETIME() NOT NULL,
    CONSTRAINT pk_seguimiento PRIMARY KEY (id_seguidor, id_seguido),
    CONSTRAINT ck_seguimiento_distintos CHECK (id_seguidor <> id_seguido),
    CONSTRAINT fk_seguimiento_estudiante_seguido FOREIGN KEY (id_seguido)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_seguimiento_estudiante_seguidor FOREIGN KEY (id_seguidor)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla mentoria
   Relación reflexiva N:M: un estudiante mentor acompaña a un estudiante aprendiz, opcionalmente sobre una materia.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.mentoria (
    id_mentor      INT NOT NULL,
    id_aprendiz    INT NOT NULL,
    id_materia     INT NULL,
    fecha_inicio   DATETIME2(0) CONSTRAINT df_mentoria_fecha_inicio DEFAULT SYSDATETIME() NOT NULL,
    estado         NVARCHAR(12) CONSTRAINT df_mentoria_estado DEFAULT 'SOLICITADA' NOT NULL,
    CONSTRAINT pk_mentoria PRIMARY KEY (id_mentor, id_aprendiz),
    CONSTRAINT ck_mentoria_distintos CHECK (id_mentor <> id_aprendiz),
    CONSTRAINT ck_mentoria_estado CHECK (estado IN ('SOLICITADA', 'ACTIVA', 'FINALIZADA')),
    CONSTRAINT fk_mentoria_estudiante_aprendiz FOREIGN KEY (id_aprendiz)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_mentoria_estudiante_mentor FOREIGN KEY (id_mentor)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_mentoria_materia FOREIGN KEY (id_materia)
        REFERENCES red_social.materia (id_materia)
        ON DELETE SET NULL ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla publicacion
   Publicaciones del muro: preguntas, recursos, noticias, avisos o memes.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.publicacion (
    id_publicacion     INT IDENTITY(1,1) NOT NULL,
    id_autor           INT NOT NULL,
    contenido          NVARCHAR(MAX) NOT NULL,
    tipo_publicacion   NVARCHAR(20) NOT NULL,
    fecha_creacion     DATETIME2(0) CONSTRAINT df_publicacion_fecha_creacion DEFAULT SYSDATETIME() NOT NULL,
    metadatos          NVARCHAR(MAX) NULL,  -- Etiquetas, adjuntos y geoubicación de la publicación (JSON).
    CONSTRAINT pk_publicacion PRIMARY KEY (id_publicacion),
    CONSTRAINT ck_publicacion_tipo CHECK (tipo_publicacion IN ('PREGUNTA', 'RECURSO', 'NOTICIA', 'AVISO', 'MEME')),
    CONSTRAINT ck_publicacion_metadatos_json CHECK (ISJSON(metadatos) = 1),
    CONSTRAINT fk_publicacion_estudiante_autor FOREIGN KEY (id_autor)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla comentario
   Respuestas que escriben los estudiantes en una publicación.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.comentario (
    id_comentario      INT IDENTITY(1,1) NOT NULL,
    id_publicacion     INT NOT NULL,
    id_autor           INT NOT NULL,
    contenido          NVARCHAR(1000) NOT NULL,
    fecha_comentario   DATETIME2(0) CONSTRAINT df_comentario_fecha_comentario DEFAULT SYSDATETIME() NOT NULL,
    CONSTRAINT pk_comentario PRIMARY KEY (id_comentario),
    CONSTRAINT fk_comentario_estudiante_autor FOREIGN KEY (id_autor)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_comentario_publicacion FOREIGN KEY (id_publicacion)
        REFERENCES red_social.publicacion (id_publicacion)
        ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla reaccion
   Reacciones de un clic (me gusta, útil…) de un estudiante sobre una publicación.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.reaccion (
    id_estudiante    INT NOT NULL,
    id_publicacion   INT NOT NULL,
    tipo_reaccion    NVARCHAR(15) NOT NULL,
    fecha_reaccion   DATETIME2(0) CONSTRAINT df_reaccion_fecha_reaccion DEFAULT SYSDATETIME() NOT NULL,
    CONSTRAINT pk_reaccion PRIMARY KEY (id_estudiante, id_publicacion),
    CONSTRAINT ck_reaccion_tipo CHECK (tipo_reaccion IN ('ME_GUSTA', 'ME_ENCANTA', 'ME_DIVIERTE', 'UTIL')),
    CONSTRAINT fk_reaccion_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_reaccion_publicacion FOREIGN KEY (id_publicacion)
        REFERENCES red_social.publicacion (id_publicacion)
        ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla grupo_estudio
   Grupos de estudio, equipos de hackatón, clubes o semilleros creados por estudiantes.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.grupo_estudio (
    id_grupo         INT IDENTITY(1,1) NOT NULL,
    id_creador       INT NOT NULL,
    id_materia       INT NULL,
    nombre_grupo     NVARCHAR(80) NOT NULL,
    descripcion      NVARCHAR(500) NULL,
    tipo             NVARCHAR(20) NOT NULL,
    es_privado       BIT CONSTRAINT df_grupo_estudio_es_privado DEFAULT 0 NOT NULL,
    estado           NVARCHAR(10) CONSTRAINT df_grupo_estudio_estado DEFAULT 'ACTIVO' NOT NULL,
    fecha_creacion   DATETIME2(0) CONSTRAINT df_grupo_estudio_fecha_creacion DEFAULT SYSDATETIME() NOT NULL,
    CONSTRAINT pk_grupo_estudio PRIMARY KEY (id_grupo),
    CONSTRAINT ck_grupo_estudio_estado CHECK (estado IN ('ACTIVO', 'ARCHIVADO')),
    CONSTRAINT ck_grupo_estudio_tipo CHECK (tipo IN ('ESTUDIO', 'HACKATON', 'CLUB', 'SEMILLERO')),
    CONSTRAINT fk_grupo_estudio_estudiante_creador FOREIGN KEY (id_creador)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_grupo_estudio_materia FOREIGN KEY (id_materia)
        REFERENCES red_social.materia (id_materia)
        ON DELETE SET NULL ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla miembro_grupo
   Tabla intermedia N:M: qué estudiantes pertenecen a cada grupo y con qué rol.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.miembro_grupo (
    id_grupo        INT NOT NULL,
    id_estudiante   INT NOT NULL,
    rol             NVARCHAR(15) CONSTRAINT df_miembro_grupo_rol DEFAULT 'MIEMBRO' NOT NULL,
    fecha_ingreso   DATETIME2(0) CONSTRAINT df_miembro_grupo_fecha_ingreso DEFAULT SYSDATETIME() NOT NULL,
    CONSTRAINT pk_miembro_grupo PRIMARY KEY (id_grupo, id_estudiante),
    CONSTRAINT ck_miembro_grupo_rol CHECK (rol IN ('ADMIN', 'MODERADOR', 'MIEMBRO')),
    CONSTRAINT fk_miembro_grupo_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_miembro_grupo_grupo_estudio FOREIGN KEY (id_grupo)
        REFERENCES red_social.grupo_estudio (id_grupo)
        ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla evento
   Reuniones de estudio, talleres, torneos o actividades del campus.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.evento (
    id_evento        INT IDENTITY(1,1) NOT NULL,
    id_organizador   INT NOT NULL,
    id_grupo         INT NULL,
    id_espacio       INT NULL,
    titulo           NVARCHAR(100) NOT NULL,
    descripcion      NVARCHAR(1000) NULL,
    fecha_inicio     DATETIME2(0) NOT NULL,
    fecha_cierre     DATETIME2(0) NOT NULL,
    modalidad        NVARCHAR(10) NOT NULL,
    CONSTRAINT pk_evento PRIMARY KEY (id_evento),
    CONSTRAINT ck_evento_espacio CHECK (modalidad = 'VIRTUAL' OR id_espacio IS NOT NULL),
    CONSTRAINT ck_evento_fechas CHECK (fecha_cierre >= fecha_inicio),
    CONSTRAINT ck_evento_modalidad CHECK (modalidad IN ('PRESENCIAL', 'VIRTUAL', 'HIBRIDA')),
    CONSTRAINT fk_evento_espacio FOREIGN KEY (id_espacio)
        REFERENCES red_social.espacio (id_espacio)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_evento_estudiante_organizador FOREIGN KEY (id_organizador)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_evento_grupo_estudio FOREIGN KEY (id_grupo)
        REFERENCES red_social.grupo_estudio (id_grupo)
        ON DELETE SET NULL ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla participacion_evento
   Tabla intermedia N:M: inscripción y asistencia de los estudiantes a los eventos.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.participacion_evento (
    id_estudiante       INT NOT NULL,
    id_evento           INT NOT NULL,
    estado              NVARCHAR(12) CONSTRAINT df_participacion_evento_estado DEFAULT 'INSCRITO' NOT NULL,
    fecha_inscripcion   DATETIME2(0) CONSTRAINT df_participacion_evento_fecha_inscripcion DEFAULT SYSDATETIME() NOT NULL,
    CONSTRAINT pk_participacion_evento PRIMARY KEY (id_estudiante, id_evento),
    CONSTRAINT ck_participacion_evento_estado CHECK (estado IN ('INSCRITO', 'ASISTIO', 'CANCELADO')),
    CONSTRAINT fk_participacion_evento_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_participacion_evento_evento FOREIGN KEY (id_evento)
        REFERENCES red_social.evento (id_evento)
        ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla acceso_recurso
   Tabla intermedia N:M: qué recursos consulta cada estudiante.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.acceso_recurso (
    id_estudiante         INT NOT NULL,
    id_recurso            INT NOT NULL,
    fecha_ultimo_acceso   DATETIME2(0) CONSTRAINT df_acceso_recurso_fecha_ultimo_acceso DEFAULT SYSDATETIME() NOT NULL,
    CONSTRAINT pk_acceso_recurso PRIMARY KEY (id_estudiante, id_recurso),
    CONSTRAINT fk_acceso_recurso_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT fk_acceso_recurso_recurso_academico FOREIGN KEY (id_recurso)
        REFERENCES red_social.recurso_academico (id_recurso)
        ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Tabla matricula
   Tabla intermedia N:M: en qué cursos está matriculado cada estudiante.
   ---------------------------------------------------------------------------- */
CREATE TABLE red_social.matricula (
    id_estudiante     INT NOT NULL,
    id_curso          INT NOT NULL,
    fecha_matricula   DATE CONSTRAINT df_matricula_fecha_matricula DEFAULT CONVERT(date, SYSDATETIME()) NOT NULL,
    CONSTRAINT pk_matricula PRIMARY KEY (id_estudiante, id_curso),
    CONSTRAINT fk_matricula_curso FOREIGN KEY (id_curso)
        REFERENCES red_social.curso (id_curso)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT fk_matricula_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES red_social.estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

/* ----------------------------------------------------------------------------
   Índices sobre claves foráneas (aceleran JOIN y comprobaciones de borrado)
   ---------------------------------------------------------------------------- */
CREATE INDEX idx_programa_facultad ON red_social.programa (id_facultad);
CREATE INDEX idx_estudiante_programa ON red_social.estudiante (id_programa);
CREATE INDEX idx_estudiante_interes_interes ON red_social.estudiante_interes (id_interes);
CREATE INDEX idx_estudiante_habilidad_habil ON red_social.estudiante_habilidad (id_habilidad);
CREATE INDEX idx_seguimiento_seguido ON red_social.seguimiento (id_seguido);
CREATE INDEX idx_mentoria_aprendiz ON red_social.mentoria (id_aprendiz);
CREATE INDEX idx_mentoria_materia ON red_social.mentoria (id_materia);
CREATE INDEX idx_publicacion_autor ON red_social.publicacion (id_autor);
CREATE INDEX idx_comentario_publicacion ON red_social.comentario (id_publicacion);
CREATE INDEX idx_comentario_autor ON red_social.comentario (id_autor);
CREATE INDEX idx_reaccion_publicacion ON red_social.reaccion (id_publicacion);
CREATE INDEX idx_grupo_estudio_creador ON red_social.grupo_estudio (id_creador);
CREATE INDEX idx_grupo_estudio_materia ON red_social.grupo_estudio (id_materia);
CREATE INDEX idx_miembro_grupo_estudiante ON red_social.miembro_grupo (id_estudiante);
CREATE INDEX idx_evento_organizador ON red_social.evento (id_organizador);
CREATE INDEX idx_evento_grupo ON red_social.evento (id_grupo);
CREATE INDEX idx_evento_espacio ON red_social.evento (id_espacio);
CREATE INDEX idx_participacion_evento_evento ON red_social.participacion_evento (id_evento);
CREATE INDEX idx_acceso_recurso_recurso ON red_social.acceso_recurso (id_recurso);
CREATE INDEX idx_curso_profesor ON red_social.curso (id_profesor);
CREATE INDEX idx_curso_espacio ON red_social.curso (id_espacio);
CREATE INDEX idx_matricula_curso ON red_social.matricula (id_curso);
GO

