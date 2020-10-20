rd distribution /s/q

mkdir distribution
mkdir distribution/noita-mapcap

robocopy "." "distribution/noita-mapcap/" init.lua LICENSE compatibility.xml mod.xml README.md AREAS.md
robocopy "images/" "distribution/noita-mapcap/images/" coordinates.png example1.png example2.png scale32_base-layout.png scale32_main-world.png scale32_extended.png

robocopy "data" "distribution/noita-mapcap/data" /e
robocopy "files" "distribution/noita-mapcap/files" /e

robocopy "bin/capture-b/" "distribution/noita-mapcap/bin/capture-b/" capture.dll README.md
robocopy "bin/stitch/" "distribution/noita-mapcap/bin/stitch/" stitch.exe README.md

cd distribution

7z a -t7z Windows.x86.7z -m0=lzma2 -mx=9 -aoa noita-mapcap

cd ..
