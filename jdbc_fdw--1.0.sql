/* contrib/jdbc_fdw/jdbc_fdw--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION jdbc_fdw" to load this file. \quit

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
