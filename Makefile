all:
	dub build

test:
	dub build --build=unittest
	dub test --build=unittest -- --threads=1

clean:
	dub clean

# https://github.com/Ai-Himmel/Linux-so-hijack
# .so file hijack
hijack:
	dmd dummy.d -ofdummy

	@echo "--- test exe ---"
	@./dummy
	@echo "----------------"

	dub build
	@echo "--- hijack   ---"
	@LD_PRELOAD=./libeu4dll.so ./dummy
	@echo "----------------"
