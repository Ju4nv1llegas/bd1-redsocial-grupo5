/* Ejecuta toda la Tarea 6 desde psql, parado en la carpeta tarea6/scripts:
     psql -U postgres -d red_social_hibrida -f 00_ejecutar_todo.sql
   (crear antes la base:  CREATE DATABASE red_social_hibrida;)               */
\set ON_ERROR_STOP on
\encoding UTF8
\i base_tarea5/01_ddl_postgresql.sql
\i base_tarea5/02_datos_ejemplo_foro.sql
\i base_tarea5/03_datos_ampliados.sql
\i 01_ddl_hibrido.sql
\i 02_datos_hibridos.sql
