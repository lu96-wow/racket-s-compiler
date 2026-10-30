.PHONY: build test rebuild clean

build:
	racket binary-build/main.rkt

test: build
	raco test test/*.rkt

rebuild: clean build

clean:
	racket binary-build/main.rkt --clean
