set GOARCH=386
set CGO_ENABLED=1

go build -o capture.dll -buildmode=c-shared