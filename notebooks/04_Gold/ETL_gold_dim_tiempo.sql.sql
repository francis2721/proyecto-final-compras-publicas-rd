-- Databricks notebook source
-- ETL Gold: dim_tiempo
-- Se genera a partir de las fechas reales de adjudicación (silver.awards)

MERGE INTO compras_publicas_rd.gold.dim_tiempo AS target
USING (
  SELECT DISTINCT
    CAST(fecha AS DATE) AS fecha,
    YEAR(fecha) AS anio,
    MONTH(fecha) AS mes,
    QUARTER(fecha) AS trimestre,
    DATE_FORMAT(fecha, 'EEEE') AS dia_semana,
    CONCAT(
      CASE MONTH(fecha)
        WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' WHEN 12 THEN 'Diciembre'
      END, ' ', YEAR(fecha)
    ) AS mes_anio_texto,
    YEAR(fecha) * 100 + MONTH(fecha) AS mes_anio_orden
  FROM compras_publicas_rd.silver.awards
  WHERE fecha IS NOT NULL
) AS source
ON target.fecha = source.fecha
WHEN MATCHED THEN UPDATE SET
  target.anio = source.anio,
  target.mes = source.mes,
  target.trimestre = source.trimestre,
  target.dia_semana = source.dia_semana,
  target.mes_anio_texto = source.mes_anio_texto,
  target.mes_anio_orden = source.mes_anio_orden,
  target._ingested_at = current_timestamp()
WHEN NOT MATCHED THEN INSERT (fecha, anio, mes, trimestre, dia_semana, mes_anio_texto, mes_anio_orden, _ingested_at)
  VALUES (source.fecha, source.anio, source.mes, source.trimestre, source.dia_semana, source.mes_anio_texto, source.mes_anio_orden, current_timestamp())
WHEN NOT MATCHED BY SOURCE THEN DELETE;

SELECT COUNT(*) as total_fechas FROM compras_publicas_rd.gold.dim_tiempo;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Sobre esta dimensión
-- MAGIC
-- MAGIC Se genera a partir de las fechas reales presentes en `silver.awards` (fecha de 
-- MAGIC adjudicación), no de un calendario completo generado aparte — es la fecha que 
-- MAGIC efectivamente usa la fact table.
-- MAGIC
-- MAGIC **Columnas derivadas:** `anio`, `mes`, `trimestre` y `dia_semana` se calculan con 
-- MAGIC funciones nativas de Spark SQL (`YEAR`, `MONTH`, `QUARTER`, `DATE_FORMAT`) a partir 
-- MAGIC de la fecha, para habilitar los filtros temporales del dashboard sin tener que 
-- MAGIC recalcularlos en cada consulta.

-- COMMAND ----------

SELECT MIN(fecha) as min_fecha, MAX(fecha) as max_fecha, 
       COUNT(DISTINCT YEAR(fecha)) as anios_distintos
FROM compras_publicas_rd.gold.dim_tiempo;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Hallazgo:** el rango real de fechas es 2025-01-02 a 2026-06-19 (2 años calendario), 
-- MAGIC no solo 2025 como el resto del dataset. Esto es porque `fecha` corresponde a la fecha 
-- MAGIC de **adjudicación** (`awards.date`), no de publicación del proceso — y una adjudicación 
-- MAGIC puede resolverse varios meses después de publicado el proceso original. Explica las 
-- MAGIC 431 fechas distintas en la dimensión.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC