## Uncomment these lines and set them appropriately.

#PROJECT = <project name>
#TOPLEVEL = <top-level module name>
#CONSTRAINTS = <constraints file name>.ucf
#TARGET_PART = <part name, e.g. xc6slx9-2-tqg144>


## Where are the Xilinx tools installed?

#(Linux) XILINX = /opt/xilinx/14.7/ISE_DS/ISE/bin/lin
#(Windows) XILINX = /cygdrive/c/Xilinx/14.7/ISE_DS/ISE/bin/nt64


## What are your HDL source files? Repeat this line for each file.

#VSOURCE += example.v


## These settings are probably fine for most projects.

COMMON_OPTS = -intstyle xflow
NGDBUILD_OPTS =
MAP_OPTS = -mt 2
PAR_OPTS = -mt 2
TRCE_OPTS = -e
BITGEN_OPTS = -g Compress


###########################################################################

BITFILE = build/$(PROJECT).bit

RUN = @echo -ne "\n\n\e[1;33m======== $(1) ========\e[m\n\n"; \
	cd build && $(XILINX)/$(1)

default: $(BITFILE)

clean:
	rm -rf build

build/$(PROJECT).prj: Makefile
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@$(foreach file,$(VSOURCE),echo "verilog work \"../$(file)\"" >> $@;)

build/$(PROJECT).scr: Makefile
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@echo "run" \
	    "-ifn $(PROJECT).prj" \
	    "-ofn $(PROJECT).ngc" \
	    "-ifmt mixed" \
	    "-top $(TOPLEVEL)" \
	    "-ofmt NGC" \
	    "-p $(TARGET_PART)" \
	    > build/$(PROJECT).scr

$(BITFILE): Makefile $(VSOURCE) $(CONSTRAINTS) build/$(PROJECT).prj build/$(PROJECT).scr
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

## You'll need to write an impact.cmd if you want to use this part.
## A simple one looks like:
##
##    setMode -bscan
##    setCable -p auto
##    addDevice -p 1 -file build/projectname.bit
##    program -p 1
##    quit
##
## You may need to change this rule to something else entirely if your board
## doesn't support Impact.
prog: $(BITFILE)
	$(XILINX)/impact -batch impact.cmd
