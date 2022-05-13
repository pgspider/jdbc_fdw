/* contrib/jdbc_fdw/jdbc_fdw--1.0-1.1.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION jdbc_fdw" to load this file. \quit

CREATE OR REPLACE FUNCTION jdbc_fdw_version()
  RETURNS pg_catalog.int4 STRICT
  AS 'MODULE_PATHNAME' LANGUAGE C;

