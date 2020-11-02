all:
	dub build

test:
	dub test --build=unittest
