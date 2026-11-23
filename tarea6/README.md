# Tarea 6 — Arquitectura híbrida (relacional + JSONB + IoT)

Bases de Datos I · G100 (SD1006) · Grupo 5 · Red social estudiantil pascualina · PostgreSQL 16

Extiende el esquema relacional de la Tarea 5 (25 tablas) con datos semiestructurados (JSONB) y un flujo IoT de gran volumen.

## Estructura
| Ruta | Contenido |
|---|---|
| `scripts/00_ejecutar_todo.sql` | Carga completa desde psql (base + híbrido) |
| `scripts/base_tarea5/` | DDL y datos de la Tarea 5 (prerrequisito) |
| `scripts/01_ddl_hibrido.sql` | DDL: 6 objetos nuevos, partición mensual, índices GIN/BRIN, trigger, vista materializada |
| `scripts/02_datos_hibridos.sql` | Datos sintéticos reproducibles (~98 000 lecturas IoT, 20 000 logs) |
| `scripts/03_consultas_dml.sql` | 14 consultas con JSONB, 5 sentencias DML y 3 planes EXPLAIN |
| `diccionarios/diccionario_de_datos.md` | Tablas y campos nuevos, estructurados y semiestructurados |
| `informe/informe_tarea6.pdf` | Informe técnico (incluye evidencia de ejecución) |
| `informe/capturas/` | 14 capturas de pgAdmin con la ejecución real de los scripts |
| `video/enlace_video.txt` | Enlace a YouTube (5–10 min) |

## Cómo ejecutarlo
```powershell
psql -U postgres -c "CREATE DATABASE red_social_hibrida"
cd scripts
psql -U postgres -d red_social_hibrida -f 00_ejecutar_todo.sql   # ~10 s
psql -U postgres -d red_social_hibrida -f 03_consultas_dml.sql   # consultas
```
Los scripts son re-ejecutables. Todos los datos son ficticios.
