#!/bin/bash
#
# test_generator.sh
# Reads 'test_inputs.txt' and generates a single 'golden_data.txt'
# file for the Verilog testbench to parse and test with.
#

INPUT_FILE="test_inputs.txt"
OUTPUT_FILE="golden_data.txt"
DRAW_FILE="draw.txt"
DUMP_FILE="vsDump.txt"
CONTROLLER="../controller"

echo "Compiling C++ model..."
cd .. && make && cd -
if [ $? -ne 0 ]; then
    echo "ERROR: 'make' failed"
    exit 1
fi
if [ ! -f "$CONTROLLER" ]; then
    echo "ERROR: '$CONTROLLER' not found after 'make'"
    exit 1
fi

echo "Start generating golden data..."
> "$OUTPUT_FILE"

echo "clear" > "$DRAW_FILE"
echo "line 20 20 25 20 255" >> "$DRAW_FILE"

while read -r line_params || [[ -n "$line_params" ]]; do
    if [ -z "$line_params" ]; then continue; fi

    # Example (temporary) input:
    # clear
    # gameoflife 255 0
    # dump
    # quit
    echo "Processing test: $line_params"
    echo "gameoflife $line_params" >> "$DRAW_FILE"
    echo "dump" >> "$DRAW_FILE"
    echo "quit" >> "$DRAW_FILE" 

    "$CONTROLLER" < "$DRAW_FILE"
    
    # Example output:
    # START
    # 255 0
    # 20 20 22
    # ...
    # 30 20 22
    # END
    #
    # START
    # ...
    # END
    echo "START" >> "$OUTPUT_FILE"
    echo "$line_params" >> "$OUTPUT_FILE"
    cat "$DUMP_FILE" >> "$OUTPUT_FILE"
    echo "END" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

done < "$INPUT_FILE"

# rm "$DRAW_FILE"
rm "$DUMP_FILE"

echo "Done! '$OUTPUT_FILE' generated successfully :D"