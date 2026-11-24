BUILD     := build
SNAPSHOTS := snaps
STAMP     := $(BUILD)/.compiled

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

.PHONY: all framebuffer display render clean snapshot snapshot-display snapshot-framebuffer

all: snapshot render

display: $(BUILD)/i2c.hex
framebuffer: $(BUILD)/fb.hex
render: $(BUILD)/fb.jpg $(BUILD)/i2c.jpg
snapshot : snapshot-display snapshot-framebuffer

$(STAMP): $(BUILD)/Font.mif $(SOURCES)
	rm -f $(STAMP)
	mkdir -p $(BUILD)
	cd $(BUILD) && rm -rf work && $(VCOM) $(VCOM_FLAGS) -work work $(SOURCES)
	touch $(STAMP)

$(BUILD)/fb.hex: $(STAMP)
	rm -f $@
	cd $(BUILD) && $(VSIM) $(VSIM_FLAGS) -do "run -all; quit -f" work.Tb_Framebuffer

$(BUILD)/i2c.hex: $(STAMP)
	rm -f $@
	cd $(BUILD) && $(VSIM) $(VSIM_FLAGS) -do "run -all; quit -f" work.Tb_Display_Driver

$(BUILD)/%.jpg: $(BUILD)/%.hex
	python3 render_fb.py $< -o $@
$(BUILD)/Font.mif: ../Font.mif
	mkdir -p $(BUILD)
	cp ../Font.mif $(BUILD)/Font.mif

snapshot-framebuffer : $(BUILD)/fb.hex $(SNAPSHOTS)/fb.hex
	@if cmp -s $^; then                                                      \
		[ -t 1 ] && printf '\e[92mfb.hex good\e[0m\n' || echo 'fb.hex good'; \
	else                                                                     \
		[ -t 1 ] && printf '\e[91mfb.hex bad!\e[0m\n' || echo 'fb.hex bad!'; \
		exit 1;                                                              \
	fi
snapshot-display : $(BUILD)/i2c.hex $(SNAPSHOTS)/i2c.hex
	@if cmp -s $^; then                                                        \
		[ -t 1 ] && printf '\e[92mi2c.hex good\e[0m\n' || echo 'i2c.hex good'; \
	else			                                                           \
		[ -t 1 ] && printf '\e[91mi2c.hex bad!\e[0m\n' || echo 'i2c.hex bad!'; \
		exit 1;                                                                \
	fi

clean:
	rm -rf $(BUILD)
