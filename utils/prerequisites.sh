#!/usr/bin/env bash
set -e
# set -x

# These base packages will only be cross-compiled in case no version of them already exists on the target/
# hence not allowing chroot compilations which are the preferred method for packaging...

# Note that even those will (most likely) be rebuilt later inside a chroot, this is the reason we just check
# for paths, since those chroot-compiled binaries are acceptable even for our purpose.

SCRIPT=$(realpath "${0}")
SCRIPTPATH=$(dirname "${SCRIPT}")

pushd "${SCRIPTPATH}/../" >/dev/null

source "utils/colors.sh"
source "session/.state"

CAVOS_GCC_TARGET="x86_64-linux-musl"
mkdir -p session/target
CAVOS_FS_TARGET=$(readlink -f "session/target")

update_session() {
	echo -e "ids_track=\"$ids_track\"\nids_stage=\"$ids_stage\"" >"$SCRIPTPATH/../session/.state"
}

check_md5sum() {
	if [[ "$(md5sum "${1}" | sed 's/ .*//g')" != "${2}" ]]; then
		echo -e "${RED}!${CLEAR} Invalid md5sum! Exiting immediately! ($1) ($2)"
		exit 1
	fi
}

# Stage 0: We're creating our target and copying some fresh Linux headers.
if [[ "$ids_stage" == "0" ]]; then
	echo -e "${BLUE}(p)${CLEAR} ${CYAN}(Stage 0)${CLEAR} Creating target & fetching Linux headers"
	mkdir -p session/target/tools
	mkdir -p session/target/usr/include

	wget -nc https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.6.41.tar.xz
	check_md5sum linux-6.6.41.tar.xz 2201c0201a2a803da345a38dbdc38fcf
	tar xpvf linux-6.6.41.tar.xz >/dev/null

	cd linux-6.6.41

	make mrproper
	make headers

	find usr/include -type f ! -name '*.h' -delete
	cp -r usr/include/* "$CAVOS_FS_TARGET/usr/include/"

	cd ..
	rm -rf linux-6.6.41 linux-6.6.41.tar.xz

	ids_stage="1"
	update_session
fi

# Stage 1: Compile binutils.
if [[ "$ids_stage" == "1" ]]; then
	echo -e "${BLUE}(p)${CLEAR} ${CYAN}(Stage 1)${CLEAR} Compiling binutils"
	wget -nc https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.gz
	check_md5sum binutils-2.38.tar.gz f430dff91bdc8772fcef06ffdc0656ab
	tar xpvf binutils-2.38.tar.gz >/dev/null
	cd binutils-2.38/
	mkdir -p build
	cd build
	../configure --prefix=$CAVOS_FS_TARGET/tools \
		--with-sysroot=$CAVOS_FS_TARGET \
		--target=$CAVOS_GCC_TARGET \
		--disable-nls \
		--enable-gprofng=no \
		--disable-werror \
		--enable-new-dtags \
		--enable-default-hash-style=gnu >/dev/null
	make -j$(nproc) >/dev/null
	make install >/dev/null
	cd ../../
	rm -rf binutils-2.38/
	# rm -f binutils-2.38.tar.gz

	ids_stage="2"
	update_session
fi

# Stage 2: Compile a very standalone version of gcc for our cross-compiling toolchain.
if [[ "$ids_stage" == "2" ]]; then
	echo -e "${BLUE}(p)${CLEAR} ${CYAN}(Stage 2)${CLEAR} Static GCC compilation"
	wget -nc https://ftp.gnu.org/gnu/gcc/gcc-11.4.0/gcc-11.4.0.tar.gz
	check_md5sum gcc-11.4.0.tar.gz 555f990ed0cc31537c0731895e1273fe
	tar xpvf gcc-11.4.0.tar.gz >/dev/null
	cd gcc-11.4.0/

	contrib/download_prerequisites
	case $(uname -m) in
	x86_64)
		sed -e '/m64=/s/lib64/lib/' \
			-i.orig gcc/config/i386/t-linux64
		;;
	esac

	mkdir -p build
	cd build
	../configure \
		--prefix=${CAVOS_FS_TARGET}/tools --build="x86_64-cross-linux-gnu" \
		--host="x86_64-cross-linux-gnu" --target=${CAVOS_GCC_TARGET} \
		--with-sysroot=${CAVOS_FS_TARGET} \
		--disable-nls --with-newlib \
		--disable-libitm --disable-libvtv \
		--disable-libssp --disable-shared \
		--disable-libgomp --without-headers \
		--disable-threads --disable-multilib \
		--disable-libatomic --disable-libstdcxx \
		--enable-languages=c --disable-libquadmath \
		--disable-libsanitizer \
		--disable-decimal-float --enable-clocale=generic >/dev/null
	make all-gcc -j$(nproc) >/dev/null
	make all-target-libgcc -j$(nproc) >/dev/null
	make install-gcc install-target-libgcc >/dev/null
	cd ../
	# cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
	# 	$(dirname $($CAVOS_GCC_TARGET-gcc -print-libgcc-file-name))/include/limits.h
	cd ../
	rm -rf gcc-11.4.0/
	# rm -f gcc-11.4.0.tar.gz

	ids_stage="3"
	update_session
fi

# Stage 3: Prepare our libc (musl).
if [[ "$ids_stage" == "3" ]]; then
	echo -e "${BLUE}(p)${CLEAR} ${CYAN}(Stage 3)${CLEAR} Musl compilation"
	wget -nc https://musl.libc.org/releases/musl-1.2.5.tar.gz
	check_md5sum musl-1.2.5.tar.gz ac5cfde7718d0547e224247ccfe59f18
	tar xpvf musl-1.2.5.tar.gz >/dev/null
	cd musl-1.2.5/

	export PATH=$CAVOS_FS_TARGET/tools/bin/:$PATH
	./configure CROSS_COMPILE=${CAVOS_GCC_TARGET}- --prefix=/ --target=${CAVOS_GCC_TARGET} >/dev/null
	make -j$(nproc) >/dev/null
	DESTDIR="$CAVOS_FS_TARGET/usr" make install >/dev/null
	cd ../
	rm -rf musl-1.2.5/
	rm -f musl-1.2.5.tar.gz

	rm -f "$CAVOS_FS_TARGET/lib"
	ln -sf "usr/lib" "$CAVOS_FS_TARGET/lib"

	rm -f "$CAVOS_FS_TARGET/bin"
	ln -sf "usr/bin" "$CAVOS_FS_TARGET/bin"

	rm -f "$CAVOS_FS_TARGET/usr/lib/ld-musl-x86_64.so.1"
	ln -sf "libc.so" "$CAVOS_FS_TARGET/usr/lib/ld-musl-x86_64.so.1"

	mkdir -p "$CAVOS_FS_TARGET/usr/bin"
	ln -sf "../lib/ld-musl-x86_64.so.1" "$CAVOS_FS_TARGET/usr/bin/ldd"

	mkdir -p "$CAVOS_FS_TARGET/etc"
	echo -e "/usr/lib\n/lib" >"$CAVOS_FS_TARGET/etc/ld-musl-x86_64.path"

	ids_stage="4"
	update_session
fi

# Stage 4: Compile an actual gcc cross-compiler.
if [[ "$ids_stage" == "4" ]]; then
	echo -e "${BLUE}(p)${CLEAR} ${CYAN}(Stage 4)${CLEAR} GCC cross-compiler compilation (final)"
	wget -nc https://ftp.gnu.org/gnu/gcc/gcc-11.4.0/gcc-11.4.0.tar.gz
	check_md5sum gcc-11.4.0.tar.gz 555f990ed0cc31537c0731895e1273fe
	tar xpvf gcc-11.4.0.tar.gz >/dev/null
	cd gcc-11.4.0/

	bash ../patches/gcc-alpine/apply_patches_ct.sh
	contrib/download_prerequisites

	mkdir -p build
	cd build

	export PATH=$CAVOS_FS_TARGET/tools/bin/:$PATH
	AR=ar LDFLAGS="-Wl,-rpath,$CAVOS_FS_TARGET/tools/lib" \
		../configure \
		--prefix="$CAVOS_FS_TARGET/tools/" \
		--build=x86_64-cross-linux-gnu \
		--host=x86_64-cross-linux-gnu \
		--target=$CAVOS_GCC_TARGET \
		--disable-multilib \
		--with-sysroot="$CAVOS_FS_TARGET" \
		--disable-nls \
		--enable-shared \
		--enable-languages=c,c++ \
		--enable-threads=posix \
		--enable-clocale=generic \
		--enable-libstdcxx-time \
		--enable-fully-dynamic-string \
		--disable-symvers \
		--disable-libsanitizer \
		--disable-lto-plugin \
		--disable-libssp >/dev/null

	make -j$(nproc) AS_FOR_TARGET="$CAVOS_GCC_TARGET-as" \
		LD_FOR_TARGET="$CAVOS_GCC_TARGET-ld" >/dev/null
	make install >/dev/null

	cd ../../
	rm -rf gcc-11.4.0/
	# rm -f gcc-11.4.0.tar.gz

	ids_stage="5"
	update_session
fi

# Stage 5: Compile binutils for the chroot environment.
if [[ "$ids_stage" == "5" ]]; then
	echo -e "${BLUE}(p)${CLEAR} ${CYAN}(Stage 5)${CLEAR} Binutils chroot assembly"
	wget -nc https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.gz
	check_md5sum binutils-2.38.tar.gz f430dff91bdc8772fcef06ffdc0656ab
	tar xpvf binutils-2.38.tar.gz >/dev/null
	cd binutils-2.38/

	sed '6009s/$add_dir//' -i ltmain.sh

	mkdir -p build
	cd build

	export PATH=$CAVOS_FS_TARGET/tools/bin/:$PATH
	../configure --prefix=/usr \
		--host=$CAVOS_GCC_TARGET \
		--disable-nls \
		--enable-shared \
		--enable-gprofng=no \
		--disable-werror \
		--enable-64-bit-bfd \
		--enable-new-dtags \
		--enable-default-hash-style=gnu >/dev/null
	make -j$(nproc) >/dev/null
	make DESTDIR="$CAVOS_FS_TARGET" install >/dev/null
	rm -f $CAVOS_FS_TARGET/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}

	cd ../../
	rm -rf binutils-2.38/
	rm -f binutils-2.38.tar.gz

	ids_stage="6"
	update_session
fi

# Stage 6: Compile gcc for the chroot environment.
if [[ "$ids_stage" == "6" ]]; then
	echo -e "${BLUE}(p)${CLEAR} ${CYAN}(Stage 6)${CLEAR} Gcc chroot assembly"
	wget -nc https://ftp.gnu.org/gnu/gcc/gcc-11.4.0/gcc-11.4.0.tar.gz
	check_md5sum gcc-11.4.0.tar.gz 555f990ed0cc31537c0731895e1273fe
	tar xpvf gcc-11.4.0.tar.gz >/dev/null
	cd gcc-11.4.0/

	bash ../patches/gcc-alpine/apply_patches_ct.sh
	case $(uname -m) in
	x86_64)
		sed -e '/m64=/s/lib64/lib/' \
			-i.orig gcc/config/i386/t-linux64
		;;
	esac
	# patch -Np1 -i ../patches/gcc-alpine/fix_fenv_header.patch
	contrib/download_prerequisites

	mkdir -p build
	cd build

	export PATH=$CAVOS_FS_TARGET/tools/bin/:$PATH
	../configure \
		--host=$CAVOS_GCC_TARGET \
		--target=$CAVOS_GCC_TARGET \
		LDFLAGS_FOR_TARGET=-L$PWD/$CAVOS_GCC_TARGET/libgcc \
		--prefix=/usr \
		--with-build-sysroot=$CAVOS_FS_TARGET \
		--enable-default-pie \
		--enable-default-ssp \
		--disable-nls \
		--disable-multilib \
		--disable-libatomic \
		--disable-libgomp \
		--disable-libquadmath \
		--disable-libsanitizer \
		--disable-libssp \
		--disable-libvtv \
		--enable-languages=c,c++ >/dev/null
	make -j$(nproc) >/dev/null
	make DESTDIR=$CAVOS_FS_TARGET install >/dev/null
	ln -sf gcc $CAVOS_FS_TARGET/usr/bin/cc

	cd ../../
	rm -rf gcc-11.4.0/
	rm -f gcc-11.4.0.tar.gz

	ids_stage="7"
	update_session
fi

USR_PATHNAME=$(readlink -f "$CAVOS_FS_TARGET/usr/")
cav_repo="$SCRIPTPATH/../"

pushd "$CAVOS_FS_TARGET" >/dev/null
chmod +x "${cav_repo}/methods/autotools.sh"

USR_PATHNAME_FIXED=$(readlink -e "$USR_PATHNAME")
DESTDIR_FIXED=$(readlink -e "$USR_PATHNAME/../")

# Big thanks to:
#		- The LFS book: https://www.linuxfromscratch.org/lfs/view/stable/
#		- The MLFS repo: https://github.com/dslm4515/Musl-LFS

if [ ! -f "$USR_PATHNAME/bin/m4" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz" "" "build-aux/config.sub" "" "" "" "" "" "0d90823e1426f1da2fd872df0311298d"
fi

if [ ! -f "$USR_PATHNAME/bin/ncursesw6-config" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz" "" "config.sub" "--with-shared --without-normal --with-cxx-shared --without-debug --without-ada --disable-stripping" "" "" "" "ln -sf libncursesw.so $USR_PATHNAME/lib/libncurses.so && sed -e 's/^#if.*XOPEN.*$/#if 1/' -i $USR_PATHNAME/include/curses.h" "ac2d2629296f04c8537ca706b6977687"
fi

if [ ! -f "$USR_PATHNAME/bin/bash" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/bash/bash-5.2.tar.gz" "" "support/config.sub" "--without-bash-malloc" "" "" "" "ln -sf bash $USR_PATHNAME/bin/sh" "cfb4cf795fc239667f187b3d6b3d396f"
fi

if [ ! -f "$USR_PATHNAME/bin/id" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/coreutils/coreutils-9.5.tar.xz" "" "build-aux/config.sub" "--enable-install-program=hostname" "" "" "" "" "e99adfa059a63db3503cc71f3d151e31"
fi

if [ ! -f "$USR_PATHNAME/bin/diff" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/diffutils/diffutils-3.10.tar.xz" "" "build-aux/config.sub" "" "" "" "" "" "2745c50f6f4e395e7b7d52f902d075bf"
fi

if [ ! -f "$USR_PATHNAME/bin/file" ]; then
	${cav_repo}/methods/autotools.sh "https://astron.com/pub/file/file-5.45.tar.gz" "/usr" "config.sub" "--prefix /usr" "" "DESTDIR=$DESTDIR_FIXED" "mkdir build && cd build && ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib && make -j$(nproc) && cd .." "rm -f $USR_PATHNAME/lib/libmagic.la" "26b2a96d4e3a8938827a1e572afd527a"
fi

if [ ! -f "$USR_PATHNAME/bin/find" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/findutils/findutils-4.10.0.tar.xz" "" "build-aux/config.sub" "" "" "" "" "" "870cfd71c07d37ebe56f9f4aaf4ad872"
fi

if [ ! -f "$USR_PATHNAME/bin/gawk" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/gawk/gawk-5.3.0.tar.xz" "" "build-aux/config.sub" "" "" "" "sed -i 's/extras//' Makefile.in" "" "97c5a7d83f91a7e1b2035ebbe6ac7abd"
fi

if [ ! -f "$USR_PATHNAME/bin/grep" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/grep/grep-3.11.tar.xz" "" "build-aux/config.sub" "" "" "" "" "" "7c9bbd74492131245f7cdb291fa142c0"
fi

if [ ! -f "$USR_PATHNAME/bin/gzip" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/gzip/gzip-1.13.tar.xz" "" "build-aux/config.sub" "" "" "" "" "" "d5c9fc9441288817a4a0be2da0249e29"
fi

if [ ! -f "$USR_PATHNAME/bin/make" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz" "" "build-aux/config.sub" "--without-guile" "" "" "" "" "c8469a3713cbbe04d955d4ae4be23eeb"
fi

if [ ! -f "$USR_PATHNAME/bin/patch" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz" "" "build-aux/config.sub" "" "" "" "" "" "78ad9937e4caadcba1526ef1853730d5"
fi

if [ ! -f "$USR_PATHNAME/bin/sed" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz" "" "build-aux/config.sub" "" "" "" "" "" "6aac9b2dbafcd5b7a67a8a9bcb8036c3"
fi

if [ ! -f "$USR_PATHNAME/bin/tar" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz" "" "build-aux/config.sub" "" "" "" "" "" "a2d8042658cfd8ea939e6d911eaf4152"
fi

if [ ! -f "$USR_PATHNAME/bin/xz" ]; then
	${cav_repo}/methods/autotools.sh "https://github.com/tukaani-project/xz/releases/download/v5.4.6/xz-5.4.6.tar.xz" "" "build-aux/config.sub" "--disable-static" "" "" "" "rm -f $USR_PATHNAME/lib/liblzma.la" "7ade7bd1181a731328f875bec62a9377"
fi

if [ ! -f "$USR_PATHNAME/bin/gperf" ]; then
	${cav_repo}/methods/autotools.sh "https://ftp.gnu.org/gnu/gperf/gperf-3.1.tar.gz" "" "build-aux/config.sub" "" "" "" "" "" "9e251c0a618ad0824b51117d5d9db87e"
fi
