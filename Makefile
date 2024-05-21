# contrib/jdbc_fdw/Makefile

MODULE_big = jdbc_fdw
OBJS = jdbc_fdw.o option.o deparse.o connection.o jq.o

PG_CPPFLAGS = -I$(libpq_srcdir)
SHLIB_LINK = $(libpq)

EXTENSION = jdbc_fdw
DATA = jdbc_fdw--1.0.sql jdbc_fdw--1.0--1.1.sql jdbc_fdw--1.2.sql

REGRESS = postgresql/new_test postgresql/aggregates postgresql/date postgresql/float8 postgresql/insert postgresql/select postgresql/update postgresql/delete postgresql/float4 postgresql/int4 postgresql/int8 postgresql/ported_postgres_fdw postgresql/exec_function 

JDBC_CONFIG = jdbc_config

LIBDIR=/usr/lib64/

SHLIB_LINK += -L$(LIBDIR) -ljvm

UNAME = $(shell uname)

TRGTS = JAVAFILES

JAVA_SOURCES = \
	$(srcdir)/JDBCUtils.java \
	$(srcdir)/JDBCDriverLoader.java \
	$(srcdir)/JDBCConnection.java \
	$(srcdir)/resultSetInfo.java

PG_CPPFLAGS=-D'PKG_LIB_DIR=$(pkglibdir)' -I$(libpq_srcdir)

JFLAGS = -d $(pkglibdir)

all:$(TRGTS)

JAVAFILES:
	javac $(JFLAGS) $(JAVA_SOURCES)

# the db name is hard-coded in the tests
override USE_MODULE_DB =

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
SHLIB_PREREQS = submake-libpq
subdir = contrib/jdbc_fdw
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif

ifdef REGRESS_PREFIX
REGRESS_PREFIX_SUB = $(REGRESS_PREFIX)
else
REGRESS_PREFIX_SUB = $(VERSION)
endif

REGRESS := $(addprefix $(REGRESS_PREFIX_SUB)/,$(REGRESS))
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/griddb)
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/mysql)
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/postgresql)
