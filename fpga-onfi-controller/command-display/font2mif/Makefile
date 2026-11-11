ifeq (,$(i))
$(error Provide i=)
endif

i_name = $(basename $(i))

.PHONY: all
all: Font.mif

Font.mif : $(i_name).raw convert.py header.txt
	python3 ./convert.py -i "$<" -o "$@"

$(i_name).raw : $(i)
	monobit-convert "$<" to "$@" -overwrite
