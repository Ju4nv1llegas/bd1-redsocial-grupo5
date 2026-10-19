/* =============================================================================
   Red Social Estudiantil Pascualina - Script DDL (modelo fisico)
   SGBD ........ PostgreSQL 16 (compatible con 13 o superior)
   Curso ....... Bases de Datos I - G100 (SD1006) - Tarea 3, Grupo 5
   Origen ...... Modelo logico de la Tarea 2 (25 tablas, 34 claves foraneas, 3FN)

   Convenciones de nomenclatura
   - Tablas y columnas en minusculas, snake_case y sin tildes ni enie.
   - Nombre de tabla en singular (estudiante, perfil, ...).
   - Clave primaria surrogate: id_<tabla>; las FK conservan el nombre de la PK
     referenciada (salvo roles: id_autor, id_seguidor, id_mentor, ...).
   - Restricciones con nombre explicito:
       pk_<tabla> | fk_<hija>_<padre>[_<rol>] | uq_<tabla>_<columna(s)>
       ck_<tabla>_<regla> | idx_<tabla>_<columna>
   - DATETIME del modelo logico -> TIMESTAMP; INT -> INTEGER;
     las PK simples se generan con IDENTITY.
   - Orden de creacion: de las tablas padre hacia las hijas.
   ============================================================================= */

DROP SCHEMA IF EXISTS red_social CASCADE;
CREATE SCHEMA red_social;
SET search_path TO red_social;

/* -----------------------------------------------------------------------------
   1. Tablas catalogo sin dependencias: facultad, sede, interes, habilidad,
      materia, profesor, recurso_academico
   ----------------------------------------------------------------------------- */

CREATE TABLE facultad (
    id_facultad      INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre_facultad  VARCHAR(100) NOT NULL,
    CONSTRAINT pk_facultad PRIMARY KEY (id_facultad),
    CONSTRAINT uq_facultad_nombre UNIQUE (nombre_facultad)
);

CREATE TABLE sede (
    id_sede      INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre_sede  VARCHAR(80)  NOT NULL,
    direccion    VARCHAR(150) NOT NULL,
    CONSTRAINT pk_sede PRIMARY KEY (id_sede),
    CONSTRAINT uq_sede_nombre UNIQUE (nombre_sede)
);

CREATE TABLE interes (
    id_interes      INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre_interes  VARCHAR(60)  NOT NULL,
    tipo            VARCHAR(20)  NOT NULL,
    descripcion     VARCHAR(255),
    CONSTRAINT pk_interes PRIMARY KEY (id_interes),
    CONSTRAINT uq_interes_nombre UNIQUE (nombre_interes),
    CONSTRAINT ck_interes_tipo CHECK (tipo IN
        ('ACADEMICO', 'DEPORTIVO', 'CULTURAL', 'TECNOLOGICO', 'OCIO'))
);

CREATE TABLE habilidad (
    id_habilidad      INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre_habilidad  VARCHAR(60) NOT NULL,
    descripcion       VARCHAR(255),
    CONSTRAINT pk_habilidad PRIMARY KEY (id_habilidad),
    CONSTRAINT uq_habilidad_nombre UNIQUE (nombre_habilidad)
);

CREATE TABLE materia (
    id_materia      INTEGER GENERATED ALWAYS AS IDENTITY,
    codigo_materia  VARCHAR(15)  NOT NULL,
    nombre_materia  VARCHAR(100) NOT NULL,
    creditos        INTEGER      NOT NULL,
    CONSTRAINT pk_materia PRIMARY KEY (id_materia),
    CONSTRAINT uq_materia_codigo UNIQUE (codigo_materia),
    CONSTRAINT ck_materia_creditos CHECK (creditos BETWEEN 1 AND 10)
);

CREATE TABLE profesor (
    id_profesor  INTEGER GENERATED ALWAYS AS IDENTITY,
    nombre       VARCHAR(50)  NOT NULL,
    apellido     VARCHAR(50)  NOT NULL,
    email        VARCHAR(100) NOT NULL,
    CONSTRAINT pk_profesor PRIMARY KEY (id_profesor),
    CONSTRAINT uq_profesor_email UNIQUE (email)
);

