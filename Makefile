CC      := g++
ECHO    := echo
RM      := rm
CD      := cd
TAR     := tar

BUILD_DIR := build

OUTDIR := $(BUILD_DIR)
CFLAGS  := -W -Wall -std=c++11
DEBUG   ?= 0
ifeq ($(DEBUG), 1)
	OUTDIR := $(OUTDIR)/Debug
	CFLAGS += -g -DDEBUG
else
	OUTDIR := $(OUTDIR)/Release
	CFLAGS += -O2
endif
OBJDIR := $(OUTDIR)/obj

LIBS   := -lz 

EXE_SRC := dmf.cpp datareader.cpp pce.cpp pcewriter.cpp main.cpp
OBJS    := $(EXE_SRC:.cpp=.o)
EXE_OBJ := $(addprefix $(OBJDIR)/, $(OBJS))
EXE     := $(OUTDIR)/dmfread

DEPEND = .depend

all: $(EXE)

dep: $(DEPEND)

$(DEPEND):
	@$(ECHO) "  MKDEP"
	@$(CC) -MM -MG $(CFLAGS) $(EXE_SRC) > $(DEPEND)

$(EXE): $(EXE_OBJ)
	@$(ECHO) "  LD        $@"
	@$(CC) -o $(EXE) $^ $(LIBS)

$(OBJDIR)/%.o: %.cpp
	@$(ECHO) "  CC        $@"
	@$(CC) $(CFLAGS) -c -o $@ $<

$(EXE_OBJ): | $(OBJDIR) $(OUTDIR)

$(OUTDIR):
	@mkdir  -p $(OUTDIR)

$(OBJDIR):
	@mkdir  -p $(OBJDIR)

install:

clean: FORCE
	@$(ECHO) "  CLEAN     object files"
	@find $(BUILD_DIR) -name "*.o" -exec $(RM) -f {} \;

realclean: clean
	@$(ECHO) "  CLEAN     $(EXE)"
	@$(RM) -f $(EXE)
	@$(ECHO) "  CLEAN     noise files"
	@$(RM) -f `find . -name "*~" -o -name "\#*"`

c: clean

rc: realclean

FORCE :
ifeq (.depend,$(wildcard .depend))
include .depend
endif
