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

#
# EU4にdllをかませて起動、dll.soっておかしいので後で変えたい
#
EU4_DIR := ~/.steam/debian-installation/steamapps/common/Europa\ Universalis\ IV/

run: all
	@echo "--- copy eu4dll.so ---"
	cp -f ./libeu4dll.so $(EU4_DIR)
	@echo "--- run eu4 ---"
	cd $(EU4_DIR) && LD_PRELOAD=./libeu4dll.so ./eu4
