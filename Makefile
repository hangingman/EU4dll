.PHONY: all test clean hijack run help

.DEFAULT_GOAL := help

help: ## Show this help.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\x1b[36m%-20s\x1b[0m %s\n", $$1, $$2}'

all: ## Build the project using dub.
	dub build

test: ## Run unit tests for the project.
	dub build --build=unittest
	dub test --build=unittest -- --threads=1

clean: ## Clean the project build files.
	dub clean
	rm -f libeu4dll.so
	rm -f *.log

# https://github.com/Ai-Himmel/Linux-so-hijack
# .so file hijack
hijack: ## Build a dummy executable and test .so file hijacking.
	dmd dummy.d -ofdummy

	@echo "--- test exe ---"
	@./dummy
	@echo "----------------"

	dub build
	dub build -c eu4dll-poc
	make -C tests/poc/

#
# EU4にdllをかませて起動、dll.soっておかしいので後で変えたい
#
EU4_DIR := ~/.steam/debian-installation/steamapps/common/Europa\ Universalis\ IV/

run: all ## Copy the built .so to EU4 directory and run EU4 with it.
	@echo "--- copy eu4dll.so ---"
	cp -f ./libeu4dll.so $(EU4_DIR)
	@echo "--- run eu4 ---"
	cd $(EU4_DIR) && LD_PRELOAD=./libeu4dll.so ./eu4
