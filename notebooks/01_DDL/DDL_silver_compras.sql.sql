-- Databricks notebook source
-- MAGIC %md
-- MAGIC **DDL: Tablas Silver (datos limpios y tipados)**

-- COMMAND ----------

-- DDL: Tablas Silver

CREATE TABLE IF NOT EXISTS compras_publicas_rd.silver.main (
  id STRING,
  ocid STRING,
  fecha_publicacion TIMESTAMP,
  institucion_id STRING,
  institucion_nombre STRING,
  tender_titulo STRING,
  tender_estado STRING,
  tender_categoria STRING,
  valor_estimado DOUBLE,
  valor_moneda STRING,
  _ingested_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compras_publicas_rd.silver.awards (
  id STRING,
  main_id STRING,
  main_ocid STRING,
  fecha TIMESTAMP,
  estado STRING,
  _ingested_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compras_publicas_rd.silver.awards_items (
  id STRING,
  awards_id STRING,
  main_id STRING,
  descripcion STRING,
  cantidad DOUBLE,
  monto_unitario DOUBLE,
  moneda STRING,
  monto_total DOUBLE,
  _ingested_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compras_publicas_rd.silver.awards_suppliers (
  id STRING,
  nombre STRING,
  awards_id STRING,
  main_id STRING,
  _ingested_at TIMESTAMP
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Sobre las tablas Silver
-- MAGIC
-- MAGIC Estas 4 tablas son la versión limpia y tipada de las tablas Bronze, con estos cambios 
-- MAGIC respecto al crudo:
-- MAGIC
-- MAGIC - **Tipos correctos**: `fecha_publicacion` y `fecha` pasan de STRING a TIMESTAMP; 
-- MAGIC   `valor_estimado`, `cantidad`, `monto_unitario` y `monto_total` pasan a DOUBLE. 
-- MAGIC   Se aplican con `TRY_CAST` en el ETL (no con `CAST`), para que un valor corrupto 
-- MAGIC   se convierta en NULL en vez de romper toda la carga.
-- MAGIC - **Nombres simplificados**: se acortan los nombres verbosos del estándar OCDS 
-- MAGIC   (ej. `tender_procuringEntity_name` → `institucion_nombre`) para que el modelo 
-- MAGIC   sea más legible.
-- MAGIC - **Columna calculada `monto_total`** (en `awards_items`): se agrega `cantidad × monto_unitario`, 
-- MAGIC   ya resuelta en Silver para no repetir el cálculo en cada consulta de Gold.
-- MAGIC - **Se descartan columnas de Bronze que no aportan** al análisis (`_rescued_data`, 
-- MAGIC   `tag`, `language`, etc.) — Silver solo conserva lo que realmente se va a usar.
-- MAGIC - **Aplican los filtros de calidad definidos en el EDA**: en el ETL (no en el DDL) 
-- MAGIC   se van a excluir las filas con corrimiento de columnas (moneda inválida, fecha 
-- MAGIC   fuera de rango 2015–2026) y los montos nulos o en cero.
-- MAGIC
-- MAGIC Estas tablas todavía están vacías, la limpieza real ocurre en el ETL de Silver 
-- MAGIC (próxima fase), que lee de Bronze, aplica estas transformaciones, y hace MERGE 
-- MAGIC hacia acá para mantener la idempotencia.