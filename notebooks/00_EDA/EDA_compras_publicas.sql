-- Databricks notebook source
-- MAGIC %md
-- MAGIC **EDA: main.csv (Tabla raíz de procesos de contratación)**

-- COMMAND ----------


-- EDA: main.csv (tabla raíz de procesos de contratación)

-- 1. Vista previa de columnas y datos reales
SELECT * FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/main.csv',
  format => 'csv',
  header => true
)
LIMIT 10;

-- COMMAND ----------

-- 2. Cuántas filas tiene
SELECT COUNT(*) as total_filas FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/main.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

-- 3. Columnas y tipos detectados
DESCRIBE QUERY
SELECT * FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/main.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **EDA: awards.csv (Adjudicaciones)**

-- COMMAND ----------


-- EDA: awards.csv (adjudicaciones — acá está el monto y ganador)

-- 1. Vista previa
SELECT * FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards.csv',
  format => 'csv',
  header => true
)
LIMIT 10;

-- COMMAND ----------

-- 2. Cuántas filas
SELECT COUNT(*) as total_filas FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

-- 3. Columnas y tipos
DESCRIBE QUERY
SELECT * FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **EDA: awards_items.csv(¿qué se compró?)**

-- COMMAND ----------


-- EDA: awards_items.csv 

-- 1. Vista previa
SELECT * FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_items.csv',
  format => 'csv',
  header => true
)
LIMIT 10;

-- COMMAND ----------

-- 2. Cuántas filas
SELECT COUNT(*) as total_filas FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_items.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

-- 3. Columnas y tipos
DESCRIBE QUERY
SELECT * FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_items.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **EDA: awards_suppliers.csv (proveedor ganador de cada adjudicación)**

-- COMMAND ----------

-- EDA: awards_suppliers.csv

SELECT * FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_suppliers.csv',
  format => 'csv',
  header => true
)
LIMIT 10;

-- COMMAND ----------

SELECT COUNT(*) as total_filas FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_suppliers.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

DESCRIBE QUERY
SELECT * FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_suppliers.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **EDA: parties.csv (catálogo completo de compradores y proveedores)**

-- COMMAND ----------

-- EDA: parties.csv (catálogo completo de compradores y proveedores)

SELECT * FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/parties.csv',
  format => 'csv',
  header => true
)
LIMIT 10;

-- COMMAND ----------

DESCRIBE QUERY
SELECT * FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/parties.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Nulos y rangos en el monto**

-- COMMAND ----------

-- Nulos y rangos en el monto
SELECT 
  COUNT(*) as total,
  SUM(CASE WHEN unit_value_amount IS NULL THEN 1 ELSE 0 END) as nulos_monto,
  SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) as nulos_cantidad,
  MIN(TRY_CAST(unit_value_amount AS DOUBLE)) as monto_minimo,
  MAX(TRY_CAST(unit_value_amount AS DOUBLE)) as monto_maximo,
  COUNT(DISTINCT unit_value_currency) as monedas_distintas
FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_items.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

-- Ver qué "monedas" raras aparecen (deberían ser solo códigos de 3 letras como DOP, USD)
SELECT 
  unit_value_currency,
  COUNT(*) as cantidad
FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_items.csv',
  format => 'csv',
  header => true
)
GROUP BY unit_value_currency
ORDER BY cantidad DESC
LIMIT 20;

-- COMMAND ----------

-- Filas donde la "moneda" no es un código de moneda válido de 3 letras
SELECT COUNT(*) as filas_corridas
FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_items.csv',
  format => 'csv',
  header => true
)
WHERE unit_value_currency IS NOT NULL 
  AND LENGTH(unit_value_currency) != 3;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Hallazgos**
-- MAGIC
-- MAGIC
-- MAGIC Se identificó que 1,395 filas (~0.36%) de awards_items.csv presentan corrimiento de columnas, probablemente por comas sin escapar dentro del campo description. Dado que representa una fracción mínima del dataset, en Silver estas filas se excluirán del análisis (filtro WHERE unit_value_currency IN ('DOP','USD', ...) o similar), en vez de intentar reconstruir el parsing — no vale la pena el riesgo de introducir más errores para recuperar 0.36% de las filas.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Análisis Temporal**

-- COMMAND ----------

