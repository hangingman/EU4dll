all:
	dub build

test:
	dub build --build=unittest
	dub test --build=unittest -- --threads=1

clean:
	dub clean
