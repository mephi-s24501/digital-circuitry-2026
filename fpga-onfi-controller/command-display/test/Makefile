BUILD := build
STAMP := $(BUILD)/.compiled

VCOM       ?= vcom
VSIM       ?= vsim
VCOM_FLAGS ?= -2008 -quiet
VSIM_FLAGS ?= -c -quiet

SOURCES := $(abspath                    \
  ../Onfi_Command_Pkg.vhd               \
  ../Onfi_Command_Pkg_Body.vhd          \
  ../Font_Memory.vhd                    \
  ../Framebuffer_Memory.vhd             \
  ../Framebuffer.vhd                    \
  ../i2c_master_flow_mmode_behavior.vhd \
  ../Display_Driver.vhd                 \
  ./Tb_Utils_Pkg.vhd                    \
  ./Framebuffer_Tester.vhd              \
  ./Tb_Framebuffer.vhd                  \
  ./Display_Driver_Tester.vhd           \
  ./Tb_Display_Driver.vhd               \
)

.PHONY: all framebuffer display render clean

all: render

display: $(BUILD)/i2c.hex
framebuffer: $(BUILD)/fb.hex
render: $(BUILD)/fb.jpg $(BUILD)/i2c.jpg

$(STAMP): $(BUILD) $(BUILD)/Font.mif $(SOURCES)
	rm -f $(STAMP)
	cd $(BUILD) && rm -rf work && $(VCOM) $(VCOM_FLAGS) -work work $(SOURCES)
	touch $(STAMP)

$(BUILD)/fb.hex: $(STAMP)
	rm -f $@
	cd $(BUILD) && $(VSIM) $(VSIM_FLAGS) -do "run -all; quit -f" work.Tb_Framebuffer

$(BUILD)/i2c.hex: $(STAMP)
	rm -f $@
	cd $(BUILD) && $(VSIM) $(VSIM_FLAGS) -do "run -all; quit -f" work.Tb_Display_Driver

$(BUILD):
	mkdir -p $(BUILD)
$(BUILD)/%.jpg: $(BUILD)/%.hex
	python3 render_fb.py $< -o $@
$(BUILD)/Font.mif: ../Font.mif
	cp ../Font.mif $(BUILD)/Font.mif

clean:
	rm -rf $(BUILD)
