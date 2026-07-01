# --- Verilator Project Makefile (Pure Verilog TB) ---

# Top-level testbench module name (the one containing the initial block and clock gen)
TB_TOP = checksum_tb

# File Paths based on your directory structure
RTL_SRC = ../RTL/IP/checksum/checksum.v
TB_SRC  = checksum_tb.v

# Verilator Executable and Flags
VERILATOR = verilator
# --binary tells Verilator to build a complete executable straight from Verilog
# -j 0 optimizes compilation by using all available CPU cores
VERILATOR_FLAGS = -Wall --binary --trace -j 0

# Build Directories
BUILD_DIR = obj_dir
EXE_NAME = V$(TB_TOP)

.PHONY: all run compile clean

# Default target: compile and run simulation
all: run

# Run the generated simulation executable
run: compile
	@echo "--------------------------------------------------------"
	@echo "Running Verilator Simulation..."
	@echo "--------------------------------------------------------"
	./$(BUILD_DIR)/$(EXE_NAME)

# Compile code using Verilator
compile: $(BUILD_DIR)/$(EXE_NAME)

$(BUILD_DIR)/$(EXE_NAME): $(RTL_SRC) $(TB_SRC)
	@echo "--------------------------------------------------------"
	@echo "Verilating and Compiling Verilog Testbench..."
	@echo "--------------------------------------------------------"
	$(VERILATOR) $(VERILATOR_FLAGS) $(RTL_SRC) $(TB_SRC) --top-module $(TB_TOP)

# Clean up build artifacts
clean:
	@echo "Cleaning up build directory..."
	rm -rf $(BUILD_DIR)