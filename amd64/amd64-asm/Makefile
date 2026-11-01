.PHONY: build test clean

build:
	racket binary-build/main.rkt

test: build
	raco test test.rkt test-oracle.rkt test-generated.rkt

clean:
	racket binary-build/main.rkt --clean
