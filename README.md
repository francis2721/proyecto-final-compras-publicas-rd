# Concentración de Proveedores en Compras Públicas de RD

Pipeline de datos end-to-end en Databricks que analiza la concentración de 
proveedores en las contrataciones públicas de República Dominicana, construido 
como Trabajo Práctico Final del bootcamp "De Cero a Data Engineer — Databricks 
SQL" (instructor: Luciano Argolo).

## Pregunta de negocio

¿Existe concentración de contratos en pocos proveedores? ¿Qué porcentaje del 
monto total adjudicado se llevan los proveedores más grandes?

## Fuente de datos

Dataset OCDS (Open Contracting Data Standard), publicado por Open Contracting 
Partnership en base a datos de la Dirección General de Contrataciones Públicas 
(DGCP) de República Dominicana.

- Fuente: https://data.open-contracting.org/es/publication/22
- Año: 2025 (año calendario completo)
- Archivos usados: `main.csv`, `awards.csv`, `awards_items.csv`, `awards_suppliers.csv`

## Arquitectura

Arquitectura Medallion (Bronze → Silver → Gold) en Databricks:

- **Bronze**: ingesta cruda de los 4 CSV, con metadata de trazabilidad 
  (`_source`, `_ingested_at`), usando `mode => 'DROPMALFORMED'` para descartar 
  filas con corrupción de formato (ver `docs/decisiones_tecnicas.md`)
- **Silver**: limpieza y tipado (`TRY_CAST`), filtros de calidad de datos, 
  deduplicación
- **Gold**: modelo dimensional (Star Schema) — ver diagrama abajo

Ver diagrama completo en `docs/diagrama_arquitectura.png`.

## Modelo dimensional

**Grano de la fact table**: 1 fila = 1 combinación única de adjudicación + 
proveedor. Cuando una adjudicación tiene varios proveedores (consorcio), el 
monto se prorratea entre ellos.

- `fact_adjudicacion_proveedor`: métricas (monto_total_adjudicacion, 
  monto_prorrateado, cantidad_proveedores, cantidad_items) + FKs a las 3 dims
- `dim_proveedor`, `dim_comprador`, `dim_tiempo`

## Pipeline y orquestación

Workflow `pipeline_compras_publicas_rd` en Databricks Jobs: 10 tareas (DDLs → 
Bronze → Silver → 3 dimensiones en paralelo → Fact), con schedule semanal 
(viernes 12pm) y alerta por email ante fallos.

**Idempotencia**: Bronze usa `INSERT OVERWRITE`; Silver y Gold usan `MERGE` con 
`WHEN NOT MATCHED BY SOURCE THEN DELETE`, verificado con corridas dobles 
consecutivas dando resultados idénticos.

## Dashboard

Power BI, conectado a las tablas Gold vía SQL Warehouse. 6 KPIs:

1. Top 15 proveedores por monto adjudicado
2. % del gasto concentrado en el Top 10 de proveedores
3. Cantidad de proveedores necesarios para alcanzar el 80% del gasto (Pareto)
4. Evolución mensual del monto adjudicado
5. Top 10 instituciones compradoras por monto
6. % de adjudicaciones con más de un proveedor (consorcios)

Filtro interactivo: institución compradora.

## Estructura del repositorio

notebooks/
├── 00_EDA/ → Análisis exploratorio documentado
├── 01_DDL/ → Creación de schemas y tablas
├── 02_Bronze/ → ETL de ingesta
├── 03_Silver/ → ETL de limpieza
└── 04_Gold/ → ETL de dimensiones y fact table
docs/
├── diagrama_arquitectura.png
└── decisiones_tecnicas.md

## Autor

Francis De La Rosa Del Rosario — Economista y Data Engineer en formación
