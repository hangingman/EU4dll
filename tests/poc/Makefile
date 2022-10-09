# https://github.com/Ai-Himmel/Linux-so-hijack
# .so file highjack
all:
	dmd ./dummy.d -ofdummy

	@echo "--- test exe ---"
	@./dummy
	@echo "----------------"

	@echo "--- highjack   ---"
	@LD_PRELOAD=./libeu4dll-poc.so ./dummy
	@echo "----------------"