CREATE TABLE recurso_academico (
    id_recurso    INTEGER GENERATED ALWAYS AS IDENTITY,
    titulo        VARCHAR(150) NOT NULL,
    url           VARCHAR(255) NOT NULL,
    tipo_archivo  VARCHAR(10)  NOT NULL,
    CONSTRAINT pk_recurso_academico PRIMARY KEY (id_recurso),
    CONSTRAINT uq_recurso_academico_url UNIQUE (url),
    CONSTRAINT ck_recurso_academico_tipo CHECK (tipo_archivo IN
        ('PDF', 'DOC', 'VIDEO', 'ENLACE', 'IMAGEN'))
);

/* -----------------------------------------------------------------------------
   2. Estructura academica: programa, espacio, curso
   ----------------------------------------------------------------------------- */

CREATE TABLE programa (
    id_programa      INTEGER GENERATED ALWAYS AS IDENTITY,
    id_facultad      INTEGER      NOT NULL,
    nombre_programa  VARCHAR(100) NOT NULL,
    CONSTRAINT pk_programa PRIMARY KEY (id_programa),
    CONSTRAINT uq_programa_nombre UNIQUE (nombre_programa),
    CONSTRAINT fk_programa_facultad FOREIGN KEY (id_facultad)
        REFERENCES facultad (id_facultad)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE espacio (
    id_espacio      INTEGER GENERATED ALWAYS AS IDENTITY,
    id_sede         INTEGER     NOT NULL,
    nombre_espacio  VARCHAR(60) NOT NULL,
    bloque          VARCHAR(10) NOT NULL,
    capacidad       INTEGER     NOT NULL,
    CONSTRAINT pk_espacio PRIMARY KEY (id_espacio),
    CONSTRAINT uq_espacio_sede_nombre_bloque UNIQUE (id_sede, nombre_espacio, bloque),
    CONSTRAINT ck_espacio_capacidad CHECK (capacidad > 0),
    CONSTRAINT fk_espacio_sede FOREIGN KEY (id_sede)
        REFERENCES sede (id_sede)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE curso (
    id_curso      INTEGER GENERATED ALWAYS AS IDENTITY,
    id_materia    INTEGER     NOT NULL,
    id_profesor   INTEGER     NOT NULL,
    id_espacio    INTEGER     NOT NULL,
    periodo       VARCHAR(6)  NOT NULL,
    codigo_grupo  VARCHAR(10) NOT NULL,
    CONSTRAINT pk_curso PRIMARY KEY (id_curso),
    CONSTRAINT uq_curso_materia_periodo_grupo UNIQUE (id_materia, periodo, codigo_grupo),
    CONSTRAINT ck_curso_periodo CHECK (periodo ~ '^[0-9]{4}-[12]$'),
    CONSTRAINT fk_curso_materia FOREIGN KEY (id_materia)
        REFERENCES materia (id_materia)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_curso_profesor FOREIGN KEY (id_profesor)
        REFERENCES profesor (id_profesor)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_curso_espacio FOREIGN KEY (id_espacio)
        REFERENCES espacio (id_espacio)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

/* -----------------------------------------------------------------------------
   3. Nucleo social: estudiante y perfil
   ----------------------------------------------------------------------------- */

CREATE TABLE estudiante (
    id_estudiante      INTEGER GENERATED ALWAYS AS IDENTITY,
    id_programa        INTEGER      NOT NULL,
    codigo_estudiante  VARCHAR(15)  NOT NULL,
    nombre             VARCHAR(50)  NOT NULL,
    apellido           VARCHAR(50)  NOT NULL,
    email              VARCHAR(100) NOT NULL,
    contrasena_hash    VARCHAR(255) NOT NULL,
    semestre           INTEGER      NOT NULL,
    fecha_registro     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultima_actividad   TIMESTAMP,
    estado             VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT pk_estudiante PRIMARY KEY (id_estudiante),
    CONSTRAINT uq_estudiante_codigo UNIQUE (codigo_estudiante),
    CONSTRAINT uq_estudiante_email UNIQUE (email),
    CONSTRAINT ck_estudiante_semestre CHECK (semestre BETWEEN 1 AND 12),
    CONSTRAINT ck_estudiante_estado CHECK (estado IN
        ('ACTIVO', 'INACTIVO', 'SUSPENDIDO')),
    CONSTRAINT fk_estudiante_programa FOREIGN KEY (id_programa)
        REFERENCES programa (id_programa)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE perfil (
    id_perfil            INTEGER GENERATED ALWAYS AS IDENTITY,
    id_estudiante        INTEGER      NOT NULL,
    biografia            VARCHAR(500),
    foto_perfil          VARCHAR(255),
    ciudad               VARCHAR(60),
    fecha_actualizacion  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_perfil PRIMARY KEY (id_perfil),
    CONSTRAINT uq_perfil_estudiante UNIQUE (id_estudiante),   -- relacion 1:1
    CONSTRAINT fk_perfil_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE
);

/* -----------------------------------------------------------------------------
   4. Intereses, habilidades, seguimiento y mentoria
   ----------------------------------------------------------------------------- */

CREATE TABLE estudiante_interes (
    id_estudiante   INTEGER   NOT NULL,
    id_interes      INTEGER   NOT NULL,
    fecha_agregado  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_estudiante_interes PRIMARY KEY (id_estudiante, id_interes),
    CONSTRAINT fk_estudiante_interes_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_estudiante_interes_interes FOREIGN KEY (id_interes)
        REFERENCES interes (id_interes)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE estudiante_habilidad (
    id_estudiante   INTEGER     NOT NULL,
    id_habilidad    INTEGER     NOT NULL,
    nivel           VARCHAR(12) NOT NULL,
    fecha_agregado  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_estudiante_habilidad PRIMARY KEY (id_estudiante, id_habilidad),
    CONSTRAINT ck_estudiante_habilidad_nivel CHECK (nivel IN
        ('BASICO', 'INTERMEDIO', 'AVANZADO')),
    CONSTRAINT fk_estudiante_habilidad_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_estudiante_habilidad_habilidad FOREIGN KEY (id_habilidad)
        REFERENCES habilidad (id_habilidad)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE seguimiento (
    id_seguidor        INTEGER   NOT NULL,
    id_seguido         INTEGER   NOT NULL,
    fecha_seguimiento  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_seguimiento PRIMARY KEY (id_seguidor, id_seguido),
    CONSTRAINT ck_seguimiento_distintos CHECK (id_seguidor <> id_seguido),
    CONSTRAINT fk_seguimiento_estudiante_seguidor FOREIGN KEY (id_seguidor)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_seguimiento_estudiante_seguido FOREIGN KEY (id_seguido)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE mentoria (
    id_mentor     INTEGER     NOT NULL,
    id_aprendiz   INTEGER     NOT NULL,
    id_materia    INTEGER,
    fecha_inicio  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado        VARCHAR(12) NOT NULL DEFAULT 'SOLICITADA',
    CONSTRAINT pk_mentoria PRIMARY KEY (id_mentor, id_aprendiz),
    CONSTRAINT ck_mentoria_distintos CHECK (id_mentor <> id_aprendiz),
    CONSTRAINT ck_mentoria_estado CHECK (estado IN
        ('SOLICITADA', 'ACTIVA', 'FINALIZADA')),
    CONSTRAINT fk_mentoria_estudiante_mentor FOREIGN KEY (id_mentor)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mentoria_estudiante_aprendiz FOREIGN KEY (id_aprendiz)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mentoria_materia FOREIGN KEY (id_materia)
        REFERENCES materia (id_materia)
        ON DELETE SET NULL ON UPDATE CASCADE
);

/* -----------------------------------------------------------------------------
   5. Publicaciones, comentarios y reacciones
   ----------------------------------------------------------------------------- */

CREATE TABLE publicacion (
    id_publicacion    INTEGER GENERATED ALWAYS AS IDENTITY,
    id_autor          INTEGER     NOT NULL,
    contenido         TEXT        NOT NULL,
    tipo_publicacion  VARCHAR(20) NOT NULL,
    fecha_creacion    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_publicacion PRIMARY KEY (id_publicacion),
    CONSTRAINT ck_publicacion_tipo CHECK (tipo_publicacion IN
        ('PREGUNTA', 'RECURSO', 'NOTICIA', 'AVISO', 'MEME')),
    CONSTRAINT fk_publicacion_estudiante_autor FOREIGN KEY (id_autor)
        REFERENCES estudiante (id_estudiante)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE comentario (
    id_comentario    INTEGER GENERATED ALWAYS AS IDENTITY,
    id_publicacion   INTEGER       NOT NULL,
    id_autor         INTEGER       NOT NULL,
    contenido        VARCHAR(1000) NOT NULL,
    fecha_comentario TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_comentario PRIMARY KEY (id_comentario),
    CONSTRAINT fk_comentario_publicacion FOREIGN KEY (id_publicacion)
        REFERENCES publicacion (id_publicacion)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_comentario_estudiante_autor FOREIGN KEY (id_autor)
        REFERENCES estudiante (id_estudiante)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE reaccion (
    id_estudiante   INTEGER     NOT NULL,
    id_publicacion  INTEGER     NOT NULL,
    tipo_reaccion   VARCHAR(15) NOT NULL,
    fecha_reaccion  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_reaccion PRIMARY KEY (id_estudiante, id_publicacion),
    CONSTRAINT ck_reaccion_tipo CHECK (tipo_reaccion IN
        ('ME_GUSTA', 'ME_ENCANTA', 'ME_DIVIERTE', 'UTIL')),
    CONSTRAINT fk_reaccion_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_reaccion_publicacion FOREIGN KEY (id_publicacion)
        REFERENCES publicacion (id_publicacion)
        ON DELETE CASCADE ON UPDATE CASCADE
);

/* -----------------------------------------------------------------------------
   6. Grupos de estudio y miembros
   ----------------------------------------------------------------------------- */

CREATE TABLE grupo_estudio (
    id_grupo        INTEGER GENERATED ALWAYS AS IDENTITY,
    id_creador      INTEGER      NOT NULL,
    id_materia      INTEGER,
    nombre_grupo    VARCHAR(80)  NOT NULL,
    descripcion     VARCHAR(500),
    tipo            VARCHAR(20)  NOT NULL,
    es_privado      BOOLEAN      NOT NULL DEFAULT FALSE,
    estado          VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO',
    fecha_creacion  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_grupo_estudio PRIMARY KEY (id_grupo),
    CONSTRAINT ck_grupo_estudio_tipo CHECK (tipo IN
        ('ESTUDIO', 'HACKATON', 'CLUB', 'SEMILLERO')),
    CONSTRAINT ck_grupo_estudio_estado CHECK (estado IN ('ACTIVO', 'ARCHIVADO')),
    CONSTRAINT fk_grupo_estudio_estudiante_creador FOREIGN KEY (id_creador)
        REFERENCES estudiante (id_estudiante)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_grupo_estudio_materia FOREIGN KEY (id_materia)
        REFERENCES materia (id_materia)
        ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE miembro_grupo (
    id_grupo       INTEGER     NOT NULL,
    id_estudiante  INTEGER     NOT NULL,
    rol            VARCHAR(15) NOT NULL DEFAULT 'MIEMBRO',
    fecha_ingreso  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_miembro_grupo PRIMARY KEY (id_grupo, id_estudiante),
    CONSTRAINT ck_miembro_grupo_rol CHECK (rol IN
        ('ADMIN', 'MODERADOR', 'MIEMBRO')),
    CONSTRAINT fk_miembro_grupo_grupo_estudio FOREIGN KEY (id_grupo)
        REFERENCES grupo_estudio (id_grupo)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_miembro_grupo_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE
);

/* -----------------------------------------------------------------------------
   7. Eventos y participacion
   ----------------------------------------------------------------------------- */

CREATE TABLE evento (
    id_evento        INTEGER GENERATED ALWAYS AS IDENTITY,
    id_organizador   INTEGER       NOT NULL,
    id_grupo         INTEGER,
    id_espacio       INTEGER,
    titulo           VARCHAR(100)  NOT NULL,
    descripcion      VARCHAR(1000),
    fecha_inicio     TIMESTAMP     NOT NULL,
    fecha_cierre     TIMESTAMP     NOT NULL,
    modalidad        VARCHAR(10)   NOT NULL,
    CONSTRAINT pk_evento PRIMARY KEY (id_evento),
    CONSTRAINT ck_evento_fechas CHECK (fecha_cierre >= fecha_inicio),
    CONSTRAINT ck_evento_modalidad CHECK (modalidad IN
        ('PRESENCIAL', 'VIRTUAL', 'HIBRIDA')),
    -- id_espacio es obligatorio salvo que el evento sea virtual
    CONSTRAINT ck_evento_espacio CHECK (modalidad = 'VIRTUAL' OR id_espacio IS NOT NULL),
    CONSTRAINT fk_evento_estudiante_organizador FOREIGN KEY (id_organizador)
        REFERENCES estudiante (id_estudiante)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_evento_grupo_estudio FOREIGN KEY (id_grupo)
        REFERENCES grupo_estudio (id_grupo)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_evento_espacio FOREIGN KEY (id_espacio)
        REFERENCES espacio (id_espacio)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE participacion_evento (
    id_estudiante      INTEGER     NOT NULL,
    id_evento          INTEGER     NOT NULL,
    estado             VARCHAR(12) NOT NULL DEFAULT 'INSCRITO',
    fecha_inscripcion  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_participacion_evento PRIMARY KEY (id_estudiante, id_evento),
    CONSTRAINT ck_participacion_evento_estado CHECK (estado IN
        ('INSCRITO', 'ASISTIO', 'CANCELADO')),
    CONSTRAINT fk_participacion_evento_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_participacion_evento_evento FOREIGN KEY (id_evento)
        REFERENCES evento (id_evento)
        ON DELETE CASCADE ON UPDATE CASCADE
);

/* -----------------------------------------------------------------------------
   8. Recursos consultados y matriculas
   ----------------------------------------------------------------------------- */

CREATE TABLE acceso_recurso (
    id_estudiante         INTEGER   NOT NULL,
    id_recurso            INTEGER   NOT NULL,
    fecha_ultimo_acceso   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_acceso_recurso PRIMARY KEY (id_estudiante, id_recurso),
    CONSTRAINT fk_acceso_recurso_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_acceso_recurso_recurso_academico FOREIGN KEY (id_recurso)
        REFERENCES recurso_academico (id_recurso)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matricula (
    id_estudiante    INTEGER NOT NULL,
    id_curso         INTEGER NOT NULL,
    fecha_matricula  DATE    NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_matricula PRIMARY KEY (id_estudiante, id_curso),
    CONSTRAINT fk_matricula_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_matricula_curso FOREIGN KEY (id_curso)
        REFERENCES curso (id_curso)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

/* -----------------------------------------------------------------------------
   9. Indices sobre claves foraneas que no son prefijo de una PK/UNIQUE
      (PostgreSQL no los crea automaticamente; aceleran JOIN y borrados)
   ----------------------------------------------------------------------------- */

CREATE INDEX idx_programa_facultad            ON programa (id_facultad);
CREATE INDEX idx_estudiante_programa          ON estudiante (id_programa);
CREATE INDEX idx_estudiante_interes_interes   ON estudiante_interes (id_interes);
CREATE INDEX idx_estudiante_habilidad_habil   ON estudiante_habilidad (id_habilidad);
CREATE INDEX idx_seguimiento_seguido          ON seguimiento (id_seguido);
CREATE INDEX idx_mentoria_aprendiz            ON mentoria (id_aprendiz);
CREATE INDEX idx_mentoria_materia             ON mentoria (id_materia);
CREATE INDEX idx_publicacion_autor            ON publicacion (id_autor);
CREATE INDEX idx_comentario_publicacion       ON comentario (id_publicacion);
CREATE INDEX idx_comentario_autor             ON comentario (id_autor);
CREATE INDEX idx_reaccion_publicacion         ON reaccion (id_publicacion);
CREATE INDEX idx_grupo_estudio_creador        ON grupo_estudio (id_creador);
CREATE INDEX idx_grupo_estudio_materia        ON grupo_estudio (id_materia);
CREATE INDEX idx_miembro_grupo_estudiante     ON miembro_grupo (id_estudiante);
CREATE INDEX idx_evento_organizador           ON evento (id_organizador);
CREATE INDEX idx_evento_grupo                 ON evento (id_grupo);
CREATE INDEX idx_evento_espacio               ON evento (id_espacio);
CREATE INDEX idx_participacion_evento_evento  ON participacion_evento (id_evento);
CREATE INDEX idx_acceso_recurso_recurso       ON acceso_recurso (id_recurso);
CREATE INDEX idx_curso_profesor               ON curso (id_profesor);
CREATE INDEX idx_curso_espacio                ON curso (id_espacio);
CREATE INDEX idx_matricula_curso              ON matricula (id_curso);

/* -----------------------------------------------------------------------------
   10. Comentarios en el catalogo (documentan el modelo dentro del SGBD)
   ----------------------------------------------------------------------------- */

COMMENT ON TABLE estudiante           IS 'Cuenta de cada estudiante de la red social.';
COMMENT ON TABLE perfil               IS 'Datos publicos del estudiante (relacion 1:1).';
COMMENT ON TABLE seguimiento          IS 'Relacion N:M reflexiva: un estudiante sigue a otro.';
COMMENT ON TABLE mentoria             IS 'Relacion N:M reflexiva: mentor y aprendiz.';
COMMENT ON TABLE evento               IS 'Reuniones, talleres y actividades; espacio obligatorio si no es virtual.';
COMMENT ON COLUMN estudiante.contrasena_hash IS 'Solo se almacena el hash de la contrasena, nunca el texto plano.';
