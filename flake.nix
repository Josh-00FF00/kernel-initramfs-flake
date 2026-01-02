{
  description = "Minimal Initramfs with Custom Kernel Support";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          busyboxStatic = pkgs.pkgsStatic.busybox;

          initScript = pkgs.writeScript "init" ''
            #!/bin/busybox sh
            /bin/busybox --install -s
            mount -t devtmpfs devtmpfs /dev
            mount -t proc proc /proc
            mount -t sysfs sysfs /sys
            echo "--------------------------------------"
            echo "Custom Kernel Boot"
            echo "--------------------------------------"
            setsid cttyhack sh
          '';

          mountScript = pkgs.writeScript "mhost" ''
            mkdir /host
            mount -t 9p -o trans=virtio,version=9p2000.L,msize=262144 host_share /host
          '';
        in
        {
          default =
            pkgs.runCommand "busybox-initramfs.cpio"
              {
                nativeBuildInputs = [
                  pkgs.cpio
                  pkgs.gzip
                ];
              }
              ''
                mkdir -p ./root/{bin,dev,proc,sys,etc,sbin}
                cp ${busyboxStatic}/bin/busybox ./root/bin/busybox
                cp ${initScript} ./root/init
                cp ${mountScript} ./root/bin/mhost
                chmod +x ./root/init

                mkdir -p $out

                cd root
                find . -print0 | cpio --null -o -H newc > $out/initramfs.cpio
              '';
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          initramfsDir = self.packages.${system}.default;
          initramfsPath = "${initramfsDir}/initramfs.cpio";

          # Determine QEMU binary based on architecture
          qemuBinary = if system == "aarch64-linux" then "qemu-system-aarch64" else "qemu-system-x86_64";

          qemuFlags = "-nographic -append 'console=ttyS0 earlyprintk nokaslr no_hash_pointers' -m 512M";
        in
        {
          default = {
            type = "app";

            # The wrapper script handles the kernel logic
            program =
              (pkgs.writeShellScript "run-vm" ''
                KERNEL="$1"

                if [ -z "$KERNEL" ]; then
                  # Default: Use the generic kernel from Nixpkgs
                  KERNEL="${pkgs.linux}/bzImage"
                  echo "Using default Nixpkgs kernel: $KERNEL"
                else
                  # Custom: Use the path provided by the user
                  echo "Using custom kernel path: $KERNEL"
                fi

                echo "Booting with initramfs: ${initramfsPath}"

                ${pkgs.qemu}/bin/${qemuBinary} \
                  -kernel "$KERNEL" \
                  -initrd ${initramfsPath} \
                  -virtfs local,path=$(pwd),mount_tag=host_share,security_model=none,id=host_share \
                  ${qemuFlags}
              '').outPath;
          };
        }
      );
    };
}
