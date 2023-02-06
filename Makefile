all: hello

hello:
	dune exec ./hello.exe

bench:
	@cat test.json

clean:
	dune clean

.PHONY: all hello clean bench
