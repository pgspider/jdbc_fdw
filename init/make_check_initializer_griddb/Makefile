CC=gcc
IDIR =../griddb/client/c/include
CFLAGS=-I$(IDIR)

ODIR =./obj

LDIR =../griddb/bin
LDLIBS=-lgridstore
LDFLAGS=-L$(LDIR) $(LDLIBS)

_DEPS = gridstore.h
DEPS = $(patsubst %,$(IDIR)/%,$(_DEPS))

_OBJ = griddb_init.o
OBJ = $(patsubst %,$(ODIR)/%,$(_OBJ))

griddb_init: $(OBJ)
	$(CC) -o $@ $^ $(LDFLAGS)

$(ODIR)/%.o: %.c $(DEPS)
	mkdir -p $(ODIR)
	$(CC) -c -o $@ $< $(CFLAGS)

.PHONY: clean

clean:
	rm -f $(OBJ) griddb_init
