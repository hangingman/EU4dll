all:
	dub build

test:
	dub build --build=unittest
	dub test --build=unittest