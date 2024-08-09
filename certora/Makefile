default: help

MUNGED_DIR    = ./munged
CONTRACTS_DIR = ../contracts/src

help:
	@echo "usage:"
	@echo "  make clean:  remove all generated files (those ignored by git)"
	@echo "  make $(MUNGED_DIR): create $(MUNGED_DIR) directory by applying the patch file to $(CONTRACTS_DIR)"

munge:
	mkdir -p $(MUNGED_DIR)

clean:
	git clean -fdX
	touch $(PATCH)
