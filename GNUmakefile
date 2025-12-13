
.PHONY: build
build:
	zig build

os.iso: build grub.cfg
	mkdir -p isodir/boot/grub
	cp grub.cfg isodir/boot/grub
	cp zig-out/bin/kernel.elf isodir/boot/
	grub-mkrescue -o $@ isodir
	rm -r isodir

.PHONY: run
run: os.iso
	qemu-system-x86_64 -m 8G -cdrom os.iso -serial stdio

.PHONY: clean
clean:
	rm -f os.iso
	rm -rf isodir/
	rm -rf .zig-cache/
	rm -rf zig-out/
	rm -f log.txt
