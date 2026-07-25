-- Databricks notebook source
-- DDL: Creación de schemas (bronze, silver, gold)

CREATE SCHEMA IF NOT EXISTS compras_publicas_rd.bronze;
CREATE SCHEMA IF NOT EXISTS compras_publicas_rd.silver;
CREATE SCHEMA IF NOT EXISTS compras_publicas_rd.gold;