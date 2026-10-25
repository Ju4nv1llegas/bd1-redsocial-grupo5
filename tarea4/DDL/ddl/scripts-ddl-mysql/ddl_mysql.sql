/* ============================================================================
   Red Social Estudiantil Pascualina - Script DDL (modelo físico)
   SGBD ........ MySQL 8 (motor InnoDB)  (SGBD 2 de 3)
   Curso ....... Bases de Datos I - G100 (SD1006) - Tarea 4, Grupo 5
   Autor ....... Juan Camilo Villegas Ocampo
   Contenido ... 25 tablas, 34 claves foráneas, 22 índices y 2 columnas JSON (big data / IoT)

   Notas específicas del motor
   - MySQL: AUTO_INCREMENT, motor InnoDB (obligatorio para claves foráneas), utf8mb4, tipo JSON nativo.
   - En MySQL esquema y base de datos son lo mismo: se crea la base red_social_pascualina.
   - BOOLEAN es un alias de TINYINT(1). TIMESTAMP se traduce a DATETIME.
   - Error 3823: MySQL no permite un CHECK sobre una columna que tenga una acción referencial CASCADE/SET NULL.
   -   - seguimiento y mentoria: las reglas 'distintos' se implementan con triggers BEFORE INSERT/UPDATE.
   -   - evento.id_espacio: ON UPDATE RESTRICT (las claves son autoincrementales y no cambian).
   ============================================================================ */

DROP DATABASE IF EXISTS red_social_pascualina;
CREATE DATABASE red_social_pascualina CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE red_social_pascualina;
SET FOREIGN_KEY_CHECKS = 1;

/* ----------------------------------------------------------------------------
   Tabla facultad
   Facultades de la universidad. Se separó de programa al normalizar (3FN) para no repetir su nombre.
   ---------------------------------------------------------------------------- */
