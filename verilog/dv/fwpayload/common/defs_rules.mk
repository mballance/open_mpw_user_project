
COMMON_DIR    := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

ifneq (1,$(RULES))
RTL_DIR       := $(abspath $(COMMON_DIR)/../../../rtl)
GL_DIR        := $(abspath $(COMMON_DIR)/../../../gl)
PACKAGES_DIR  := $(abspath $(COMMON_DIR)/../../../../packages)
FIRMWARE_PATH := $(abspath $(COMMON_DIR)/../../caravel)
SIM ?= icarus
SIMTYPE ?= functional
TIMEOUT ?= 1ms


PYBFMS_MODULES += wishbone_bfms logic_analyzer_bfms
VLSIM_CLKSPEC += -clkspec clk=10ns

#TOP_MODULE ?= fwpayload_tb
#TB_SRCS ?= $(COMMON_DIR)/sv/fwpayload_tb.sv

PYTHONPATH := $(COMMON_DIR)/python:$(PYTHONPATH)
export PYTHONPATH

PATH := $(PACKAGES_DIR)/python/bin:$(PATH)
export PATH

#********************************************************************
#* Source setup
#********************************************************************
FWRISC_SRCS = $(wildcard $(RTL_DIR)/fwpayload/fwrisc/rtl/*.sv)
INCDIRS += $(RTL_DIR)/fwpayload/fwrisc/rtl
ifeq (gate,$(SIMTYPE))
INCDIRS += $(GL_DIR)
else
INCDIRS += $(RTL_DIR)/fwpayload/fwprotocol-defs/src/sv
endif

DEFINES += MPRJ_IO_PADS=38

ifeq (gate,$(SIMTYPE))
INCDIRS += $(PDK_ROOT)/sky130A

ifneq (fullchip,$(SIMLEVEL))
SRCS += $(GL_DIR)/user_proj_example.v

SRCS += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_io/verilog/sky130_fd_io.v
SRCS += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_io/verilog/sky130_ef_io.v
SRCS += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
SRCS += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
SRCS += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hvl/verilog/primitives.v
SRCS += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hvl/verilog/sky130_fd_sc_hvl.v
endif

DEFINES += FUNCTIONAL USE_POWER_PINS UNIT_DELAY='\#1'
else
ifneq (fullchip,$(SIMLEVEL))
SRCS += $(RTL_DIR)/fwpayload/user_proj_example.v
endif
SRCS += $(RTL_DIR)/fwpayload/fwpayload.v
SRCS += $(RTL_DIR)/fwpayload/fw-wishbone-bridges/verilog/rtl/wb_clockdomain_bridge.v
SRCS += $(RTL_DIR)/fwpayload/fw-wishbone-interconnect/verilog/rtl/wb_interconnect_NxN.v
SRCS += $(RTL_DIR)/fwpayload/fw-wishbone-interconnect/verilog/rtl/wb_interconnect_arb.v
SRCS += $(RTL_DIR)/fwpayload/spram_32x256.sv
SRCS += $(RTL_DIR)/fwpayload/spram_32x512.sv
SRCS += $(RTL_DIR)/fwpayload/spram.v
ifneq (fullchip,$(SIMLEVEL))
SRCS += $(RTL_DIR)/fwpayload/simple_spi_master.v
SRCS += $(RTL_DIR)/fwpayload/simpleuart.v
endif
SRCS += $(FWRISC_SRCS) 
endif
SRCS += $(TB_SRCS)

include $(COMMON_DIR)/$(SIM).mk

else # Rules

clean ::
	rm -f results.xml *.hex


%.elf: %.c $(FIRMWARE_PATH)/sections.lds $(FIRMWARE_PATH)/start.s
	riscv32-unknown-elf-gcc -march=rv32imc -I$(FIRMWARE_PATH) -mabi=ilp32 -Wl,-Bstatic,-T,$(FIRMWARE_PATH)/sections.lds,--strip-debug -ffreestanding -nostdlib -o $@ $(FIRMWARE_PATH)/start.s $<

%.hex: %.elf
	riscv32-unknown-elf-objcopy -O verilog $< $@ 
	# to fix flash base address
	sed -i 's/@10000000/@00000000/g' $@

%.bin: %.elf
	riscv32-unknown-elf-objcopy -O binary $< /dev/stdout | tail -c +1048577 > $@

include $(COMMON_DIR)/$(SIM).mk
include $(wildcard $(COMMON_DIR)/*_clean.mk)

endif
