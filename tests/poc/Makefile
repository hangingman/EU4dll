ROOT := ../..
POC_SO := libeu4dll-poc.so

.PHONY: all build run clean

all: build run

build:
	dub --root=$(ROOT) build -c eu4dll-poc --compiler=ldc2
	dmd ./dummy.d -ofdummy

run:
	@echo "--- test exe ---"
	@./dummy
	@echo "----------------"

	@echo "--- hijack ---"
	@LD_PRELOAD=./$(POC_SO) ./dummy
	@echo "----------------"

clean:
	rm -f dummy $(POC_SO)
