# Talleres de MySQL — edición reorganizada

Este ZIP reúne dos prácticas independientes de MySQL: **BiblioRed** (biblioteca y préstamos) y **FlotaYa** (alquiler de vehículos). Dejé cada una en su propia carpeta para no mezclar las bases de datos ni los datos de ejemplo.

## ¿Qué hay en cada carpeta?

| Archivo | Para qué sirve |
| --- | --- |
| `00_diagrama.md` | Descripción del modelo de datos y las relaciones (conservada como referencia). |
| `01_ddl.sql` | Crea la base, las tablas, las claves y las restricciones. |
| `02_dml.sql` | Inserta los datos de prueba y realiza cambios de registros. |
| `03_dql.sql` | Resuelve las consultas de los casos de negocio. |
| `04_dql_avanzado.sql` | Contiene procedimientos, funciones y pruebas más avanzadas. |
| `05_tcl.sql` | Incluye transacciones, puntos de guardado y reversiones. |

En FlotaYa también dejé la carpeta `evidencias/` con sus capturas originales.

## Cómo ejecutarlo en MySQL Workbench

1. Abre Workbench con una conexión que tenga permisos de creación de bases de datos.
2. Abre los archivos **de un solo taller**, en el orden `01_ddl.sql`, `02_dml.sql`, `03_dql.sql`, `04_dql_avanzado.sql` y `05_tcl.sql`.
3. Ejecuta los scripts uno por uno, revisando las respuestas y mensajes de MySQL.
4. Repite el proceso con el otro taller si lo necesitas. Los nombres de bases son `bibliored` y `flotaya`.

**Importante:** el DDL elimina la base correspondiente si ya existía, así que no ejecutes esos archivos sobre una base que quieras conservar. En FlotaYa el archivo avanzado crea usuarios y roles, por lo que esa sección requiere una cuenta con privilegios administrativos. Algunas pruebas de errores están comentadas a propósito y se ejecutan manualmente por separado cuando quieras comprobar restricciones.

## Cambios hechos en esta edición

- Organicé las carpetas por proyecto y conservé la numeración de ejecución.
- Cambié los alias de referencias a tablas por nombres `ref_...`, y las variables/argumentos internos a `local_...` y `param_...`. Las variables de sesión de pruebas llevan `@revision_...`.
- Unifiqué las palabras clave SQL en minúsculas y limpié los separadores visuales para que la lectura sea más uniforme.
- En dos consultas de registros sin relación cambié `LEFT JOIN ... IS NULL` por `NOT EXISTS`, con la misma intención y las mismas columnas de salida.
- Mantuve los nombres públicos de bases, tablas, columnas, rutinas y roles para no romper llamadas entre archivos.
- Agregué encabezados de sección y conservé explicaciones y pruebas importantes, reordenando la presentación.

## Comprobación pendiente

La revisión hecha aquí es **estática**: no se ejecutó una instancia de MySQL real. Por eso conviene comprobar en Workbench los resultados esperados antes de presentar el trabajo. Las capturas suministradas son evidencia de la versión anterior y no demuestran por sí solas que la versión nueva se haya ejecutado.

**Entorno:** sintaxis preparada para MySQL 8.x y sus características de CTE, roles y funciones de ventana.
