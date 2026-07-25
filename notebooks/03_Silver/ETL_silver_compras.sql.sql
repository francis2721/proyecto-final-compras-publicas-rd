-- Databricks notebook source
-- MAGIC %md
-- MAGIC **ETL Silver: limpieza, tipado y filtros de calidad**

-- COMMAND ----------

-- ETL Silver: limpieza, tipado y filtros de calidad
-- MERGE = idempotente + requisito obligatorio del TP

-- 1. main
MERGE INTO compras_publicas_rd.silver.main AS target
USING (
  SELECT 
    id,
    ocid,
    TRY_CAST(date AS TIMESTAMP) AS fecha_publicacion,
    tender_procuringEntity_id AS institucion_id,
    tender_procuringEntity_name AS institucion_nombre,
    tender_title AS tender_titulo,
    tender_status AS tender_estado,
    tender_mainProcurementCategory AS tender_categoria,
    TRY_CAST(tender_value_amount AS DOUBLE) AS valor_estimado,
    tender_value_currency AS valor_moneda,
    current_timestamp() AS _ingested_at
  FROM compras_publicas_rd.bronze.main
  WHERE TRY_CAST(date AS TIMESTAMP) BETWEEN '2015-01-01' AND '2026-12-31'
) AS source
ON target.id = source.id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
WHEN NOT MATCHED BY SOURCE THEN DELETE;

-- 2. awards
MERGE INTO compras_publicas_rd.silver.awards AS target
USING (
  SELECT 
    id,
    main_id,
    main_ocid,
    TRY_CAST(date AS TIMESTAMP) AS fecha,
    status AS estado,
    current_timestamp() AS _ingested_at
  FROM compras_publicas_rd.bronze.awards
) AS source
ON target.id = source.id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
WHEN NOT MATCHED BY SOURCE THEN DELETE;

-- 3. awards_items
MERGE INTO compras_publicas_rd.silver.awards_items AS target
USING (
  SELECT 
    id,
    awards_id,
    main_id,
    description AS descripcion,
    TRY_CAST(quantity AS DOUBLE) AS cantidad,
    TRY_CAST(unit_value_amount AS DOUBLE) AS monto_unitario,
    unit_value_currency AS moneda,
    TRY_CAST(quantity AS DOUBLE) * TRY_CAST(unit_value_amount AS DOUBLE) AS monto_total,
    current_timestamp() AS _ingested_at
  FROM compras_publicas_rd.bronze.awards_items
  WHERE unit_value_currency IN ('DOP', 'USD')
    AND TRY_CAST(unit_value_amount AS DOUBLE) > 0
    AND TRY_CAST(quantity AS DOUBLE) IS NOT NULL
    AND id RLIKE '^[0-9]+$'
    AND TRY_CAST(quantity AS DOUBLE) * TRY_CAST(unit_value_amount AS DOUBLE) <= 111619224.18
) AS source
ON target.id = source.id AND target.awards_id = source.awards_id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
WHEN NOT MATCHED BY SOURCE THEN DELETE;

-- 4. awards_suppliers
MERGE INTO compras_publicas_rd.silver.awards_suppliers AS target
USING (
  SELECT 
    id,
    name AS nombre,
    awards_id,
    main_id,
    current_timestamp() AS _ingested_at
  FROM compras_publicas_rd.bronze.awards_suppliers
) AS source
ON target.id = source.id AND target.awards_id = source.awards_id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *
WHEN NOT MATCHED BY SOURCE THEN DELETE;

-- Verificación de conteos post-limpieza
SELECT 'main' as tabla, COUNT(*) as filas FROM compras_publicas_rd.silver.main
UNION ALL
SELECT 'awards', COUNT(*) FROM compras_publicas_rd.silver.awards
UNION ALL
SELECT 'awards_items', COUNT(*) FROM compras_publicas_rd.silver.awards_items
UNION ALL
SELECT 'awards_suppliers', COUNT(*) FROM compras_publicas_rd.silver.awards_suppliers;

-- COMMAND ----------

-- Verificación CON el nuevo filtro de id numérico
SELECT id, awards_id, COUNT(*) as veces
FROM compras_publicas_rd.bronze.awards_items
WHERE unit_value_currency IN ('DOP', 'USD')
  AND TRY_CAST(unit_value_amount AS DOUBLE) > 0
  AND id RLIKE '^[0-9]+$'
