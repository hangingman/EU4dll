all:
	dub build


test:
	dub clean
	dub test --build=unittest
