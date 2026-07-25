-- Databricks notebook source
-- ETL Gold: dim_proveedor (SCD Type 1)

MERGE INTO compras_publicas_rd.gold.dim_proveedor AS target
USING (
  SELECT id AS rpe, MAX(nombre) AS nombre
  FROM compras_publicas_rd.silver.awards_suppliers
  GROUP BY id
) AS source
ON target.rpe = source.rpe
WHEN MATCHED THEN UPDATE SET nombre = source.nombre, _ingested_at = current_timestamp()
WHEN NOT MATCHED THEN INSERT (rpe, nombre, _ingested_at) 
  VALUES (source.rpe, source.nombre, current_timestamp())
WHEN NOT MATCHED BY SOURCE THEN DELETE;

SELECT COUNT(*) as total_proveedores FROM compras_publicas_rd.gold.dim_proveedor;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Sobre esta dimensión
-- MAGIC
-- MAGIC Carga los proveedores únicos a partir de `silver.awards_suppliers`, usando `rpe` 
-- MAGIC (Registro de Proveedores del Estado) como clave de negocio.
-- MAGIC
-- MAGIC **SCD Type 1:** si el nombre de un proveedor cambia en el origen, se sobrescribe 
-- MAGIC directamente (no se guarda histórico) — suficiente para este proyecto, ya que el 
-- MAGIC TP no exige SCD Type 2.
-- MAGIC
-- MAGIC **Simplificación tomada:** se usa `MAX(nombre)` para quedarse con un solo nombre 
-- MAGIC por `rpe`, en caso de que existan variaciones de escritura para el mismo proveedor 
-- MAGIC (validación que quedó pendiente del EDA — posible mejora futura: normalizar nombres 
-- MAGIC antes de agrupar).
-- MAGIC
-- MAGIC **Resultado:** 11,746 proveedores únicos, frente a 92,885 registros de adjudicación-proveedor 
-- MAGIC — confirma que hay proveedores con múltiples adjudicaciones, base del análisis de concentración.