GROUP BY id, awards_id
HAVING COUNT(*) > 1
ORDER BY veces DESC
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Sobre este ETL
-- MAGIC
-- MAGIC Aplica la limpieza y tipado definidos en el EDA sobre los datos de Bronze (ya 
-- MAGIC depurados con `DROPMALFORMED`), usando `MERGE` — requisito obligatorio del TP.
-- MAGIC
-- MAGIC **Filtros aplicados:**
-- MAGIC - `main`: fecha dentro de rango razonable (2015–2026)
-- MAGIC - `awards_items`: moneda válida (DOP/USD), monto > 0, cantidad no nula, **y `id` 
-- MAGIC   puramente numérico** (filtro agregado tras detectar un caso residual de corrupción 
-- MAGIC   que `DROPMALFORMED` no capturaba — ver detalle abajo)
-- MAGIC
-- MAGIC **Idempotencia con `MERGE`:** a diferencia de Bronze (`INSERT OVERWRITE`), acá se 
-- MAGIC necesitan las 3 cláusulas del `MERGE` para ser realmente idempotente frente a cambios 
-- MAGIC en el origen:
-- MAGIC ```sql
-- MAGIC WHEN MATCHED THEN UPDATE SET *
-- MAGIC WHEN NOT MATCHED THEN INSERT *
-- MAGIC WHEN NOT MATCHED BY SOURCE THEN DELETE
-- MAGIC ```
-- MAGIC Sin el `DELETE`, filas que dejan de existir en Bronze (por ejemplo, al mejorar un 
-- MAGIC filtro de calidad) quedan "huérfanas" en Silver — se comprobó en la práctica: antes 
-- MAGIC de agregar esta cláusula, Silver tenía 72,128 filas en `main` mientras Bronze ya 
-- MAGIC tenía solo 69,746 tras el fix de calidad.
-- MAGIC
-- MAGIC **Historia de depuración (vale la pena documentarla):**
-- MAGIC 1. Primer intento de `MERGE` falló con `DELTA_MULTIPLE_SOURCE_ROW_MATCHING_TARGET_ROW_IN_MERGE`
-- MAGIC 2. Investigación reveló que comillas dobles sin escapar en campos de texto libre 
-- MAGIC    (`description`) corrompían la columna `id`, generando IDs duplicados/falsos
-- MAGIC 3. Se agregó `mode => 'DROPMALFORMED'` en Bronze — resolvió el problema en `main` y 
-- MAGIC    `awards_suppliers`, pero quedó un caso residual en `awards_items` (10 filas con 
-- MAGIC    el mismo `id` corrupto, forma válida pero contenido incorrecto)
-- MAGIC 4. Se agregó el filtro `id RLIKE '^[0-9]+$'` en Silver para ese caso residual
-- MAGIC 5. Se detectó que el primer `MERGE` (sin `DELETE`) dejaba filas obsoletas — se agregó 
-- MAGIC    `WHEN NOT MATCHED BY SOURCE THEN DELETE`
-- MAGIC 6. **Verificado: 2 corridas consecutivas dan resultados idénticos** 
-- MAGIC    (69,746 / 71,036 / 377,480 / 92,885)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Filtro de outliers (agregado tras revisar el dashboard):** se detectó que ~404 
-- MAGIC filas (~0.1%) tenían montos unitarios absurdamente altos para el tipo de ítem 
-- MAGIC (ej. "papel higiénico" a RD$960,170 por paquete, "licencia de conducir" a 
-- MAGIC RD$3,784 millones) — errores de captura en el sistema de origen, no adjudicaciones 
-- MAGIC reales. Se excluyen los valores por encima del percentil 99.9 (RD$111,619,224), 
-- MAGIC punto donde la distribución presenta un salto abrupto (el máximo original era 416 
-- MAGIC veces mayor a este percentil, evidencia de que esos valores no pertenecen a la 
-- MAGIC misma población de datos).

-- COMMAND ----------

SELECT 
  COUNT(DISTINCT proveedor_sk) as total_proveedores_en_fact,
  SUM(monto_prorrateado) as monto_total_general
FROM compras_publicas_rd.gold.fact_adjudicacion_proveedor;