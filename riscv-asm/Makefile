.PHONY: build test rebuild clean

build:
	racket binary-build/main.rkt

test: build
	raco test test/*.rkt

rebuild: clean build

clean:
	rm -rf generated/lib generated/gen
