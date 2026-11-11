import argparse
import textwrap

ap = argparse.ArgumentParser()
ap.add_argument("-i", "--input", required=True, help="Input file")
ap.add_argument("-o", "--output", required=True, help="Output file")
args = ap.parse_args()

class Data:
    def __init__(self, fname: str) -> None:
        with open(fname, 'rb') as input_file:
            self.data = input_file.read()
    def __getitem__(self, i: int) -> bytes:
        return self.data[i*12 : (i+1)*12]
data = Data(str(args.input))

font_name = str(args.input).removesuffix(".raw")

def print_header(f):
    try:
        with open("header.txt", 'r') as header_file:
            header = header_file.readlines()
    except FileNotFoundError:
        print("warning: header.txt not found")
        return
    for line in header:
        print("--", line.replace("%F", font_name), file=f, end="")
    print(file=f)

WIDTH = 108
DEPTH = 64

with open(str(args.output), 'w') as out:
    print_header(out)
    print(textwrap.dedent(f"""\
                          {WIDTH=};
                          {DEPTH=};
                          ADDRESS_RADIX=HEX;
                          DATA_RADIX=BIN;

                          CONTENT BEGIN
                          """), file=out)
    for addr, i in enumerate([*range(ord('A'), ord('Z')+1),
                              *range(ord('a'), ord('z')+1),
                              *range(ord('0'), ord('9')+1)]):
        slice = data[i - 31] # because we don't have glyphs for 0x01:0x1f in the raw file
        print(f"\t-- {chr(i)}", file=out)
        print(f"\t{addr:02X} : {int.from_bytes(slice, "little"):0{WIDTH}b};", file=out)
        print(file=out)
    print(f"\t[{addr+1:02X}..{DEPTH-1:02X}] : 0;", file=out)
    print("END;", file=out)

"""
For printing 16-bit wide words

for p in range(0, len(slice), 2):
    msb, lsb = slice[p], slice[p+1]
    print(f"\t{addr:02X} : {msb:08b}{lsb:08b};", file=out)
"""
