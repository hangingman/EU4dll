.PHONY: all test clean hijack run help

.DEFAULT_GOAL := help

help: ## Show this help.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\x1b[36m%-20s\x1b[0m %s\n", $$1, $$2}'

all: ## Build the project using dub.
	dub build --compiler=ldc2

test: ## Run unit tests for the project.
	dub build --build=unittest --compiler=ldc2
	dub test --build=unittest --compiler=ldc2 -- --threads=1

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

	dub build --compiler=ldc2
	rm -f tests/poc/{*.o,*.so}
	dub build -c eu4dll-poc
	make -C tests/poc/

#
# EU4にdllをかませて起動、dll.soっておかしいので後で変えたい
#
EU4_DIR := ~/.steam/debian-installation/steamapps/common/Europa\ Universalis\ IV/

run: ## Copy the built .so to EU4 directory and run EU4 with it.
	dub build --force --compiler=ldc2
	@echo "--- clean eu4jps.log ---"
	rm -f $(HOME)/.steam/debian-installation/steamapps/common/pattern_eu4jps.log
	@echo "--- copy eu4dll.so ---"
	cp -f ./libeu4dll.so $(EU4_DIR)
	@echo "--- run eu4 ---"
	cd $(EU4_DIR) && LD_PRELOAD=./libeu4dll.so ./eu4

MOD_DIR := $(HOME)/.local/share/Paradox Interactive/Europa Universalis IV/mod

deploy_translations: ## Copy generated translation files to the EU4 mod directory.
	@echo "Deploying YAML translation files..."
	@SOURCE_DIR="submodules/EU4JPModAppendixI/source/localisation"; \
	DEST_DIR="$(MOD_DIR)/eu4dll_translations/localisation"; \
	echo "Source: $${SOURCE_DIR}"; \
	echo "Destination: $${DEST_DIR}"; \
	if [ ! -d "$${SOURCE_DIR}" ]; then \
		echo "Error: Source directory $${SOURCE_DIR} not found."; \
		echo "Please run the main.py script in the EU4JPModAppendixI submodule first, or ensure the files are present."; \
		exit 1; \
	fi; \
	mkdir -p "$${DEST_DIR}"; \
	cp -v "$${SOURCE_DIR}"/*.yml "$${DEST_DIR}"/; \
	echo "Deployment complete. Files are assumed to be in UTF-8."
