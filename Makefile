ASM_DIR     := asm
OBJ_DIR     := obj
SRC_DIR     := src

PYTHON      := python3
ASSEMBLER   := $(ASM_DIR)/asm.py
PASCAL      := fpc
CPP			:= g++

# location of EDSAC emulator
# tested with edsim by Lee Wittenberg
# https://computerconservationsociety.org/emu/edsac/index.htm
# EDSAC-Emulator by Andrew Herbert (based on the above)
# https://github.com/andrewjherbert/EDSAC-Emulator
# path should contain punch, edsac and tprint executables
EDSIM_PATH  :=

ASM_SOURCES := $(wildcard $(SRC_DIR)/*.asm)
OBJECTS := $(patsubst $(SRC_DIR)/%.asm,$(OBJ_DIR)/%.e,$(ASM_SOURCES))

.DEFAULT_GOAL := all

.PHONY: all clean run_mem help logic_check check_pas check_cpp

all: $(OBJECTS) run_mem

# pattern rule: compile any .asm file to .e
$(OBJ_DIR)/%.e: $(SRC_DIR)/%.asm $(ASSEMBLER) | $(OBJ_DIR)
	@$(PYTHON) $(ASSEMBLER) -a $< -o $@

# create obj directory if it doesn't exist
$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

# usage: make run PROG=pi_mem
PROG ?= pi_mem
run_mem: $(OBJ_DIR)/$(PROG).e
	$(EDSIM_PATH)punch $< | $(EDSIM_PATH)edsac | $(EDSIM_PATH)tprint | tail -n1 | $(PYTHON) spigot_reference.py | $(PYTHON) format_digits.py | cat -b

# validate checking logic with known-good digits
# "make self_check_check | grep X" should be empty
self_check_check: digits_pi.txt spigot_reference.py format_digits.py
	@cat digits_pi.txt | $(PYTHON) spigot_reference.py | $(PYTHON) format_digits.py | cat -b

logic_check: spigot_edsac.py spigot_reference.py format_digits.py
	@$(PYTHON) spigot_edsac.py | $(PYTHON) spigot_reference.py  | $(PYTHON) format_digits.py | cat -b

spigot_pas: spigot.pas
	$(PASCAL) -XMPi_Spigot -o$@ $<

spigot_cpp: spigot.cpp
	$(CPP) -o $@ $<

check_pas: spigot_pas
	@./spigot_pas | cut -c 2- | $(PYTHON) spigot_reference.py | $(PYTHON) format_digits.py | cat -b

check_cpp: spigot_cpp
	@./spigot_cpp 3001 5 | $(PYTHON)  spigot_reference.py  | $(PYTHON)  format_digits.py | cat -b

clean:
	rm -rf $(OBJ_DIR)/*.e spigot.o spigot_pas spigot_cpp

help:
	@echo "Last Orders Pi - Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all         - Build all assembly files (default)"
	@echo "  pi_mem      - Build obj/pi_mem.e"
	@echo "  run         - Run EDSAC with PROG (default: pi2)"
	@echo "              Usage: make run PROG=pi3"
	@echo "  clean       - Remove build artifacts"
	@echo "  help        - Show this help message"