CREATE TABLE facultad (
    id_facultad       INT AUTO_INCREMENT NOT NULL,
    nombre_facultad   VARCHAR(100) NOT NULL,
    CONSTRAINT pk_facultad PRIMARY KEY (id_facultad),
    CONSTRAINT uq_facultad_nombre UNIQUE (nombre_facultad)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla sede
   Sedes o campus de la universidad.
   ---------------------------------------------------------------------------- */
CREATE TABLE sede (
    id_sede       INT AUTO_INCREMENT NOT NULL,
    nombre_sede   VARCHAR(80) NOT NULL,
    direccion     VARCHAR(150) NOT NULL,
    CONSTRAINT pk_sede PRIMARY KEY (id_sede),
    CONSTRAINT uq_sede_nombre UNIQUE (nombre_sede)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla interes
   Catálogo de intereses y pasatiempos (deportes, videojuegos, música, programación…).
   ---------------------------------------------------------------------------- */
CREATE TABLE interes (
    id_interes       INT AUTO_INCREMENT NOT NULL,
    nombre_interes   VARCHAR(60) NOT NULL,
    tipo             VARCHAR(20) NOT NULL,
    descripcion      VARCHAR(255) NULL,
    CONSTRAINT pk_interes PRIMARY KEY (id_interes),
    CONSTRAINT uq_interes_nombre UNIQUE (nombre_interes),
    CONSTRAINT ck_interes_tipo CHECK (tipo IN ('ACADEMICO', 'DEPORTIVO', 'CULTURAL', 'TECNOLOGICO', 'OCIO'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla habilidad
   Catálogo de habilidades (SQL, Python, diseño, fútbol…) que el caso pide para los perfiles.
   ---------------------------------------------------------------------------- */
CREATE TABLE habilidad (
    id_habilidad       INT AUTO_INCREMENT NOT NULL,
    nombre_habilidad   VARCHAR(60) NOT NULL,
    descripcion        VARCHAR(255) NULL,
    CONSTRAINT pk_habilidad PRIMARY KEY (id_habilidad),
    CONSTRAINT uq_habilidad_nombre UNIQUE (nombre_habilidad)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla materia
   Asignaturas del plan de estudios. Se separó de curso al normalizar (3FN).
   ---------------------------------------------------------------------------- */
CREATE TABLE materia (
    id_materia       INT AUTO_INCREMENT NOT NULL,
    codigo_materia   VARCHAR(15) NOT NULL,
    nombre_materia   VARCHAR(100) NOT NULL,
    creditos         INT NOT NULL,
    CONSTRAINT pk_materia PRIMARY KEY (id_materia),
    CONSTRAINT uq_materia_codigo UNIQUE (codigo_materia),
    CONSTRAINT ck_materia_creditos CHECK (creditos BETWEEN 1 AND 10)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla profesor
   Docentes que dictan los cursos.
   ---------------------------------------------------------------------------- */
CREATE TABLE profesor (
    id_profesor   INT AUTO_INCREMENT NOT NULL,
    nombre        VARCHAR(50) NOT NULL,
    apellido      VARCHAR(50) NOT NULL,
    email         VARCHAR(100) NOT NULL,
    CONSTRAINT pk_profesor PRIMARY KEY (id_profesor),
    CONSTRAINT uq_profesor_email UNIQUE (email)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla recurso_academico
   Libros, guías, videos o enlaces que se comparten con la comunidad.
   ---------------------------------------------------------------------------- */
CREATE TABLE recurso_academico (
    id_recurso     INT AUTO_INCREMENT NOT NULL,
    titulo         VARCHAR(150) NOT NULL,
    url            VARCHAR(255) NOT NULL,
    tipo_archivo   VARCHAR(10) NOT NULL,
    CONSTRAINT pk_recurso_academico PRIMARY KEY (id_recurso),
    CONSTRAINT uq_recurso_academico_url UNIQUE (url),
    CONSTRAINT ck_recurso_academico_tipo CHECK (tipo_archivo IN ('PDF', 'DOC', 'VIDEO', 'ENLACE', 'IMAGEN'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla programa
   Programas académicos (carreras) que ofrece la universidad.
   ---------------------------------------------------------------------------- */
CREATE TABLE programa (
    id_programa       INT AUTO_INCREMENT NOT NULL,
    id_facultad       INT NOT NULL,
    nombre_programa   VARCHAR(100) NOT NULL,
    CONSTRAINT pk_programa PRIMARY KEY (id_programa),
    CONSTRAINT uq_programa_nombre UNIQUE (nombre_programa),
    CONSTRAINT fk_programa_facultad FOREIGN KEY (id_facultad)
        REFERENCES facultad (id_facultad)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla espacio
   Aulas, laboratorios y auditorios donde hay clases o eventos.
   ---------------------------------------------------------------------------- */
CREATE TABLE espacio (
    id_espacio       INT AUTO_INCREMENT NOT NULL,
    id_sede          INT NOT NULL,
    nombre_espacio   VARCHAR(60) NOT NULL,
    bloque           VARCHAR(10) NOT NULL,
    capacidad        INT NOT NULL,
    datos_iot        JSON NULL,  -- Última lectura de los sensores IoT del espacio: ocupación, temperatura, CO2 (JSON).
    CONSTRAINT pk_espacio PRIMARY KEY (id_espacio),
    CONSTRAINT uq_espacio_sede_nombre_bloque UNIQUE (id_sede, nombre_espacio, bloque),
    CONSTRAINT ck_espacio_capacidad CHECK (capacidad > 0),
    CONSTRAINT ck_espacio_datos_iot_json CHECK (JSON_TYPE(datos_iot) = 'OBJECT'),
    CONSTRAINT fk_espacio_sede FOREIGN KEY (id_sede)
        REFERENCES sede (id_sede)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla curso
   Grupo concreto de una materia en un periodo académico, con su profesor y su aula.
   ---------------------------------------------------------------------------- */
CREATE TABLE curso (
    id_curso       INT AUTO_INCREMENT NOT NULL,
    id_materia     INT NOT NULL,
    id_profesor    INT NOT NULL,
    id_espacio     INT NOT NULL,
    periodo        VARCHAR(6) NOT NULL,
    codigo_grupo   VARCHAR(10) NOT NULL,
    CONSTRAINT pk_curso PRIMARY KEY (id_curso),
    CONSTRAINT uq_curso_materia_periodo_grupo UNIQUE (id_materia, periodo, codigo_grupo),
    CONSTRAINT ck_curso_periodo CHECK (periodo REGEXP '^[0-9]{4}-[12]$'),
    CONSTRAINT fk_curso_espacio FOREIGN KEY (id_espacio)
        REFERENCES espacio (id_espacio)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_curso_materia FOREIGN KEY (id_materia)
        REFERENCES materia (id_materia)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_curso_profesor FOREIGN KEY (id_profesor)
        REFERENCES profesor (id_profesor)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla estudiante
   Cuenta de cada estudiante de la red social. Es la tabla principal: casi todas las demás se conectan con ella. Los datos visibles del perfil se guardan aparte, en la tabla perfil.
   ---------------------------------------------------------------------------- */
CREATE TABLE estudiante (
    id_estudiante       INT AUTO_INCREMENT NOT NULL,
    id_programa         INT NOT NULL,
    codigo_estudiante   VARCHAR(15) NOT NULL,
    nombre              VARCHAR(50) NOT NULL,
    apellido            VARCHAR(50) NOT NULL,
    email               VARCHAR(100) NOT NULL,
    contrasena_hash     VARCHAR(255) NOT NULL,
    semestre            INT NOT NULL,
    fecha_registro      DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    ultima_actividad    DATETIME NULL,
    estado              VARCHAR(10) DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT pk_estudiante PRIMARY KEY (id_estudiante),
    CONSTRAINT uq_estudiante_codigo UNIQUE (codigo_estudiante),
    CONSTRAINT uq_estudiante_email UNIQUE (email),
    CONSTRAINT ck_estudiante_estado CHECK (estado IN ('ACTIVO', 'INACTIVO', 'SUSPENDIDO')),
    CONSTRAINT ck_estudiante_semestre CHECK (semestre BETWEEN 1 AND 12),
    CONSTRAINT fk_estudiante_programa FOREIGN KEY (id_programa)
        REFERENCES programa (id_programa)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla perfil
   Datos que el estudiante muestra a los demás (biografía, foto, ciudad). Cada estudiante tiene un único perfil (relación 1:1).
   ---------------------------------------------------------------------------- */
CREATE TABLE perfil (
    id_perfil             INT AUTO_INCREMENT NOT NULL,
    id_estudiante         INT NOT NULL,
    biografia             VARCHAR(500) NULL,
    foto_perfil           VARCHAR(255) NULL,
    ciudad                VARCHAR(60) NULL,
    fecha_actualizacion   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_perfil PRIMARY KEY (id_perfil),
    CONSTRAINT uq_perfil_estudiante UNIQUE (id_estudiante),
    CONSTRAINT fk_perfil_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla estudiante_interes
   Tabla intermedia N:M entre estudiante e interes.
   ---------------------------------------------------------------------------- */
CREATE TABLE estudiante_interes (
    id_estudiante    INT NOT NULL,
    id_interes       INT NOT NULL,
    fecha_agregado   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_estudiante_interes PRIMARY KEY (id_estudiante, id_interes),
    CONSTRAINT fk_estudiante_interes_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_estudiante_interes_interes FOREIGN KEY (id_interes)
        REFERENCES interes (id_interes)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla estudiante_habilidad
   Tabla intermedia N:M entre estudiante y habilidad; guarda el nivel de dominio.
   ---------------------------------------------------------------------------- */
CREATE TABLE estudiante_habilidad (
    id_estudiante    INT NOT NULL,
    id_habilidad     INT NOT NULL,
    nivel            VARCHAR(12) NOT NULL,
    fecha_agregado   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_estudiante_habilidad PRIMARY KEY (id_estudiante, id_habilidad),
    CONSTRAINT ck_estudiante_habilidad_nivel CHECK (nivel IN ('BASICO', 'INTERMEDIO', 'AVANZADO')),
    CONSTRAINT fk_estudiante_habilidad_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_estudiante_habilidad_habilidad FOREIGN KEY (id_habilidad)
        REFERENCES habilidad (id_habilidad)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla seguimiento
   Relación reflexiva N:M: un estudiante sigue a otro. Las dos columnas apuntan a estudiante.
   ---------------------------------------------------------------------------- */
CREATE TABLE seguimiento (
    id_seguidor         INT NOT NULL,
    id_seguido          INT NOT NULL,
    fecha_seguimiento   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_seguimiento PRIMARY KEY (id_seguidor, id_seguido),
    CONSTRAINT fk_seguimiento_estudiante_seguido FOREIGN KEY (id_seguido)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_seguimiento_estudiante_seguidor FOREIGN KEY (id_seguidor)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla mentoria
   Relación reflexiva N:M: un estudiante mentor acompaña a un estudiante aprendiz, opcionalmente sobre una materia.
   ---------------------------------------------------------------------------- */
CREATE TABLE mentoria (
    id_mentor      INT NOT NULL,
    id_aprendiz    INT NOT NULL,
    id_materia     INT NULL,
    fecha_inicio   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    estado         VARCHAR(12) DEFAULT 'SOLICITADA' NOT NULL,
    CONSTRAINT pk_mentoria PRIMARY KEY (id_mentor, id_aprendiz),
    CONSTRAINT ck_mentoria_estado CHECK (estado IN ('SOLICITADA', 'ACTIVA', 'FINALIZADA')),
    CONSTRAINT fk_mentoria_estudiante_aprendiz FOREIGN KEY (id_aprendiz)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mentoria_estudiante_mentor FOREIGN KEY (id_mentor)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_mentoria_materia FOREIGN KEY (id_materia)
        REFERENCES materia (id_materia)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla publicacion
   Publicaciones del muro: preguntas, recursos, noticias, avisos o memes.
   ---------------------------------------------------------------------------- */
CREATE TABLE publicacion (
    id_publicacion     INT AUTO_INCREMENT NOT NULL,
    id_autor           INT NOT NULL,
    contenido          TEXT NOT NULL,
    tipo_publicacion   VARCHAR(20) NOT NULL,
    fecha_creacion     DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    metadatos          JSON NULL,  -- Etiquetas, adjuntos y geoubicación de la publicación (JSON).
    CONSTRAINT pk_publicacion PRIMARY KEY (id_publicacion),
    CONSTRAINT ck_publicacion_tipo CHECK (tipo_publicacion IN ('PREGUNTA', 'RECURSO', 'NOTICIA', 'AVISO', 'MEME')),
    CONSTRAINT ck_publicacion_metadatos_json CHECK (JSON_TYPE(metadatos) = 'OBJECT'),
    CONSTRAINT fk_publicacion_estudiante_autor FOREIGN KEY (id_autor)
        REFERENCES estudiante (id_estudiante)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla comentario
   Respuestas que escriben los estudiantes en una publicación.
   ---------------------------------------------------------------------------- */
CREATE TABLE comentario (
    id_comentario      INT AUTO_INCREMENT NOT NULL,
    id_publicacion     INT NOT NULL,
    id_autor           INT NOT NULL,
    contenido          VARCHAR(1000) NOT NULL,
    fecha_comentario   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_comentario PRIMARY KEY (id_comentario),
    CONSTRAINT fk_comentario_estudiante_autor FOREIGN KEY (id_autor)
        REFERENCES estudiante (id_estudiante)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_comentario_publicacion FOREIGN KEY (id_publicacion)
        REFERENCES publicacion (id_publicacion)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla reaccion
   Reacciones de un clic (me gusta, útil…) de un estudiante sobre una publicación.
   ---------------------------------------------------------------------------- */
CREATE TABLE reaccion (
    id_estudiante    INT NOT NULL,
    id_publicacion   INT NOT NULL,
    tipo_reaccion    VARCHAR(15) NOT NULL,
    fecha_reaccion   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_reaccion PRIMARY KEY (id_estudiante, id_publicacion),
    CONSTRAINT ck_reaccion_tipo CHECK (tipo_reaccion IN ('ME_GUSTA', 'ME_ENCANTA', 'ME_DIVIERTE', 'UTIL')),
    CONSTRAINT fk_reaccion_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_reaccion_publicacion FOREIGN KEY (id_publicacion)
        REFERENCES publicacion (id_publicacion)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla grupo_estudio
   Grupos de estudio, equipos de hackatón, clubes o semilleros creados por estudiantes.
   ---------------------------------------------------------------------------- */
CREATE TABLE grupo_estudio (
    id_grupo         INT AUTO_INCREMENT NOT NULL,
    id_creador       INT NOT NULL,
    id_materia       INT NULL,
    nombre_grupo     VARCHAR(80) NOT NULL,
    descripcion      VARCHAR(500) NULL,
    tipo             VARCHAR(20) NOT NULL,
    es_privado       BOOLEAN DEFAULT FALSE NOT NULL,
    estado           VARCHAR(10) DEFAULT 'ACTIVO' NOT NULL,
    fecha_creacion   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_grupo_estudio PRIMARY KEY (id_grupo),
    CONSTRAINT ck_grupo_estudio_estado CHECK (estado IN ('ACTIVO', 'ARCHIVADO')),
    CONSTRAINT ck_grupo_estudio_tipo CHECK (tipo IN ('ESTUDIO', 'HACKATON', 'CLUB', 'SEMILLERO')),
    CONSTRAINT fk_grupo_estudio_estudiante_creador FOREIGN KEY (id_creador)
        REFERENCES estudiante (id_estudiante)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_grupo_estudio_materia FOREIGN KEY (id_materia)
        REFERENCES materia (id_materia)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla miembro_grupo
   Tabla intermedia N:M: qué estudiantes pertenecen a cada grupo y con qué rol.
   ---------------------------------------------------------------------------- */
CREATE TABLE miembro_grupo (
    id_grupo        INT NOT NULL,
    id_estudiante   INT NOT NULL,
    rol             VARCHAR(15) DEFAULT 'MIEMBRO' NOT NULL,
    fecha_ingreso   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_miembro_grupo PRIMARY KEY (id_grupo, id_estudiante),
    CONSTRAINT ck_miembro_grupo_rol CHECK (rol IN ('ADMIN', 'MODERADOR', 'MIEMBRO')),
    CONSTRAINT fk_miembro_grupo_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_miembro_grupo_grupo_estudio FOREIGN KEY (id_grupo)
        REFERENCES grupo_estudio (id_grupo)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla evento
   Reuniones de estudio, talleres, torneos o actividades del campus.
   ---------------------------------------------------------------------------- */
CREATE TABLE evento (
    id_evento        INT AUTO_INCREMENT NOT NULL,
    id_organizador   INT NOT NULL,
    id_grupo         INT NULL,
    id_espacio       INT NULL,
    titulo           VARCHAR(100) NOT NULL,
    descripcion      VARCHAR(1000) NULL,
    fecha_inicio     DATETIME NOT NULL,
    fecha_cierre     DATETIME NOT NULL,
    modalidad        VARCHAR(10) NOT NULL,
    CONSTRAINT pk_evento PRIMARY KEY (id_evento),
    CONSTRAINT ck_evento_espacio CHECK (modalidad = 'VIRTUAL' OR id_espacio IS NOT NULL),
    CONSTRAINT ck_evento_fechas CHECK (fecha_cierre >= fecha_inicio),
    CONSTRAINT ck_evento_modalidad CHECK (modalidad IN ('PRESENCIAL', 'VIRTUAL', 'HIBRIDA')),
    CONSTRAINT fk_evento_espacio FOREIGN KEY (id_espacio)
        REFERENCES espacio (id_espacio)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_evento_estudiante_organizador FOREIGN KEY (id_organizador)
        REFERENCES estudiante (id_estudiante)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_evento_grupo_estudio FOREIGN KEY (id_grupo)
        REFERENCES grupo_estudio (id_grupo)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla participacion_evento
   Tabla intermedia N:M: inscripción y asistencia de los estudiantes a los eventos.
   ---------------------------------------------------------------------------- */
CREATE TABLE participacion_evento (
    id_estudiante       INT NOT NULL,
    id_evento           INT NOT NULL,
    estado              VARCHAR(12) DEFAULT 'INSCRITO' NOT NULL,
    fecha_inscripcion   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_participacion_evento PRIMARY KEY (id_estudiante, id_evento),
    CONSTRAINT ck_participacion_evento_estado CHECK (estado IN ('INSCRITO', 'ASISTIO', 'CANCELADO')),
    CONSTRAINT fk_participacion_evento_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_participacion_evento_evento FOREIGN KEY (id_evento)
        REFERENCES evento (id_evento)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla acceso_recurso
   Tabla intermedia N:M: qué recursos consulta cada estudiante.
   ---------------------------------------------------------------------------- */
CREATE TABLE acceso_recurso (
    id_estudiante         INT NOT NULL,
    id_recurso            INT NOT NULL,
    fecha_ultimo_acceso   DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_acceso_recurso PRIMARY KEY (id_estudiante, id_recurso),
    CONSTRAINT fk_acceso_recurso_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_acceso_recurso_recurso_academico FOREIGN KEY (id_recurso)
        REFERENCES recurso_academico (id_recurso)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Tabla matricula
   Tabla intermedia N:M: en qué cursos está matriculado cada estudiante.
   ---------------------------------------------------------------------------- */
CREATE TABLE matricula (
    id_estudiante     INT NOT NULL,
    id_curso          INT NOT NULL,
    fecha_matricula   DATE DEFAULT (CURRENT_DATE) NOT NULL,
    CONSTRAINT pk_matricula PRIMARY KEY (id_estudiante, id_curso),
    CONSTRAINT fk_matricula_curso FOREIGN KEY (id_curso)
        REFERENCES curso (id_curso)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_matricula_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante (id_estudiante)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

/* ----------------------------------------------------------------------------
   Triggers que sustituyen los CHECK no permitidos por MySQL (error 3823)
   ---------------------------------------------------------------------------- */
DELIMITER $$
CREATE TRIGGER trg_seguimiento_ins BEFORE INSERT ON seguimiento FOR EACH ROW
BEGIN
    IF NEW.id_seguidor = NEW.id_seguido THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un estudiante no puede seguirse a sí mismo';
    END IF;
END$$
CREATE TRIGGER trg_seguimiento_upd BEFORE UPDATE ON seguimiento FOR EACH ROW
BEGIN
    IF NEW.id_seguidor = NEW.id_seguido THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un estudiante no puede seguirse a sí mismo';
    END IF;
END$$
CREATE TRIGGER trg_mentoria_ins BEFORE INSERT ON mentoria FOR EACH ROW
BEGIN
    IF NEW.id_mentor = NEW.id_aprendiz THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un estudiante no puede ser su propio mentor';
    END IF;
END$$
CREATE TRIGGER trg_mentoria_upd BEFORE UPDATE ON mentoria FOR EACH ROW
BEGIN
    IF NEW.id_mentor = NEW.id_aprendiz THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un estudiante no puede ser su propio mentor';
    END IF;
END$$
DELIMITER ;

/* ----------------------------------------------------------------------------
   Índices sobre claves foráneas (aceleran JOIN y comprobaciones de borrado)
   ---------------------------------------------------------------------------- */
CREATE INDEX idx_programa_facultad ON programa (id_facultad);
CREATE INDEX idx_estudiante_programa ON estudiante (id_programa);
CREATE INDEX idx_estudiante_interes_interes ON estudiante_interes (id_interes);
CREATE INDEX idx_estudiante_habilidad_habil ON estudiante_habilidad (id_habilidad);
CREATE INDEX idx_seguimiento_seguido ON seguimiento (id_seguido);
CREATE INDEX idx_mentoria_aprendiz ON mentoria (id_aprendiz);
CREATE INDEX idx_mentoria_materia ON mentoria (id_materia);
CREATE INDEX idx_publicacion_autor ON publicacion (id_autor);
CREATE INDEX idx_comentario_publicacion ON comentario (id_publicacion);
CREATE INDEX idx_comentario_autor ON comentario (id_autor);
CREATE INDEX idx_reaccion_publicacion ON reaccion (id_publicacion);
CREATE INDEX idx_grupo_estudio_creador ON grupo_estudio (id_creador);
CREATE INDEX idx_grupo_estudio_materia ON grupo_estudio (id_materia);
CREATE INDEX idx_miembro_grupo_estudiante ON miembro_grupo (id_estudiante);
CREATE INDEX idx_evento_organizador ON evento (id_organizador);
CREATE INDEX idx_evento_grupo ON evento (id_grupo);
CREATE INDEX idx_evento_espacio ON evento (id_espacio);
CREATE INDEX idx_participacion_evento_evento ON participacion_evento (id_evento);
CREATE INDEX idx_acceso_recurso_recurso ON acceso_recurso (id_recurso);
CREATE INDEX idx_curso_profesor ON curso (id_profesor);
CREATE INDEX idx_curso_espacio ON curso (id_espacio);
CREATE INDEX idx_matricula_curso ON matricula (id_curso);

