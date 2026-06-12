ASM_DIR     := asm
OBJ_DIR     := obj
SRC_DIR     := src
DIST_DIR    := dist/web

PYTHON      := python3 # tested with 3.11
ASSEMBLER   := $(ASM_DIR)/asm.py
PASCAL      := fpc  # tested with FPC 3.2
CPP         := g++  # tested with g++ 14
AWK         := gawk # tested with v 5
ZIG         := zig  # expects 0.13.0
BC          := bc   # tested with v 1

# format digits
FMT         := $(AWK) -f format_digits.awk

# location of EDSAC simulator
# tested with edsim by Lee Wittenberg
# https://computerconservationsociety.org/emu/edsac/index.htm

# also tested with EDSAC-Emulator by Andrew Herbert (based on edsim)
# https://github.com/andrewjherbert/EDSAC-Emulator

# EDSIM_PATH should contain "punch", "edsac" and "tprint" executables
EDSIM_PATH  := ./edsim

ZIGSAC_PATH := ./zigsac
ZIGSAC_OPT := -Doptimize=ReleaseFast

ZIGSAC_SRC := $(ZIGSAC_PATH)/src/edsac.zig $(ZIGSAC_PATH)/src/main.zig
ZIGSAC_BIN := $(ZIGSAC_PATH)/zig-out/bin/zigsac
$(ZIGSAC_BIN): $(ZIGSAC_SRC)
	cd $(ZIGSAC_PATH) && zig build $(ZIGSAC_OPT)

ZIGSAC_WASM_SRC := $(ZIGSAC_PATH)/src/edsac.zig $(ZIGSAC_PATH)/src/wasm.zig
ZIGSAC_WASM := $(ZIGSAC_PATH)/web/zigsac.wasm
$(ZIGSAC_WASM): $(ZIGSAC_WASM_SRC)
	cd $(ZIGSAC_PATH) && zig build wasm

ASM_SOURCES := $(wildcard $(SRC_DIR)/*.asm)
OBJECTS := $(patsubst $(SRC_DIR)/%.asm,$(OBJ_DIR)/%.e1,$(ASM_SOURCES))

.DEFAULT_GOAL := all

.PHONY: all clean run help logic_check check_pas check_cpp web

# assemble .asm file to .e1
$(OBJ_DIR)/%.e1: $(SRC_DIR)/%.asm $(ASSEMBLER) | $(OBJ_DIR)
	@$(PYTHON) $(ASSEMBLER) -a $< -o $@

# create obj directory if it doesn't exist
$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

# usage: make format_zigsac PROG=pi_tank
PROG ?= pi_tank

# run PROG with reference check and formatting
format_zigsac: $(OBJ_DIR)/$(PROG).e1 | $(ZIGSAC_BIN)
	$(ZIGSAC_BIN) < $< | $(PYTHON) spigot_reference.py | $(FMT) | cat -b

format_edsim: $(OBJ_DIR)/$(PROG).e1
	@$(EDSIM_PATH)/punch $< | $(EDSIM_PATH)/edsac | $(EDSIM_PATH)/tprint | $(PYTHON) spigot_reference.py | $(FMT) | cat -b

# run PROG without processing output
run_zigsac: $(OBJ_DIR)/$(PROG).e1 | $(ZIGSAC_BIN)
	@$(ZIGSAC_BIN) < $<

run_edsim: $(OBJ_DIR)/$(PROG).e1
	@$(EDSIM_PATH)/punch $< | $(EDSIM_PATH)/edsac | $(EDSIM_PATH)/tprint


# compare bc digits with spigot_reference.py digits
reference_bc:
	@echo
	@echo "scale=2502; 4*a(1)" | bc -l | $(PYTHON) spigot_reference.py | $(FMT) | cat -b

# endless stream of digits produced by awk, checked with python and formatted by awk
spigot_awk:
	@$(AWK) -M -f spigot.awk  | $(PYTHON) spigot_reference.py | $(FMT) | cat -b

spigot_pas: spigot.pas
	$(PASCAL) -XMPi_Spigot -o$@ $<

spigot_cpp: spigot.cpp
	$(CPP) -o $@ $<

check_pas: spigot_pas
	@./spigot_pas | cut -c 2- | $(PYTHON) spigot_reference.py | $(FMT) | cat -b

check_cpp: spigot_cpp
	@./spigot_cpp 3001 5 | $(PYTHON)  spigot_reference.py  | $(FMT) | cat -b


web: $(ZIGSAC_WASM)
	rm -rf $(DIST_DIR)
	cp -r zigsac/web $(DIST_DIR)
	cp $(ASM_DIR)/asm.py $(DIST_DIR)/asm.py
	mkdir -p $(DIST_DIR)/asm
	cp $(SRC_DIR)/pi*.asm $(DIST_DIR)/asm/
	cp favicon.png $(DIST_DIR)


clean:
	rm -rf spigot.o spigot_pas spigot_cpp $(DIST_DIR)
