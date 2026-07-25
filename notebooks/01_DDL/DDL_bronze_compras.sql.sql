-- Databricks notebook source
-- MAGIC %md
-- MAGIC **DDL: Tablas Bronze (datos crudos + metadata)**

-- COMMAND ----------

-- DDL: Tablas Bronze

CREATE TABLE IF NOT EXISTS compras_publicas_rd.bronze.main (
  id STRING,
  tag STRING,
  date STRING,
  ocid STRING,
  language STRING,
  initiationType STRING,
  tender_id STRING,
  tender_procurementMethodDetails STRING,
  tender_title STRING,
  tender_procurementMethod STRING,
  tender_status STRING,
  tender_mainProcurementCategory STRING,
  tender_numberOfTenderers STRING,
  tender_description STRING,
  tender_value_amount STRING,
  tender_value_currency STRING,
  tender_awardPeriod_endDate STRING,
  tender_awardPeriod_startDate STRING,
  tender_tenderPeriod_endDate STRING,
  tender_tenderPeriod_startDate STRING,
  tender_contractPeriod_durationInDays STRING,
  tender_procuringEntity_id STRING,
  tender_procuringEntity_name STRING,
  planning_budget_description STRING,
  planning_budget_amount_amount STRING,
  planning_budget_amount_currency STRING,
  _rescued_data STRING,
  _source STRING,
  _ingested_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compras_publicas_rd.bronze.awards (
  id STRING,
  date STRING,
  status STRING,
  main_ocid STRING,
  main_id STRING,
  _rescued_data STRING,
  _source STRING,
  _ingested_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compras_publicas_rd.bronze.awards_items (
  id STRING,
  description STRING,
  quantity STRING,
  unit_id STRING,
  unit_name STRING,
  unit_value_amount STRING,
  unit_value_currency STRING,
  classification_id STRING,
  classification_scheme STRING,
  classification_description STRING,
  main_ocid STRING,
  main_id STRING,
  awards_id STRING,
  _rescued_data STRING,
  _source STRING,
  _ingested_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compras_publicas_rd.bronze.awards_suppliers (
  id STRING,
  name STRING,
  main_ocid STRING,
  main_id STRING,
  awards_id STRING,
  _rescued_data STRING,
  _source STRING,
  _ingested_at TIMESTAMP
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Sobre las tablas Bronze
-- MAGIC
-- MAGIC Estas 4 tablas replican la estructura cruda de los archivos fuente (`main`, `awards`, 
-- MAGIC `awards_items`, `awards_suppliers`), sin ninguna transformación:
-- MAGIC
-- MAGIC - **Todas las columnas son STRING**, incluso las que claramente son fechas o números. 
-- MAGIC   Esto es intencional: Bronze conserva el dato tal como llegó, sin asumir que el tipo 
-- MAGIC   original es confiable. El tipado correcto se aplica recién en Silver con `TRY_CAST`.
-- MAGIC - **`_rescued_data`**: columna que captura datos que no encajaron bien en el schema 
-- MAGIC   esperado — útil para no perder información silenciosamente.
-- MAGIC - **`_source`**: de qué archivo/proceso vino el registro (trazabilidad).
-- MAGIC - **`_ingested_at`**: cuándo se cargó el registro — permite auditar el pipeline y 
-- MAGIC   detectar si una carga falló o quedó desactualizada.
-- MAGIC
-- MAGIC Estas tablas todavía están vacías (solo definimos la estructura). El siguiente paso 
-- MAGIC es el ETL de ingesta, que las llena a partir de los CSV en el Volume.