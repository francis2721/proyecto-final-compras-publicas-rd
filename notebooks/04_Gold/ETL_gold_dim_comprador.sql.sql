-- Databricks notebook source
-- ETL Gold: dim_comprador (SCD Type 1)

MERGE INTO compras_publicas_rd.gold.dim_comprador AS target
USING (
  SELECT institucion_id, MAX(institucion_nombre) AS nombre_institucion
  FROM compras_publicas_rd.silver.main
  WHERE institucion_id IS NOT NULL
  GROUP BY institucion_id
) AS source
ON target.institucion_id = source.institucion_id
WHEN MATCHED THEN UPDATE SET nombre_institucion = source.nombre_institucion, _ingested_at = current_timestamp()
WHEN NOT MATCHED THEN INSERT (institucion_id, nombre_institucion, _ingested_at) 
  VALUES (source.institucion_id, source.nombre_institucion, current_timestamp())
WHEN NOT MATCHED BY SOURCE THEN DELETE;

SELECT COUNT(*) as total_compradores FROM compras_publicas_rd.gold.dim_comprador;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Sobre esta dimensión
-- MAGIC
-- MAGIC Carga las instituciones compradoras únicas a partir de `silver.main`, usando 
-- MAGIC `institucion_id` como clave de negocio.
-- MAGIC
-- MAGIC **SCD Type 1:** mismo criterio que `dim_proveedor` — se sobrescribe el nombre si cambia.
-- MAGIC
-- MAGIC **Filtro aplicado:** se excluyen registros con `institucion_id` nulo, ya que sin ese 
-- MAGIC identificador no se puede vincular la fact table a un comprador válido.