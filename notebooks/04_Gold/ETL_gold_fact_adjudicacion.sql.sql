-- Databricks notebook source
-- ETL Gold: fact_adjudicacion_proveedor
-- Calcula monto_total por adjudicación (sumando items) y lo prorratea 
-- entre los proveedores de esa adjudicación

MERGE INTO compras_publicas_rd.gold.fact_adjudicacion_proveedor AS target
USING (
  WITH montos_por_adjudicacion AS (
    SELECT 
      awards_id,
      SUM(monto_total) AS monto_total_adjudicacion,
      COUNT(*) AS cantidad_items
    FROM compras_publicas_rd.silver.awards_items
    GROUP BY awards_id
  ),
  proveedores_por_adjudicacion AS (
    SELECT 
      awards_id,
      id AS rpe,
      COUNT(*) OVER (PARTITION BY awards_id) AS cantidad_proveedores
    FROM compras_publicas_rd.silver.awards_suppliers
  )
  SELECT
    a.id AS adjudicacion_id,
    dp.proveedor_sk,
    dc.comprador_sk,
    dt.tiempo_sk,
    m.monto_total_adjudicacion,
    m.monto_total_adjudicacion / p.cantidad_proveedores AS monto_prorrateado,
    p.cantidad_proveedores,
    m.cantidad_items,
    current_timestamp() AS _ingested_at
  FROM compras_publicas_rd.silver.awards a
  INNER JOIN montos_por_adjudicacion m ON m.awards_id = a.id
  INNER JOIN proveedores_por_adjudicacion p ON p.awards_id = a.id
  INNER JOIN compras_publicas_rd.gold.dim_proveedor dp ON dp.rpe = p.rpe
  LEFT JOIN compras_publicas_rd.silver.main main_t ON main_t.id = a.main_id
  LEFT JOIN compras_publicas_rd.gold.dim_comprador dc ON dc.institucion_id = main_t.institucion_id
  LEFT JOIN compras_publicas_rd.gold.dim_tiempo dt ON dt.fecha = CAST(a.fecha AS DATE)
) AS source
ON target.adjudicacion_id = source.adjudicacion_id AND target.proveedor_sk = source.proveedor_sk
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
WHEN NOT MATCHED BY SOURCE THEN DELETE;

-- Verificación
SELECT COUNT(*) as total_filas_fact FROM compras_publicas_rd.gold.fact_adjudicacion_proveedor;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Sobre la fact table
-- MAGIC
-- MAGIC Corazón del modelo dimensional — implementa el grano definido en la Fase 3: 
-- MAGIC **1 fila = 1 combinación única de adjudicación + proveedor**.
-- MAGIC
-- MAGIC **Lógica de cálculo:**
-- MAGIC 1. `montos_por_adjudicacion`: suma todos los ítems (`awards_items`) de cada 
-- MAGIC    adjudicación para obtener el monto total real (no viene directo en `awards.csv`, 
-- MAGIC    como se documentó en el EDA)
-- MAGIC 2. `proveedores_por_adjudicacion`: cuenta cuántos proveedores tiene cada adjudicación, 
-- MAGIC    usando `COUNT() OVER (PARTITION BY awards_id)`
-- MAGIC 3. El monto final se prorratea: `monto_total_adjudicacion / cantidad_proveedores` 
-- MAGIC    — decisión de modelado documentada en el EDA, para evitar duplicar el monto al 
-- MAGIC    sumar por proveedor en adjudicaciones con consorcios
-- MAGIC
-- MAGIC **Joins:** conecta `silver.awards` con las 3 dimensiones Gold para traer los 
-- MAGIC surrogate keys correspondientes (`proveedor_sk`, `comprador_sk`, `tiempo_sk`). 
-- MAGIC Los joins a `dim_comprador` y `dim_tiempo` son `LEFT JOIN` (una adjudicación siempre 
-- MAGIC tiene proveedor, pero podría no tener comprador o fecha bien formada) — el `JOIN` 
-- MAGIC a `dim_proveedor` es `INNER`, porque sin proveedor no tiene sentido esa fila para 
-- MAGIC el análisis de concentración.

-- COMMAND ----------

SELECT COUNT(*) as adjudicaciones_sin_proveedor_en_dim
FROM compras_publicas_rd.silver.awards a
LEFT JOIN compras_publicas_rd.silver.awards_suppliers s ON s.awards_id = a.id
LEFT JOIN compras_publicas_rd.gold.dim_proveedor dp ON dp.rpe = s.id
WHERE s.id IS NOT NULL AND dp.rpe IS NULL;