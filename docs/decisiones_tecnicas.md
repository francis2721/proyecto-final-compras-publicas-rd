# Decisiones Técnicas del Proyecto

## 1. Elección del dataset

Se evaluaron varias opciones antes de decidir por compras públicas de RD:
- Mercado bursátil/acciones: descartado por ser un dataset "de laboratorio", sin 
  valor de negocio diferenciado
- LinkedIn Job Postings (tech/data): válido pero sin conexión geográfica a RD
- Datos de SIGERD (centros educativos): descartado por consideraciones éticas — 
  la data se obtuvo por un rol laboral previo, sin autorización explícita para 
  republicarla públicamente

**Decisión final**: compras y contrataciones públicas de RD — dataset 100% 
público (vía Open Contracting Partnership), sin dilemas éticos, con grano de 
fact table claro y conexión con mi perfil de economista.

## 2. Granularidad de la fact table

**Hallazgo del EDA**: `awards_suppliers.csv` tiene 92,885 filas frente a 71,036 
en `awards.csv` → existen adjudicaciones con más de un proveedor (consorcios).

**Decisión**: la fact table (`fact_adjudicacion_proveedor`) tiene grano 
**adjudicación + proveedor**, no solo adjudicación. Si una adjudicación tiene 
2 proveedores, el monto se prorratea entre ambos, para evitar duplicar el monto 
al sumar por proveedor en el análisis de concentración.

## 3. Cálculo del monto de adjudicación

El monto no viene directo en `awards.csv` — se calcula agregando 
`awards_items` (`SUM(quantity * unit_value_amount)` por `awards_id`), ya que 
el monto real vive a nivel de ítem dentro de cada adjudicación.

## 4. Problema de calidad: corrimiento de columnas

**Causa raíz**: comillas dobles sin escapar dentro de campos de texto libre 
(`description`, `tender_description`) rompían la sincronía de columnas del 
parser CSV, corrompiendo incluso la columna `id` con fragmentos de texto.

**Solución**:
1. `mode => 'DROPMALFORMED'` en `read_files()` de Bronze (las 4 lecturas) — 
   resuelve la mayoría de los casos
2. Filtro adicional en Silver (`id RLIKE '^[0-9]+$'`) para un caso residual en 
   `awards_items` que `DROPMALFORMED` no capturaba (forma de fila válida, 
   contenido incorrecto)

## 5. Filtro de outliers de monto

**Hallazgo**: al analizar percentiles de `monto_total` en `awards_items` 
(p50=14,238, p90=247,776, p95=738,738, p99=6,243,050, p99.9=111,619,224), el 
valor máximo original (46,514,825,160) era 416 veces mayor al p99.9 — un salto 
abrupto que no corresponde a una distribución natural.

**Validación**: se revisaron los ítems con montos extremos y se encontraron 
errores de captura evidentes (ej. "papel higiénico" a RD$960,170/paquete, 
"licencia de conducir" a RD$3,784 millones) — precios unitarios absurdos para 
el tipo de producto.

**Decisión**: excluir valores por encima del percentil 99.9 (404 filas, ~0.1% 
del dataset) — criterio estadístico defendible, no un número arbitrario.

## 6. Estrategia de idempotencia por capa

- **Bronze**: `INSERT OVERWRITE` — la fuente es un archivo estático completo 
  (no incremental), así que reemplazar toda la tabla en cada corrida es 
  suficiente y correcto
- **Silver y Gold**: `MERGE` (requisito obligatorio del TP), con las 3 
  cláusulas necesarias para idempotencia real frente a cambios en el origen:
```sql
  WHEN MATCHED THEN UPDATE SET ...
  WHEN NOT MATCHED THEN INSERT ...
  WHEN NOT MATCHED BY SOURCE THEN DELETE
```
  Sin el `DELETE`, filas que dejan de cumplir un filtro de calidad quedan 
  "huérfanas" en el destino — se comprobó en la práctica: antes de agregar 
  esta cláusula, Silver tenía 72,128 filas en `main` mientras Bronze ya tenía 
  solo 69,746 tras un ajuste de calidad.
- Verificado con corridas dobles consecutivas del pipeline completo, dando 
  resultados idénticos en ambas.

## 7. Surrogate keys y columnas IDENTITY

Las dimensiones usan `GENERATED ALWAYS AS IDENTITY` para las surrogate keys. 
Al escribir los `MERGE`, es necesario listar las columnas explícitamente en 
`UPDATE SET` e `INSERT` (no usar `*`), porque `*` intenta escribir también en 
la columna IDENTITY, generando el error `DELTA_MERGE_UNRESOLVED_EXPRESSION`.

## 8. Manejo de comprador nulo

**Hallazgo**: ~3.4% de las adjudicaciones (2,982 de ~88,000) no tienen 
institución compradora identificada en el dato de origen 
(`tender_procuringEntity_id` vacío).

**Decisión**: se excluyen del ranking de Top instituciones compradoras (KPI 
específico), sin afectar el resto del análisis de concentración de 
proveedores, que es la pregunta de negocio central del proyecto.

## 9. Herramienta de visualización

Se usó Power BI Desktop (versión gratuita) en vez de Databricks SQL Dashboards, 
conectado vía SQL Warehouse + Personal Access Token (scope "Herramientas de 
BI"). La versión gratuita es suficiente porque la demo se realiza compartiendo 
pantalla en vivo — Power BI Pro solo es necesario para publicar y compartir 
reportes por link, algo que no aplica para la defensa del proyecto.
