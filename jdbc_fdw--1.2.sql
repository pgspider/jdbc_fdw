/* contrib/jdbc_fdw/jdbc_fdw--1.1.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION jdbc_fdw" to load this file. \quit

CREATE OR REPLACE FUNCTION jdbc_fdw_version()
RETURNS pg_catalog.int4 STRICT
AS 'MODULE_PATHNAME' LANGUAGE C;

CREATE FUNCTION jdbc_exec (text, text)
RETURNS setof record
AS 'MODULE_PATHNAME','jdbc_exec'
LANGUAGE C STRICT PARALLEL RESTRICTED;

CREATE FUNCTION jdbc_fdw_handler()
RETURNS fdw_handler
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FUNCTION jdbc_fdw_validator(text[], oid)
RETURNS void
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FOREIGN DATA WRAPPER jdbc_fdw
  HANDLER jdbc_fdw_handler
  VALIDATOR jdbc_fdw_validator;