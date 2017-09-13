###########################################################################
## Xilinx ISE Makefile
##
## To the extent possible under law, the author(s) have dedicated all copyright
## and related and neighboring rights to this software to the public domain
## worldwide. This software is distributed without any warranty.
###########################################################################

include project.cfg


###########################################################################
# Default values
###########################################################################

ifndef XILINX
    $(error XILINX must be defined)
endif

ifndef PROJECT
    $(error PROJECT must be defined)
endif

ifndef TARGET_PART
    $(error TARGET_PART must be defined)
endif

TOPLEVEL        ?= $(PROJECT)
CONSTRAINTS     ?= $(PROJECT).ucf
BITFILE         ?= build/$(PROJECT).bit

COMMON_OPTS     ?= -intstyle xflow
XST_OPTS        ?=
NGDBUILD_OPTS   ?=
MAP_OPTS        ?=
PAR_OPTS        ?=
BITGEN_OPTS     ?=
TRACE_OPTS      ?=
FUSE_OPTS       ?= -incremental

PROGRAMMER      ?= none

IMPACT_OPTS     ?= -batch impact.cmd

DJTG_EXE        ?= djtgcfg
DJTG_DEVICE     ?= DJTG_DEVICE-NOT-SET
DJTG_INDEX      ?= 0

XC3SPROG_EXE    ?= xc3sprog
XC3SPROG_CABLE  ?= none
XC3SPROG_OPTS   ?=


###########################################################################
# Internal variables, platform-specific definitions, and macros
###########################################################################

ifeq ($(OS),Windows_NT)
    XILINX := $(shell cygpath -m $(XILINX))
    CYG_XILINX := $(shell cygpath $(XILINX))
    EXE := .exe
    XILINX_PLATFORM ?= nt64
    PATH := $(PATH):$(CYG_XILINX)/bin/$(XILINX_PLATFORM)
else
    EXE :=
    XILINX_PLATFORM ?= lin64
    PATH := $(PATH):$(XILINX)/bin/$(XILINX_PLATFORM)
endif

TEST_NAMES = $(foreach file,$(VTEST) $(VHDTEST),$(basename $(file)))
TEST_EXES = $(foreach test,$(TEST_NAMES),build/isim_$(test)$(EXE))

RUN = @echo -ne "\n\n\e[1;33m======== $(1) ========\e[m\n\n"; \
	cd build && $(XILINX)/bin/$(XILINX_PLATFORM)/$(1)

# isim executables don't work without this
export XILINX


###########################################################################
# Default build
###########################################################################

default: $(BITFILE)

clean:
	rm -rf build

build/$(PROJECT).prj: project.cfg
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@$(foreach file,$(VSOURCE),echo "verilog work \"../$(file)\"" >> $@;)
	@$(foreach file,$(VHDSOURCE),echo "vhdl work \"../$(file)\"" >> $@;)

build/$(PROJECT)_sim.prj: build/$(PROJECT).prj
	@cp build/$(PROJECT).prj $@
	@$(foreach file,$(VTEST),echo "verilog work \"../$(file)\"" >> $@;)
	@$(foreach file,$(VHDTEST),echo "vhdl work \"../$(file)\"" >> $@;)
	@echo "verilog work $(XILINX)/verilog/src/glbl.v" >> $@

build/$(PROJECT).scr: project.cfg
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@echo "run" \
	    "-ifn $(PROJECT).prj" \
	    "-ofn $(PROJECT).ngc" \
	    "-ifmt mixed" \
	    "$(XST_OPTS)" \
	    "-top $(TOPLEVEL)" \
	    "-ofmt NGC" \
	    "-p $(TARGET_PART)" \
	    > build/$(PROJECT).scr

$(BITFILE): project.cfg $(VSOURCE) $(CONSTRAINTS) build/$(PROJECT).prj build/$(PROJECT).scr
	@mkdir -p build
	$(call RUN,xst) $(COMMON_OPTS) \
	    -ifn $(PROJECT).scr
	$(call RUN,ngdbuild) $(COMMON_OPTS) $(NGDBUILD_OPTS) \
	    -p $(TARGET_PART) -uc ../$(CONSTRAINTS) \
	    $(PROJECT).ngc $(PROJECT).ngd
	$(call RUN,map) $(COMMON_OPTS) $(MAP_OPTS) \
	    -p $(TARGET_PART) \
	    -w $(PROJECT).ngd -o $(PROJECT).map.ncd $(PROJECT).pcf
	$(call RUN,par) $(COMMON_OPTS) $(PAR_OPTS) \
	    -w $(PROJECT).map.ncd $(PROJECT).ncd $(PROJECT).pcf
	$(call RUN,bitgen) $(COMMON_OPTS) $(BITGEN_OPTS) \
	    -w $(PROJECT).ncd $(PROJECT).bit
	@echo -ne "\e[1;32m======== OK ========\e[m\n"


###########################################################################
# Testing (work in progress)
###########################################################################

trace: project.cfg $(BITFILE)
	$(call RUN,trce) $(COMMON_OPTS) $(TRACE_OPTS) \
	    $(PROJECT).ncd $(PROJECT).pcf

test: $(TEST_EXES)

build/isim_%$(EXE): build/$(PROJECT)_sim.prj $(VSOURCE) $(VHDSOURCE) $(VTEST) $(VHDTEST)
	$(call RUN,fuse) $(COMMON_OPTS) $(FUSE_OPTS) \
	    -prj $(PROJECT)_sim.prj \
	    -o isim_$*$(EXE) \
	    work.$* work.glbl

isim: build/isim_$(TB)$(EXE)
	@grep --no-filename --no-messages 'ISIM:' $(TB).{v,vhd} | cut -d: -f2 > build/isim_$(TB).cmd
	@echo "run all" >> build/isim_$(TB).cmd
	cd build ; ./isim_$(TB)$(EXE) -tclbatch isim_$(TB).cmd

isimgui: build/isim_$(TB)$(EXE)
	@grep --no-filename --no-messages 'ISIM:' $(TB).{v,vhd} | cut -d: -f2 > build/isim_$(TB).cmd
	@echo "run all" >> build/isim_$(TB).cmd
	cd build ; ./isim_$(TB)$(EXE) -gui -tclbatch isim_$(TB).cmd


###########################################################################
# Programming
###########################################################################

ifeq ($(PROGRAMMER), impact)
prog: $(BITFILE)
	$(XILINX)/bin/$(XILINX_PLATFORM)/impact $(IMPACT_OPTS)
endif

ifeq ($(PROGRAMMER), digilent)
prog: $(BITFILE)
	$(DJTG_EXE) prog -d $(DJTG_DEVICE) -i $(DJTG_INDEX) -f $(BITFILE)
endif

ifeq ($(PROGRAMMER), xc3sprog)
prog: $(BITFILE)
	$(XC3SPROG_EXE) -c $(XC3SPROG_CABLE) $(XC3SPROG_OPTS) $(BITFILE)
endif

ifeq ($(PROGRAMMER), none)
prog:
	$(error PROGRAMMER must be set to use 'make prog')
endif


###########################################################################

# vim: set filetype=make: #
