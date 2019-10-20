rem Copyright (c) 2019 David Vogel
rem 
rem This software is released under the MIT License.
rem https://opensource.org/licenses/MIT

set GOARCH=386
set CGO_ENABLED=1

go build -o capture.dll -buildmode=c-shared