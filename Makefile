XILINX = /cygdrive/c/Xilinx/14.4/ISE_DS/ISE/bin/nt64

XST = $(XILINX)/xst
NGDBUILD = $(XILINX)/ngdbuild
MAP = $(XILINX)/map
PAR = $(XILINX)/par
BITGEN = $(XILINX)/bitgen
PERL = perl

DIGILENT_DEVICE_NAME = Nexys2

FPGA_PART = xc3s1200e-fg320-4

BITFILE = blinky.bit
TOPMODULE = toplevel
VSOURCES = toplevel.v
CONSTRAINTS = nexys2.ucf

BITGEN_OPTS += -g UnusedPin:Pullnone
BITGEN_OPTS += -g StartupClk:JtagClk
BITGEN_OPTS += -g Compress

##############################################################################

COMMON_OPTS += -intstyle xflow
RUNNING = echo -e "\n\n\e[1;35m>>>> Running $(1)\e[m"

default: $(BITFILE)

clean:
	rm -rf build/

prog: $(BITFILE)
	djtgcfg -d $(DIGILENT_DEVICE_NAME) -i 0 -f $(BITFILE) prog

build/project.prj: Makefile
	test -d build || mkdir build
	$(PERL) generate_project.pl build/project.prj $(addprefix ../src/,$(VSOURCES))

build/project.scr: Makefile
	test -d build || mkdir build
	$(PERL) generate_script.pl build/project.scr \
	    "-ifn project.prj" \
	    "-ifmt mixed" \
	    "-top $(TOPMODULE)" \
	    "-ofn project.ngc" \
	    "-ofmt NGC" \
	    "-p $(FPGA_PART)"

build/project.ngc: build/project.prj build/project.scr $(addprefix src/,$(VSOURCES))
	@touch build/stamp.ngc ; $(call RUNNING,Xst)
	cd build ; $(XST) $(COMMON_OPTS) $(XST_OPTS) -ifn project.scr
	@test build/project.ngc -nt build/stamp.ngc

build/project.ngd: build/project.ngc src/$(CONSTRAINTS)
	@touch build/stamp.ngd ; $(call RUNNING,ngdbuild)
	cd build ; $(NGDBUILD) $(COMMON_OPTS) $(NGD_OPTS) -p $(FPGA_PART) -uc ../src/$(CONSTRAINTS) project.ngc project.ngd
	@test build/project.ngd -nt build/stamp.ngd

build/project.map.ncd build/project.pcf: build/project.ngd
	@touch build/stamp.map ; $(call RUNNING,map)
	cd build ; $(MAP) $(COMMON_OPTS) $(MAP_OPTS) -p $(FPGA_PART) -o project.map.ncd project.ngd project.pcf
	@test build/project.map.ncd -nt build/stamp.map

build/project.par.ncd: build/project.map.ncd build/project.pcf
	@touch build/stamp.par ; $(call RUNNING,PAR)
	cd build ; $(PAR) $(COMMON_OPTS) $(PAR_OPTS) -w project.map.ncd project.par.ncd project.pcf
	@test build/project.par.ncd -nt build/stamp.par

$(BITFILE): build/project.par.ncd
	@touch build/stamp.bit ; $(call RUNNING,bitgen)
	cd build ; $(BITGEN) $(COMMON_OPTS) $(BITGEN_OPTS) -w project.par.ncd $(BITFILE) && mv $(BITFILE) ..
	@test $(BITFILE) -nt build/stamp.bit

