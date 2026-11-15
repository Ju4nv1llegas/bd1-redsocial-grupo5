# Diccionario de alias — Reglas de nomenclatura para datos calculados

Reglas aplicadas en `scripts/final/04_consultas_y_vistas.sql`.

| Regla | Descripción |
|---|---|
| R1 | Todo alias se escribe con AS y sin comillas dobles. |
| R2 | Minúsculas, snake_case, sin tildes, ñ ni espacios (igual que el DDL). |
| R3 | El prefijo indica el cálculo: total_ (conteos y sumas), promedio_, pct_ (porcentaje de 0 a 100), dias_, lista_ (texto concatenado), puntaje_ (índice compuesto), posicion_ (función de ventana), categoria_ (CASE), nombre_ (concatenación de nombres), medida_ (lecturas de sensores JSON). |
| R4 | Un alias nunca repite el nombre de una columna de las tablas consultadas. |
| R5 | Un alias no supera 30 caracteres y dice qué se calcula, no cómo. |
| R6 | Alias de tabla: abreviatura de 1 a 3 letras (e = estudiante, pu = publicacion). |
| R7 | Textos derivados o renombrados: sustantivo + rol (programa_autor, lugar_evento). Parámetros de CTE: nombre del parámetro (fecha_corte, id_referencia). |
| R8 | En una subconsulta de apoyo el conteo se llama total; la consulta externa lo renombra según R3. |

## Alias calculados (64)

