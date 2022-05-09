## Relocatable build of qemu for macOS

### How to use the scripts
- install some dependencies, these should already exist if brew is used
```
$ brew install ronn gengetopt automake autoconf libtool cmake meson ninja
```
- run the `build-qemu.sh` script
```
$ chmod +x build-qemu.sh
```
```
$ PREFIX=/Application/qemu-custom.app
$ ./build-qemu.sh
```
- finally add the `$PREFIX/bin` to `PATH`
```
$ export PATH=$PATH:$PREFIX/bin
```
- test the build using an alpine image (download **virtual** image: https://www.alpinelinux.org/downloads/)
```
$ qemu-system-x86_64 -m 512 -nic user -boot d -cdrom alpine-virt-3.15.4-x86.iso -display cocoa
```
