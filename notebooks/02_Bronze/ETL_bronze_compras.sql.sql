-- Databricks notebook source
-- MAGIC %md
-- MAGIC **ETL Bronze: ingesta cruda desde CSV**

-- COMMAND ----------

-- ETL Bronze
-- INSERT OVERWRITE = idempotente (reemplaza toda la tabla en cada corrida)

-- 1. main.csv
INSERT OVERWRITE compras_publicas_rd.bronze.main
SELECT 
  id, tag, date, ocid, language, initiationType, tender_id,
  tender_procurementMethodDetails, tender_title, tender_procurementMethod,
  tender_status, tender_mainProcurementCategory, tender_numberOfTenderers,
  tender_description, tender_value_amount, tender_value_currency,
  tender_awardPeriod_endDate, tender_awardPeriod_startDate,
  tender_tenderPeriod_endDate, tender_tenderPeriod_startDate,
  tender_contractPeriod_durationInDays, tender_procuringEntity_id,
  tender_procuringEntity_name, planning_budget_description,
  planning_budget_amount_amount, planning_budget_amount_currency,
  _rescued_data,
  'main.csv' AS _source,
  current_timestamp() AS _ingested_at
FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/main.csv',
  format => 'csv',
  header => true,
  mode => 'DROPMALFORMED'
);

-- 2. awards.csv
INSERT OVERWRITE compras_publicas_rd.bronze.awards
SELECT 
  id, date, status, main_ocid, main_id, _rescued_data,
  'awards.csv' AS _source,
  current_timestamp() AS _ingested_at
FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards.csv',
  format => 'csv',
  header => true,
  mode => 'DROPMALFORMED'
);

-- 3. awards_items.csv
INSERT OVERWRITE compras_publicas_rd.bronze.awards_items
SELECT 
  id, description, quantity, unit_id, unit_name, unit_value_amount,
  unit_value_currency, classification_id, classification_scheme,
  classification_description, main_ocid, main_id, awards_id, _rescued_data,
  'awards_items.csv' AS _source,
  current_timestamp() AS _ingested_at
FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_items.csv',
  format => 'csv',
  header => true,
  mode => 'DROPMALFORMED'
);

-- 4. awards_suppliers.csv
INSERT OVERWRITE compras_publicas_rd.bronze.awards_suppliers
SELECT 
  id, name, main_ocid, main_id, awards_id, _rescued_data,
  'awards_suppliers.csv' AS _source,
  current_timestamp() AS _ingested_at
FROM read_files(
  '/Volumes/compras_publicas_rd/bronze/raw_files/awards_suppliers.csv',
  format => 'csv',
  header => true,
  mode => 'DROPMALFORMED'
);

-- Verificación rápida de conteos
SELECT 'main' as tabla, COUNT(*) as filas FROM compras_publicas_rd.bronze.main
UNION ALL
SELECT 'awards', COUNT(*) FROM compras_publicas_rd.bronze.awards
UNION ALL
SELECT 'awards_items', COUNT(*) FROM compras_publicas_rd.bronze.awards_items
UNION ALL
SELECT 'awards_suppliers', COUNT(*) FROM compras_publicas_rd.bronze.awards_suppliers;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Sobre este ETL
-- MAGIC
-- MAGIC Ingesta los 4 archivos CSV del Volume `raw_files` hacia las tablas Bronze, agregando 
-- MAGIC metadata de trazabilidad (`_source`, `_ingested_at`).
-- MAGIC
-- MAGIC **Idempotencia:** se usa `INSERT OVERWRITE` en vez de `INSERT INTO`. Como la fuente 
-- MAGIC es un archivo estático completo (no un incremento), reemplazar toda la tabla en cada 
-- MAGIC corrida es la estrategia correcta — ejecutar el pipeline 2 veces da exactamente el 
-- MAGIC mismo resultado, sin generar duplicados.
-- MAGIC
-- MAGIC **Hallazgo de calidad (actualización post-EDA):** al intentar el `MERGE` en Silver, 
-- MAGIC se detectó que filas con comillas dobles sin escapar dentro de campos de texto libre 
-- MAGIC (`tender_description`, `awards_items.description`) rompían la sincronía de columnas 
-- MAGIC del parser CSV — el contenido de texto terminaba invadiendo columnas como `id`, 
-- MAGIC generando IDs corruptos y "duplicados" falsos que hacían fallar el `MERGE`.
-- MAGIC
-- MAGIC **Decisión:** en vez de filtrar los síntomas caso por caso en Silver (moneda inválida, 
-- MAGIC fecha fuera de rango), se resuelve en el origen agregando `mode => 'DROPMALFORMED'` 
-- MAGIC a `read_files()` en las 4 lecturas — Spark descarta automáticamente cualquier fila 
-- MAGIC mal formada al momento de leer el CSV.
-- MAGIC
-- MAGIC **Conteos actualizados** (vs. los originales del EDA):
-- MAGIC
-- MAGIC | Tabla | Original | Con DROPMALFORMED | Filas descartadas |
-- MAGIC |---|---|---|---|
-- MAGIC | main | 74,368 | 69,746 | 4,622 |
-- MAGIC | awards | 71,036 | 71,036 | 0 |
-- MAGIC | awards_items | 382,817 | 378,510 | 4,307 |
-- MAGIC | awards_suppliers | 92,885 | 92,885 | 0 |
-- MAGIC
-- MAGIC Nota: la cantidad descartada es mayor a la estimada inicialmente en el EDA (que solo 
-- MAGIC detectaba el problema vía síntomas indirectos, como fechas o monedas inválidas) — 
-- MAGIC `DROPMALFORMED` captura el problema de raíz, de forma más completa y confiable.