| Alias | Regla | Significado | Dónde se usa |
|---|---|---|---|
| `categoria_interaccion` | R3 categoria_ | ALTA (8 o más interacciones), MEDIA (3 a 7) o BAJA (menos de 3). | V2 |
| `categoria_participacion` | R3 categoria_ | DESTACADO (60 o más), ACTIVO (40 a 59) o EN CRECIMIENTO. | C8 |
| `estado_ambiente` | R3 categoria_ (CASE) | CON ALERTA si el sensor reporta alertas; NORMAL en caso contrario. | C10 |
| `estado_evento` | R3 categoria_ (CASE) | FINALIZADO si ya cerró o PROGRAMADO si aún no. | V3 |
| `lista_habilidades` | R3 lista_ | Habilidades con su nivel entre paréntesis, separadas por coma. | V1 |
| `lista_habilidades_avanzadas` | R3 lista_ | Habilidades en nivel AVANZADO del estudiante, separadas por coma. | C2 |
| `lista_intereses` | R3 lista_ | Intereses del estudiante separados por coma, en orden alfabético. | V1 |
| `lista_intereses_comunes` | R3 lista_ | Nombres de los intereses compartidos. | C3 |
| `medida_co2_ppm` | R3 medida_ | Concentración de CO2 en partes por millón leída por el sensor (co2_ppm). | C10 |
| `nombre_autor` | R3 nombre_ | Nombre completo del autor de la publicación. | V2, C4 |
| `nombre_completo` | R3 nombre_ | Nombre y apellido unidos con un espacio. | V1, V4, V6, C2, C3, C8 |
| `nombre_organizador` | R3 nombre_ | Nombre completo de quien organiza el evento. | V3 |
| `nombre_profesor` | R3 nombre_ | Nombre completo del profesor que dicta el curso. | V6 |
| `pct_aforo` | R3 pct_ | Porcentaje del aforo ocupado según el sensor IoT (ocupacion.aforo_pct). | C10 |
| `pct_asistencia` | R3 pct_ | Porcentaje de asistentes sobre inscritos vigentes (solo eventos finalizados). | V3, C5 |
| `pct_comunidad_activa` | R3 pct_ | Porcentaje de la comunidad activa que comparte el interés. | C1 |
| `pct_ocupacion_espacio` | R3 pct_ | Asistentes sobre la capacidad del espacio (NULL si es virtual). | C5 |
| `posicion_ranking` | R3 posicion_ | Lugar en el ranking (RANK: los empates comparten posición). | C8 |
| `promedio_dias_sin_actividad` | R3 promedio_ | Promedio de días desde la última actividad hasta la fecha de corte. | C7 |
| `promedio_interacciones` | R3 promedio_ | Promedio de interacciones por publicación. | V2, U2 |
| `promedio_miembros_grupo` | R3 promedio_ | Promedio de miembros entre los grupos activos. | C6 |
| `promedio_puntaje` | R3 promedio_ | Puntaje de participación promedio por estudiante. | V5 |
| `promedio_semestre` | R3 promedio_ | Semestre promedio de los estudiantes del programa. | V5 |
| `puntaje_participacion` | R3 puntaje_ | 3 × publicaciones + 2 × comentarios + 1 × reacciones + 5 × eventos asistidos. | V4, C8 |
| `total_asistentes` | R3 total_ | Inscritos con estado ASISTIO. | V3, C5 |
| `total_cancelados` | R3 total_ | Inscripciones con estado CANCELADO. | V3 |
| `total_categoria_alta` | R3 total_ | Publicaciones con categoría de interacción ALTA. | U2 |
| `total_comentarios` | R3 total_ | Comentarios recibidos (o escritos, según la consulta). | V2, V4, C4, C8 |
| `total_estudiantes` | R3 total_ | Estudiantes de un programa, sin importar su estado. | V5 |
| `total_estudiantes_activos` | R3 total_ | Estudiantes con estado ACTIVO. | V5, C7 |
| `total_estudiantes_inactivos` | R3 total_ | Estudiantes con estado INACTIVO (verificación final). | verificacion final |
| `total_estudiantes_interesados` | R3 total_ | Estudiantes activos que tienen el interés. | C1 |
| `total_eventos_asistidos` | R3 total_ | Eventos con estado ASISTIO. | V4, V5, C8 |
| `total_filas_borradas` | R3 total_ | Filas eliminadas por el DELETE, agrupadas por evento. | E3 |
| `total_grupos` | R3 total_ | Grupos de estudio a los que pertenece. | V4 |
| `total_habilidades` | R3 total_ | Cantidad de habilidades de un estudiante. | V1 |
| `total_habilidades_avanzadas` | R3 total_ | Cantidad de habilidades en nivel AVANZADO. | V1, C2 |
| `total_inactivos_30_dias` | R3 total_ | Estudiantes activos con más de 30 días sin actividad. | C7 |
| `total_inscritos_vigentes` | R3 total_ | Inscritos que no cancelaron (INSCRITO o ASISTIO). | V3, C5 |
| `total_interacciones` | R3 total_ | Reacciones más comentarios de una publicación. | V2, C4 |
| `total_intereses` | R3 total_ | Cantidad de intereses de un estudiante. | V1 |
| `total_intereses_comunes` | R3 total_ | Intereses que comparte con el estudiante de referencia. | C3 |
| `total_mentorias_activas` | R3 total_ | Mentorías en estado ACTIVA que lleva un mentor. | C2 |
| `total_miembros` | R3 total_ | Miembros de un grupo de estudio. | C6 |
| `total_participaciones` | R3 total_ | Filas de participacion_evento (verificación final). | verificacion final |
| `total_personas_actuales` | R3 total_ | Personas que reporta el sensor IoT del espacio (campo ocupacion.personas del JSON). | C10 |
| `total_publicaciones` | R3 total_ | Cantidad de publicaciones. | V2, V4, V5, C8, C9, U2 |
| `total_reacciones` | R3 total_ | Reacciones recibidas por una publicación. | V2, C4, C9 |
| `total_reacciones_dadas` | R3 total_ | Reacciones que un estudiante dio a otras publicaciones. | V4, C8 |
| `total_reacciones_utiles` | R3 total_ | Reacciones de tipo UTIL recibidas por una publicación. | V2 |
| `total_seguidores` | R3 total_ | Estudiantes que siguen a este estudiante. | V4 |
| `total_siguiendo` | R3 total_ | Estudiantes a quienes este estudiante sigue. | V4 |
| `total_sin_actividad_registrada` | R3 total_ | Estudiantes activos cuya última actividad es NULL. | C7 |
| `capacidad_espacio` | R7 descriptivo | Capacidad máxima del espacio donde se realiza el evento. | V3 |
| `grupo_organizador` | R7 descriptivo | Grupo que organiza el evento, o «Sin grupo». | V3 |
| `id_autor_publicacion` | R7 descriptivo | Identificador del estudiante que escribió la publicación. | V2 |
| `lugar_evento` | R7 descriptivo | Sede y espacio del evento, o «Virtual». | V3 |
| `materia_asociada` | R7 descriptivo | Materia del grupo, o «Sin materia asociada». | C6 |
| `programa_autor` | R7 descriptivo | Programa académico del autor de la publicación. | V2 |
| `resumen_contenido` | R7 descriptivo | Primeros 40 caracteres de la publicación seguidos de puntos suspensivos. | C4 |
| `fecha_corte` | R7 parámetro | Fecha de referencia para medir inactividad (2026-11-14). | C7 |
| `id_referencia` | R7 parámetro | Estudiante para el que se calculan las recomendaciones. | C3 |
| `total` | R8 (apoyo) | Conteo interno de una subconsulta; la consulta externa lo renombra. | V4, C2, C4, C9 |
| `total_avanzadas` | R8 (apoyo) | Conteo interno de habilidades avanzadas, antes de renombrarse en la consulta externa. | V1 |

Alias de tabla usados: a, b, c, co, e, eh, ei, ei1, ei2, es, ev, f, g, h, i, m, mg, mpg, o, p, pe, pf, pu, r, re, ref, s, se, sg, sr, vpf, vpt, x, y.