-- Análisis temporal correcto: solo fechas que castean bien
SELECT 
  COUNT(*) as total_filas,
  SUM(CASE WHEN TRY_CAST(date AS TIMESTAMP) IS NULL THEN 1 ELSE 0 END) as fechas_invalidas,
  MIN(TRY_CAST(date AS TIMESTAMP)) as fecha_minima,
  MAX(TRY_CAST(date AS TIMESTAMP)) as fecha_maxima,
  COUNT(DISTINCT DATE_TRUNC('month', TRY_CAST(date AS TIMESTAMP))) as meses_distintos
FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/main.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

-- Análisis temporal con rango razonable (excluye outliers absurdos)
SELECT 
  COUNT(*) as total_filas,
  SUM(CASE 
    WHEN TRY_CAST(date AS TIMESTAMP) IS NULL 
      OR TRY_CAST(date AS TIMESTAMP) < '2015-01-01' 
      OR TRY_CAST(date AS TIMESTAMP) > '2026-12-31' 
    THEN 1 ELSE 0 END) as fechas_invalidas_o_absurdas,
  MIN(CASE WHEN TRY_CAST(date AS TIMESTAMP) BETWEEN '2015-01-01' AND '2026-12-31' 
       THEN TRY_CAST(date AS TIMESTAMP) END) as fecha_minima,
  MAX(CASE WHEN TRY_CAST(date AS TIMESTAMP) BETWEEN '2015-01-01' AND '2026-12-31' 
       THEN TRY_CAST(date AS TIMESTAMP) END) as fecha_maxima,
  COUNT(DISTINCT CASE WHEN TRY_CAST(date AS TIMESTAMP) BETWEEN '2015-01-01' AND '2026-12-31' 
       THEN DATE_TRUNC('month', TRY_CAST(date AS TIMESTAMP)) END) as meses_distintos
FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/main.csv',
  format => 'csv',
  header => true
);

-- COMMAND ----------

SELECT 
  awards_id,
  descripcion,
  cantidad,
  monto_unitario,
  monto_total
FROM compras_publicas_rd.silver.awards_items
WHERE monto_total > 1000000000
ORDER BY monto_total DESC
LIMIT 10;

-- COMMAND ----------

SELECT 
  approx_percentile(monto_total, 0.50) AS p50_mediana,
  approx_percentile(monto_total, 0.90) AS p90,
  approx_percentile(monto_total, 0.95) AS p95,
  approx_percentile(monto_total, 0.99) AS p99,
  approx_percentile(monto_total, 0.999) AS p99_9,
  MAX(monto_total) AS maximo
FROM compras_publicas_rd.silver.awards_items;

-- COMMAND ----------

