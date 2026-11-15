# Tarea 5 (S1) · Sistema de consultas DML y vistas — Red social estudiantil pascualina

Bases de Datos I · G100 (SD1006) · Grupo 5 · Institución Universitaria Pascual Bravo
Experto temático: Juan Camilo Villegas Ocampo (trabajo individual) · Docente: Oralia Cortes Grajales

Consultas DML y vistas sobre el modelo físico de la red social (Tarea 4: esquema `red_social`, PostgreSQL 16, 25 tablas, 34 claves foráneas y 2 columnas JSONB). Continúa el trabajo de las tareas 2, 3 y 4 y del foro «Trabajando en la red social estudiantil».

## Estructura

```
tarea5/
├── README.md
├── diccionarios/
│   ├── diccionario_de_datos.md            25 tablas, 118 columnas
│   └── diccionario_de_alias.md            reglas de ALIAS y alias calculados
├── scripts/
│   ├── borrador/
│   │   ├── consultas_foro.sql             borrador: las 4 consultas del foro
│   │   └── identificacion_tablas_campos_alias.md   tablas, campos, tipos de datos y alias del borrador
│   └── final/
│       ├── 01_ddl_postgresql.sql          modelo físico de la Tarea 4
│       ├── 02_datos_ejemplo_foro.sql      datos de ejemplo del foro (8 estudiantes)
│       ├── 03_datos_ampliados.sql         datos ficticios que se suman a los del foro (40 estudiantes)
│       └── 04_consultas_y_vistas.sql      6 vistas, 11 consultas, 2 usos de vistas, 3 escrituras
├── informe/
│   └── Informe_Tarea5_Consultas_DML_y_Vistas.pdf
└── video/
    └── enlace_video.txt                   enlace de YouTube
```

## Cómo reproducir

1. Crear una base de datos vacía en PostgreSQL 16, por ejemplo `red_social_pascualina`.
2. Ejecutar, en este orden, los cuatro scripts de `scripts/final/`:
   - **pgAdmin 4:** abrir cada archivo en el Query Tool y ejecutarlo (F5). Una consulta suelta se ejecuta seleccionándola y pulsando F5.
   - **psql:** `psql -U postgres -d red_social_pascualina -f 01_ddl_postgresql.sql`, y lo mismo con los otros tres archivos, desde `scripts/final`.
3. Si la base ya tiene los datos del foro, basta ejecutar `03_datos_ampliados.sql` y `04_consultas_y_vistas.sql`.
4. Los resultados de `04_consultas_y_vistas.sql` coinciden con las imágenes del informe (los datos son deterministas y las consultas con fechas usan la fecha de corte `2026-11-14`).

En `04_consultas_y_vistas.sql` cada línea de SQL termina con un comentario que explica qué hace, además del bloque de comentarios de cada consulta y vista.

En pgAdmin conviene pulsar **Ctrl + A** y luego **F5** para ejecutar cada archivo completo. `04_consultas_y_vistas.sql` incluye varios `COMMIT;` a propósito (pgAdmin envía el script como un solo lote y, sin ellos, el `ROLLBACK` de las pruebas de escritura deshace las vistas); en Messages aparecen avisos «no hay una transacción en curso», que son normales.

`01_ddl_postgresql.sql` empieza con `DROP SCHEMA IF EXISTS red_social CASCADE` y `02_datos_ejemplo_foro.sql` vacía las tablas: reinician el esquema completo, vistas incluidas. `03_datos_ampliados.sql` solo suma filas y se niega a ejecutarse dos veces.

## Contenido de `04_consultas_y_vistas.sql`

| Parte | Piezas |
|---|---|
| A. Vistas | V1 `v_perfil_estudiante` · V2 `v_actividad_publicacion` · V3 `v_evento_asistencia` · V4 `v_participacion_estudiante` · V5 `v_resumen_programa` (sobre V4) · V6 `v_matricula_curso` (consulta 1 del foro) |
| B. Consultas | C1 intereses populares · C2 mentores disponibles · C3 compañeros recomendados · C4 publicaciones con más interacción · C5 asistencia a eventos · C6 grupos sobre el promedio · C7 inactividad por programa · C8 ranking de participación · C9 etiquetas (JSONB) · C10 aulas con sensor IoT (JSONB) · C11 EXCEPT (consulta 2 del foro) |
| C. Uso de vistas | U1 (une dos vistas) · U2 (interacción por tipo de publicación) |
| D. Escritura | E1 `INSERT ... SELECT ... ON CONFLICT` · E2 `UPDATE ... RETURNING` · E3 `DELETE` en una CTE (todas con `ROLLBACK`) |

## Datos

Los datos de `03_datos_ampliados.sql` son ficticios (nombres, correos, publicaciones y fechas inventados). Los de `02_datos_ejemplo_foro.sql` son los del foro.
