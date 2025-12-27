# Kernel Initramfs Flake

This is a flake that will build a minimal, static, busybox initramfs image and
boot a default kernel (or, more commonly, a custom built one) into a root shell.

Additionally with an optional script (`mhost`) to mount the current directory as
a shared folder into the QEMU vm. Assuming that the following kernel options
have been enabled (they are not enabled by default):

```
CONFIG_9P_FS y
CONFIG_9P_FS_POSIX_ACL y
CONFIG_9P_FS_SECURITY y
CONFIG_NET_9P y
CONFIG_NET_9P_VIRTIO y
```

A shorthand for getting a default config that is capable of being booted inside
a QEMU vm is:

 `make defconfig kvm_guest.config`

In the kernel source tree

## Usage

`nix run .`

In the flake folder will download, and run a default kernel with the default
busybox initramfs.

To run a custom kernel, pass the path to the kernel boot image as an argument to
the flake:

`nix run . -- ./kernel_src/arch/x86_64/boot/bzImage`

To exit QEMU the magic keypresses are: `C-a, C-x` (C=CTRL)

1. `C-a` QEMU attention key
2. `C-x` Kill running VM

## Motivation

One of the annoying things I have had to do when doing hacky kernel dev is
creating small initramfs for different architectures. Additionally forgetting
the args to share home directories as well. Hopefully I shall never need to
think of that again!
