all: hello

hello:
	dune exec ./hello.exe

bench:
	time dune build ./hello.exe

clean:
	dune clean

.PHONY: all hello clean bench
