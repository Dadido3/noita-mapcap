// Copyright (c) 2022 David Vogel
//
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

package main

import (
	"strings"

	"github.com/coreos/go-semver/semver"
)

// versionString contains the semantic version of the software as a string.
//
// This variable is only used to transfer the correct version information into the build.
// Don't use this variable in the software, use `version` instead.
//
// When building the software, the default `v0.0.0-development` is used.
// To compile the program with the correct version information, compile the following way:
//
// `go build -ldflags="-X 'main.versionString=x.y.z'"`, where `x.y.z` is the correct and valid version from the git tag.
// This variable may or may not contain the prefix v.
var versionString = "0.0.0-development"

// version of the program.
//
// When converted into a string, this will not contain the v prefix.
var version = semver.Must(semver.NewVersion(strings.TrimPrefix(versionString, "v")))