SELECT COUNT(*) as filas_excluidas
FROM compras_publicas_rd.silver.awards_items
WHERE monto_total > 111619224.18;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC # EDA — Compras y Contrataciones Públicas de República Dominicana (2025)
-- MAGIC
-- MAGIC ## Fuente de datos
-- MAGIC Dataset OCDS (Open Contracting Data Standard) publicado por Open Contracting Partnership, 
-- MAGIC basado en datos de la Dirección General de Contrataciones Públicas (DGCP) de RD.
-- MAGIC Fuente: https://data.open-contracting.org/es/publication/22
-- MAGIC Año seleccionado: **2025** (año calendario completo)
-- MAGIC
-- MAGIC ## Pregunta de negocio
-- MAGIC ¿Existe concentración de contratos en pocos proveedores? ¿Qué porcentaje del monto 
-- MAGIC total adjudicado se llevan los proveedores más grandes?
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC ## 1. Estructura de los datos
-- MAGIC
-- MAGIC El dataset viene desagregado en múltiples archivos CSV relacionados por `ocid` / `id`. 
-- MAGIC Se identificaron 4 archivos relevantes para esta pregunta de negocio (de los 13 disponibles 
-- MAGIC en el paquete completo):
-- MAGIC
-- MAGIC | Archivo | Filas | Contenido | Rol en el pipeline |
-- MAGIC |---|---|---|---|
-- MAGIC | `main.csv` | 74,368 | Procesos de contratación (tabla raíz) | Fuente de fecha y comprador |
-- MAGIC | `awards.csv` | 71,036 | Adjudicaciones (sin monto) | Conecta proceso con proveedor |
-- MAGIC | `awards_items.csv` | 382,817 | Ítems de cada adjudicación | **Contiene el monto real** (quantity × unit_value_amount) |
-- MAGIC | `awards_suppliers.csv` | 92,885 | Proveedor(es) ganador(es) por adjudicación | Identificación de proveedores |
-- MAGIC
-- MAGIC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Relación entre tablas:**

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Archivos descartados para el MVP:** `parties.csv`, `contracts.csv`, `tender_items.csv`, 
-- MAGIC `bids_details*.csv`, `planning_documents.csv`, `tender_documents.csv`, `tender_sustainability.csv`. 
-- MAGIC No aportan directamente a la pregunta de concentración de proveedores. `parties.csv` queda 
-- MAGIC como candidato para una futura extensión (clasificación MIPYME vs gran empresa, región del proveedor).
-- MAGIC
-- MAGIC **Nota sobre tipos de datos:** todas las columnas llegan como `string` en la ingesta cruda — 
-- MAGIC comportamiento esperado en capa Bronze. El tipado correcto (fechas, decimales) se resuelve en Silver 
-- MAGIC con `TRY_CAST`.
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC ## 2. Valores únicos / relación entre tablas
-- MAGIC
-- MAGIC - `awards_suppliers.csv` tiene **92,885 filas** frente a **71,036** en `awards.csv` → 
-- MAGIC   indica que **existen adjudicaciones con más de un proveedor** (consorcios / uniones temporales). 
-- MAGIC   **Decisión:** se debe definir en el modelado si la fact table queda a nivel de 
-- MAGIC   "adjudicación-proveedor" (una fila por cada combinación) o si se prorratea el monto entre 
-- MAGIC   proveedores de una misma adjudicación.
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC ## 3. Nulos
-- MAGIC
-- MAGIC Sobre `awards_items.csv` (382,817 filas):
-- MAGIC - `unit_value_amount` (monto): **1,552 nulos** (~0.4%)
-- MAGIC - `quantity`: **508 nulos** (~0.1%)
-- MAGIC
-- MAGIC Ambos porcentajes son bajos. **Decisión:** excluir filas con monto o cantidad nula del cálculo 
-- MAGIC de concentración de proveedores (no se puede estimar su valor).
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC ## 4. Rangos y outliers
-- MAGIC
-- MAGIC ### Montos (`awards_items.csv`)
-- MAGIC - Monto mínimo: **0** — hay ítems con valor cero (posible bien/servicio incluido sin costo, 
-- MAGIC   o error de captura). **Decisión:** excluir del cálculo de monto total por proveedor.
-- MAGIC - Monto máximo inicial: **46,514,825,160** (~RD$46,500 millones en un solo ítem) — outlier 
-- MAGIC   extremo, investigado en el punto siguiente.
-- MAGIC
-- MAGIC ### Problema de calidad detectado: corrimiento de columnas
-- MAGIC Se detectó que el campo `unit_value_currency` (que debería contener solo códigos de moneda 
-- MAGIC de 3 letras como DOP o USD) tenía **773 valores distintos**, incluyendo textos como "Unidad", 
-- MAGIC "Caja", "Paquete" y números sueltos.
-- MAGIC
-- MAGIC **Causa identificada:** el campo `description` contiene texto libre con comas sin escapar 
-- MAGIC (ej. *"Papel, tinta y sobres"*), lo que provoca que el parser de CSV interprete esas comas 
-- MAGIC como separadores de columna, corriendo el resto de los valores de la fila una posición hacia 
-- MAGIC la derecha.
-- MAGIC
-- MAGIC **Impacto cuantificado:** 
-- MAGIC - `awards_items.csv`: **1,395 filas afectadas (~0.36%)** 
-- MAGIC - `main.csv`: **2,240 filas con fechas inválidas o absurdas (~3%)**, mismo problema de fondo 
-- MAGIC   (se detectaron incluso años como "247000")
-- MAGIC
-- MAGIC **Decisión:** dado que el porcentaje de filas afectadas es bajo (<4% en ambos casos), se 
-- MAGIC excluirán en Silver mediante filtros de validez (moneda dentro de un catálogo válido, fecha 
-- MAGIC dentro de un rango razonable 2015–2026), en lugar de intentar reparar el parsing — 
-- MAGIC relación costo/beneficio no favorable para recuperar esas filas.
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC ## 5. Duplicados
-- MAGIC *(Pendiente de verificación explícita con `GROUP BY` + `HAVING COUNT(*) > 1` sobre las 
-- MAGIC claves primarias de cada tabla — awards.id, awards_items.id, main.ocid — antes de pasar 
-- MAGIC a Silver)*
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC ## 6. Análisis temporal
-- MAGIC
-- MAGIC Sobre `main.csv`, filtrando fechas dentro de un rango razonable (2015–2026):
-- MAGIC - **Fecha mínima:** 2025-01-02
-- MAGIC - **Fecha máxima:** 2025-12-31
-- MAGIC - **Meses distintos:** 12 (cobertura de año calendario completo) ✅
-- MAGIC
-- MAGIC Confirma que el dataset descargado corresponde efectivamente al año 2025 completo, sin 
-- MAGIC huecos mensuales evidentes.
-- MAGIC
-- MAGIC ---
-- MAGIC
-- MAGIC ## Conclusiones para el diseño de Silver/Gold
-- MAGIC
-- MAGIC 1. Aplicar `TRY_CAST` a todos los campos numéricos y de fecha, ya que en Bronze llegan como string.
-- MAGIC 2. Filtrar `awards_items` por moneda válida (catálogo cerrado: DOP, USD, etc.) para eliminar 
-- MAGIC    filas con corrimiento de columnas.
-- MAGIC 3. Filtrar `main` por rango de fecha razonable (2015–2026) por el mismo motivo.
-- MAGIC 4. Excluir montos nulos o iguales a 0 del cálculo de monto total.
-- MAGIC 5. Definir el grano de la fact table considerando que una adjudicación puede tener múltiples 
-- MAGIC    proveedores (decisión de modelado pendiente: ¿fila por adjudicación-proveedor, o prorrateo?).
-- MAGIC 6. El monto total de una adjudicación se calcula agregando `awards_items` (`SUM(quantity * unit_value_amount)`), 
-- MAGIC    no viene directo en `awards.csv`.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Decisión de modelado: grano de la fact table
-- MAGIC
-- MAGIC **Hallazgo del EDA:** `awards_suppliers.csv` tiene 92,885 filas frente a 71,036 en 
-- MAGIC `awards.csv` → existen adjudicaciones con más de un proveedor (consorcios/uniones temporales).
-- MAGIC
-- MAGIC **Decisión:** la fact table (`fact_adjudicacion_proveedor`) tendrá grano 
-- MAGIC **adjudicación + proveedor**, no solo adjudicación. Si una adjudicación tiene 2 
-- MAGIC proveedores, el monto se prorratea entre ambos (`monto_total / cantidad_proveedores`), 
-- MAGIC para evitar duplicar el monto al sumar por proveedor en el análisis de concentración.
-- MAGIC
-- MAGIC **Modelo dimensional definido:**
-- MAGIC - `fact_adjudicacion_proveedor`: proveedor_id (FK), comprador_id (FK), tiempo_id (FK), 
-- MAGIC   monto_total_adjudicacion, monto_prorrateado, cantidad_proveedores, cantidad_items
-- MAGIC - `dim_proveedor`: proveedor_sk, rpe, nombre
-- MAGIC - `dim_comprador`: comprador_sk, institucion_id, nombre_institucion
-- MAGIC - `dim_tiempo`: tiempo_sk, fecha, año, mes, trimestre, dia_semana

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Nota de actualización (post-diseño)
-- MAGIC
-- MAGIC La estrategia de manejo de filas corruptas descrita arriba (filtrar por moneda/fecha 
-- MAGIC en Silver) fue **reemplazada** durante la Fase 5 (ETL Bronze): se detectó que la causa 
-- MAGIC raíz era comillas sin escapar en campos de texto libre, corrompiendo también el `id`. 
-- MAGIC La solución final usa `mode => 'DROPMALFORMED'` en la ingesta de Bronze — ver detalle 
-- MAGIC en `notebooks/02_Bronze/ETL_bronze_compras.sql`.

-- COMMAND ----------

SELECT COUNT(*) as filas_sin_institucion
FROM compras_publicas_rd.gold.fact_adjudicacion_proveedor
WHERE comprador_sk IS NULL;