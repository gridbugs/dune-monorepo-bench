all: hello

hello:
	dune exec ./hello.exe

bench:
	dune exec --display=quiet bin/bench.exe -- dune build ./hello.exe -j auto

clean:
	dune clean

.PHONY: all hello clean bench
