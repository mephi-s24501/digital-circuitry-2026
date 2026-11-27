BUILD     := build
SNAPSHOTS := snaps
STAMP     := $(BUILD)/.compiled

DISPLAY_HEX := i2c.hex i2c_pgup.hex i2c_pgdown1.hex i2c_pgdown2.hex

VCOM       ?= vcom
VSIM       ?= vsim
VCOM_FLAGS ?= -2008 -quiet
VSIM_FLAGS ?= -c -quiet

SOURCES := $(abspath                       \
  ../Command_Display_Pkg.vhd               \
  ../ip/Font_Memory.vhd                    \
  ../ip/Framebuffer_Memory.vhd             \
  ../Framebuffer.vhd                       \
  ../ip/i2c_master_flow_mmode_behavior.vhd \
  ../Display_Driver.vhd                    \
  ./Tb_Utils_Pkg.vhd                       \
  ./Framebuffer_Tester.vhd                 \
  ./Tb_Framebuffer.vhd                     \
  ./Display_Driver_Tester.vhd              \
  ./Tb_Display_Driver.vhd                  \
)

.PHONY: all framebuffer display render clean snapshot snapshot-update snapshot-display snapshot-framebuffer

all: snapshot render

display: $(addprefix $(BUILD)/,$(DISPLAY_HEX))
framebuffer: $(BUILD)/fb.hex
render: $(BUILD)/fb.jpg $(addprefix $(BUILD)/,$(DISPLAY_HEX:.hex=.jpg))
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
	rm -f $(addprefix $(BUILD)/,$(DISPLAY_HEX))
	cd $(BUILD) && $(VSIM) $(VSIM_FLAGS) -do "run -all; quit -f" work.Tb_Display_Driver

# Produced by the same simulation run that writes i2c.hex.
$(BUILD)/i2c_pgup.hex $(BUILD)/i2c_pgdown1.hex $(BUILD)/i2c_pgdown2.hex: $(BUILD)/i2c.hex

$(BUILD)/%.jpg: $(BUILD)/%.hex
	python3 render_fb.py $< -o $@
$(BUILD)/Font.mif: ../Font.mif
	mkdir -p $(BUILD)
	cp ../Font.mif $(BUILD)/Font.mif

# check_file - Do a snapshot test on $(1), invoking $(2) on fail
define check_file
	if cmp -s "$(BUILD)/$(1)" "$(SNAPSHOTS)/$(1)"; then                       \
		[ -t 1 ] && printf '\e[92m%s good\e[0m\n' "$(1)" || echo "$(1) good"; \
	else                                                                      \
		[ -t 1 ] && printf '\e[91m%s bad!\e[0m\n' "$(1)" || echo "$(1) bad!"; \
		$(2);                                                                 \
	fi
endef

snapshot-framebuffer : $(BUILD)/fb.hex $(SNAPSHOTS)/fb.hex
	@$(call check_file,fb.hex,exit 1)
snapshot-display : $(addprefix $(BUILD)/,$(DISPLAY_HEX)) $(addprefix $(SNAPSHOTS)/,$(DISPLAY_HEX))
	@ok=1;                          \
	for f in $(DISPLAY_HEX); do     \
		$(call check_file,$$f,ok=0) \
	done;                           \
	[ $$ok -eq 1 ]

clean:
	rm -rf $(BUILD)
