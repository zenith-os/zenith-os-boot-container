FROM archlinux:latest as build

RUN pacman -Sy arch-install-scripts fakeroot fakechroot --noconfirm

RUN mkdir -p /bootfs

RUN mkdir -m 0755 -p /bootfs/var/{cache/pacman/pkg,lib/pacman,log} /bootfs/{dev,run,etc/pacman.d}
RUN mkdir -m 1777 -p /bootfs/tmp
RUN mkdir -m 0555 -p /bootfs/{sys,proc}
RUN pacman-key --gpgdir /bootfs/etc/pacman.d/gnupg --init

RUN fakechroot -- fakeroot -- pacman -Sy -r /bootfs --noconfirm \
    base base-devel linux-zen linux-firmware linux-zen-headers \
    ukify btrfs-progs intel-ucode amd-ucode podman toolbox \
    networkmanager nano git vim openssh sudo zsh 

COPY rootfs/* /bootfs/

# RUN fakechroot -- fakeroot -- chroot /bootfs update-ca-trust
# RUN fakechroot -- fakeroot -- chroot /bootfs pacman-key --init
# RUN fakechroot -- fakeroot -- chroot /bootfs pacman-key --populate

COPY exclude .

RUN mkdir /output

RUN fakechroot -- fakeroot -- tar \
    --numeric-owner \
    --xattrs \
    --acls \
    --exclude-from=exclude \
    -C "/bootfs" \
    -c . \
    -f "/output/zenithos-bootfs.tar"

WORKDIR /output
RUN zstd --long -T0 -8 "zenithos-bootfs.tar"
RUN sha256sum "zenithos-bootfs.tar.zst" > "zenithos-bootfs.tar.zst.SHA256"

FROM alpine:3.19 as extract

RUN apk add --no-cache tar zstd

WORKDIR /dist

COPY --from=build /output/zenithos-bootfs.tar.zst .

RUN mkdir /bootfs

RUN tar -C /bootfs --extract --file zenithos-bootfs.tar.zst

FROM alpine:3.19 AS root

COPY --from=extract /bootfs/ /

ENV LANG=C.UTF-8
CMD ["/usr/bin/bash"]