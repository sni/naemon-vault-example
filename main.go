package main

import (
	"fmt"
	"syscall"
	"time"
	"unsafe"

	"github.com/ConSol/go-neb-wrapper/neb"
	"github.com/ConSol/go-neb-wrapper/neb/structs"
	"golang.org/x/term"
)

// Build contains the current git commit id
// compile passing -ldflags "-X main.Build <build sha1>" to set the id.
var Build string

func getVaultMacroCallback(callbackType int, data unsafe.Pointer) int {
	macroName := structs.GetVaultMacroName(data)
	// fetching the password would happen here
	// for this example, we just return the macroname along with the git id and a timestamp
	structs.SetVaultMacroValue(data, fmt.Sprintf("(%s / %s / %s)", macroName, Build, time.Now()))
	return neb.Ok
}

func init() {
	neb.Title = "naemon-vault-example"
	neb.Name = neb.Title
	neb.Desc = "naemon neb api vault passwords example"
	neb.License = "GPL v3"
	neb.Version = fmt.Sprintf("1.0.0 - %s", Build)
	neb.Author = "Sven Nierlein"

	neb.AddCallback(neb.VaultMacroData, getVaultMacroCallback)

	neb.NebModuleInitHook = func(flags int, args string) int {
		neb.CoreFLog("Loading %s", neb.Title)
		neb.CoreFLog("Init args: %s", args)

		if !term.IsTerminal(int(syscall.Stdin)) {
			neb.CoreFLog("could not read password: stdin is not a attached to a terminal")
			return neb.Error
		}

		fmt.Print("Enter Vault Master Password: ")
		bytePassword, err := term.ReadPassword(int(syscall.Stdin))
		if err != nil {
			neb.CoreFLog("could not read password: %s", err.Error())
			return neb.Error
		}

		password := string(bytePassword)
		neb.CoreFLog("read password: %s", password)
		return neb.Ok
	}
	neb.NebModuleDeinitHook = func(flags, reason int) int {
		neb.CoreFLog("Unloading %s", neb.Title)
		return neb.Ok
	}
}

func main() {}
