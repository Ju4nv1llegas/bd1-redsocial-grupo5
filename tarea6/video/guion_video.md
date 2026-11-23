# Guion del video (5–10 min) — presentación individual

| Min | Tema | Qué mostrar |
|---|---|---|
| 0:00–1:00 | Contexto: de la Tarea 5 al problema Big Data/IoT | Informe, secciones 1–3 |
| 1:00–3:00 | **1. Modelo híbrido**: diagrama, qué va en columnas y qué en JSONB, partición, índices, trigger | Diagrama del informe (sec. 5) y `01_ddl_hibrido.sql` (lectura_iot) |
| 3:00–6:00 | **2. Consultas con JSON**: C1, C3 (aforo vs CO2), C5 (RFID por programa, @>), C7 (búsquedas), D1 (jsonb_set) | pgAdmin ejecutando `03_consultas_dml.sql` |
| 6:00–7:30 | EXPLAIN: poda de particiones y GIN con @> frente a ->> | Bloque E del script |
| 7:30–8:30 | **3. Dificultades, ventajas y desventajas** | Informe sec. 8 |
| 8:30–10:00 | **4. Conclusión individual** y mejoras | Informe sec. 9 |

Conclusión individual de Juan Camilo (para leer con tus palabras): la decisión no es «JSON sí o no», sino qué dato merece una columna; el GIN solo ayuda con @>; una tabla pequeña no necesita índice; validar los datos generados antes de analizarlos.
