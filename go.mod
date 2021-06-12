module github.com/sni/naemon-vault-neb-example

go 1.15

require (
	github.com/ConSol/go-neb-wrapper v0.0.0-20170828074223-42e4d17112db
	golang.org/x/term v0.0.0-20210503060354-a79de5458b56
)

replace github.com/ConSol/go-neb-wrapper => ./packages/go-neb-wrapper
