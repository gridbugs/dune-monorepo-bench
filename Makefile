all: hello

hello:
	dune exec ./hello.exe

bench:
	@echo Hello, World!

clean:
	dune clean

.PHONY: all hello clean bench
