#!/usr/bin/make -f

MAKE:=make
SHELL:=bash
GOVERSION:=$(shell \
    go version | \
    awk -F'go| ' '{ split($$5, a, /\./); printf ("%04d%04d", a[1], a[2]); exit; }' \
)
# also update README.md when changing minumum version
MINGOVERSION:=00010016
MINGOVERSIONSTR:=1.16
BUILD:=$(shell git rev-parse --short HEAD)

.PHONY: vendor

all: build

tools: versioncheck vendor dump
	go mod download
	go mod tidy
	go mod vendor

updatedeps: versioncheck
	$(MAKE) clean
	go mod download
	go get -u ./...
	go get -t -u ./...
	go mod tidy

vendor:
	go mod download
	go mod tidy
	go mod vendor

build: vendor
	#PKG_CONFIG_PATH=/src/naemon-core LIBRARY_PATH=../naemon-core/.libs/ CGO_CFLAGS_ALLOW=".*" go build -tags naemon -buildmode=c-shared -ldflags "-s -w"
	go build -tags naemon -buildmode=c-shared -ldflags "-s -w -X main.Build=$(BUILD)"

test: fmt dump vendor
	go test -v
	if grep -rn TODO: *.go; then exit 1; fi

citest: vendor
	#
	# Checking gofmt errors
	#
	if [ $$(gofmt -s -l . | wc -l) -gt 0 ]; then \
		echo "found format errors in these files:"; \
		gofmt -s -l .; \
		exit 1; \
	fi
	#
	# Checking TODO items
	#
	if grep -rn TODO: *.go; then exit 1; fi
	# Run other subtests
	#
	$(MAKE) golangci
	$(MAKE) fmt
	#
	# Normal test cases
	#
	go test -v
	#
	# Benchmark tests
	#
	go test -v -bench=B\* -run=^$$ . -benchmem
	#
	# Race rondition tests
	#
	$(MAKE) racetest
	#
	# All CI tests successfull
	#
	go mod tidy

benchmark: fmt
	go test -ldflags "-s -w -X main.Build=$(BUILD)" -v -bench=B\* -benchtime 10s -run=^$$ . -benchmem

racetest: fmt
	go test -race -short -v

clean:
	rm -rf vendor
	rm -rf naemon-vault-neb-example

fmt:
	goimports -w .
	go vet -all -assign -atomic -bool -composites -copylocks -nilfunc -rangeloops -unsafeptr -unreachable .
	gofmt -w -s .

versioncheck:
	@[ $$( printf '%s\n' $(GOVERSION) $(MINGOVERSION) | sort | head -n 1 ) = $(MINGOVERSION) ] || { \
		echo "**** ERROR:"; \
		echo "**** NEB module requires at least golang version $(MINGOVERSIONSTR) or higher"; \
		echo "**** this is: $$(go version)"; \
		exit 1; \
	}

golangci: tools
	#
	# golangci combines a few static code analyzer
	# See https://github.com/golangci/golangci-lint
	#
	golangci-lint run ./...

