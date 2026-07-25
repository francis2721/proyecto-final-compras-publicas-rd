-- Databricks notebook source
-- MAGIC %md
-- MAGIC **DDL: Dimensiones Gold**

-- COMMAND ----------

-- DDL: Dimensiones Gold

-- DDL: Dimensiones Gold

CREATE TABLE IF NOT EXISTS compras_publicas_rd.gold.dim_proveedor (
  proveedor_sk BIGINT GENERATED ALWAYS AS IDENTITY,
  rpe STRING NOT NULL,
  nombre STRING,
  _ingested_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compras_publicas_rd.gold.dim_comprador (
  comprador_sk BIGINT GENERATED ALWAYS AS IDENTITY,
  institucion_id STRING NOT NULL,
  nombre_institucion STRING,
  _ingested_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compras_publicas_rd.gold.dim_tiempo (
  tiempo_sk BIGINT GENERATED ALWAYS AS IDENTITY,
  fecha DATE NOT NULL,
  anio INT,
  mes INT,
  trimestre INT,
  dia_semana STRING,
  mes_anio_texto STRING,
  mes_anio_orden INT,
  _ingested_at TIMESTAMP
);

-- DDL: Fact table Gold

CREATE TABLE IF NOT EXISTS compras_publicas_rd.gold.fact_adjudicacion_proveedor (
  adjudicacion_id STRING NOT NULL,
  proveedor_sk BIGINT,
  comprador_sk BIGINT,
  tiempo_sk BIGINT,
  monto_total_adjudicacion DOUBLE,
  monto_prorrateado DOUBLE,
  cantidad_proveedores INT,
  cantidad_items INT,
  _ingested_at TIMESTAMP
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Sobre las tablas Gold
-- MAGIC
-- MAGIC Gold es la capa final del modelo dimensional (Star Schema), lista para conectar 
-- MAGIC al dashboard. Se compone de 3 dimensiones y 1 fact table:
-- MAGIC
-- MAGIC - **Surrogate keys (`GENERATED ALWAYS AS IDENTITY`)**: cada dimensión tiene su propia 
-- MAGIC   clave autogenerada (`proveedor_sk`, `comprador_sk`, `tiempo_sk`), en vez de usar 
-- MAGIC   directamente el identificador natural (RPE, institución, fecha). Esto desacopla 
-- MAGIC   el modelo de cómo cambien esos IDs en el origen, y es más eficiente para los JOINs 
-- MAGIC   con la fact table.
-- MAGIC - **`dim_proveedor`** y **`dim_comprador`** llevan `rpe` / `institucion_id` como 
-- MAGIC   `NOT NULL` porque son las claves de negocio usadas para el `MERGE` (SCD Type 1) 
-- MAGIC   que mantiene estas dimensiones actualizadas sin duplicados.
-- MAGIC - **`dim_tiempo`** se genera a partir de las fechas reales presentes en los datos 
-- MAGIC   (no es un calendario completo generado aparte), con `fecha` como clave de negocio.
-- MAGIC - **`fact_adjudicacion_proveedor`**: grano definido en la Fase 3 — una fila por cada 
-- MAGIC   combinación única de adjudicación + proveedor. Contiene las métricas numéricas 
-- MAGIC   (`monto_total_adjudicacion`, `monto_prorrateado`) y las FKs a las 3 dimensiones 
-- MAGIC   vía sus surrogate keys.
-- MAGIC
-- MAGIC Con estas 4 tablas creadas (vacías), el modelo dimensional queda completamente 
-- MAGIC definido. El siguiente paso es poblar todo el pipeline: primero Bronze (ETL de 
-- MAGIC ingesta desde los CSV), después Silver (limpieza), y finalmente Gold (carga de 
-- MAGIC dimensiones y fact con MERGE para garantizar idempotencia).