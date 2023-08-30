#!/usr/bin/make -f

MAKE:=make
SHELL:=bash
GOVERSION:=$(shell \
    go version | \
    awk -F'go| ' '{ split($$5, a, /\./); printf ("%04d%04d", a[1], a[2]); exit; }' \
)
# also update README.md when changing minumum version
MINGOVERSION:=00010020
MINGOVERSIONSTR:=1.20
BUILD:=$(shell git rev-parse --short HEAD)
# see https://github.com/go-modules-by-example/index/blob/master/010_tools/README.md
# and https://github.com/golang/go/wiki/Modules#how-can-i-track-tool-dependencies-for-a-module
TOOLSFOLDER=$(shell pwd)/tools
export GOBIN := $(TOOLSFOLDER)
export PATH := $(GOBIN):$(PATH)

.PHONY: vendor

all: build

tools: versioncheck vendor
	go mod download
	set -e; for DEP in $(shell grep "_ " buildtools/tools.go | awk '{ print $$2 }'); do \
		go install $$DEP; \
	done
	go mod tidy
	go mod vendor

updatedeps: versioncheck
	$(MAKE) clean
	go mod download
	set -e; for DEP in $(shell grep "_ " buildtools/tools.go | awk '{ print $$2 }'); do \
		go get $$DEP; \
	done
	go get -u ./...
	go get -t -u ./...
	go mod tidy

vendor:
	go mod download
	go mod tidy
	go mod vendor

build: vendor
	go build -tags naemon -buildmode=c-shared -ldflags "-s -w -X main.Build=$(BUILD)" -o naemon-vault-example.so

test: fmt vendor
	go test -v
	if grep -rn TODO: *.go; then exit 1; fi

citest: vendor
	#
	# Checking gofmt errors
	#
	if [ $$(gofmt -s -l *.go | wc -l) -gt 0 ]; then \
		echo "found format errors in these files:"; \
		gofmt -s -l *.go; \
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
	$(MAKE) test
	#
	# Benchmark tests
	#
	$(MAKE) benchmark
	#
	# Race rondition tests
	#
	$(MAKE) racetest
	#
	# All CI tests successful
	#

benchmark:
	go test -ldflags "-s -w -X main.Build=$(BUILD)" -v -bench=B\* -benchtime 10s -run=^$$ . -benchmem

racetest:
	go test -race -v

clean:
	rm -rf vendor
	rm -rf naemon-vault-example.so

GOVET=go vet -all
fmt: tools
	goimports -w *.go
	go vet -all -assign -atomic -bool -composites -copylocks -nilfunc -rangeloops -unsafeptr -unreachable .
	gofmt -w -s *.go
	./tools/gofumpt -w *.go
	./tools/gci write *.go --skip-generated
	goimports -w *.go

versioncheck:
	@[ $$( printf '%s\n' $(GOVERSION) $(MINGOVERSION) | sort | head -n 1 ) = $(MINGOVERSION) ] || { \
		echo "**** ERROR:"; \
		echo "**** module requires at least golang version $(MINGOVERSIONSTR) or higher"; \
		echo "**** this is: $$(go version)"; \
		exit 1; \
	}

golangci: tools
	#
	# golangci combines a few static code analyzer
	# See https://github.com/golangci/golangci-lint
	#
	golangci-lint run ./...

