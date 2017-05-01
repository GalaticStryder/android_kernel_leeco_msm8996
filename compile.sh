#!/bin/bash
#
# Copyright - Ícaro Hoff <icarohoff@gmail.com>
#
#              \
#              /\
#             /  \
#            /    \
#
SCRIPT_VERSION="3.5.0 (How Siegfried was Mourned and Buried)"

# Colorize
red='\033[01;31m'
green='\033[01;32m'
yellow='\033[01;33m'
blue='\033[01;34m'
blink_red='\033[05;31m'
blink_green='\033[05;32m'
blink_yellow='\033[05;33m'
blink_blue='\033[05;34m'
restore='\033[0m'

# Cleaning
clear

# Naming
NAME="Lambda"

# Arguments
FLAVOR=${1};

# Flavor
if [ "$FLAVOR" = mx ]; then
	# EUI
	FLAVOR="mx"
	FNAME="MX"
	FMODULE="yes"
elif [ "$FLAVOR" = lx ]; then
	# LineageOS
	FLAVOR="lx"
	FNAME="LX"
	FMODULE="no"
else if [ "$FLAVOR" = perf ]; then
	# LA.UM
	FLAVOR="perf"
	FNAME="PERF"
	FMODULE="no"
fi;
fi;

# Target
TARGET="pro3-${FLAVOR}"

# Resources
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"

# Variables
export ARCH=arm64
IMAGE=Image.gz-dtb
MODIMAGE=modules.img
DEFCONFIG=${TARGET}_defconfig
BUILD_DATE=$(date -u +%m%d%Y)

# Paths
KERNEL_FOLDER=`pwd`
OUT_FOLDER="$KERNEL_FOLDER/out"
REPACK_FOLDER="$KERNEL_FOLDER/../anykernel"
MODULES_FOLDER="$REPACK_FOLDER/modules-img"
RAMDISK_FOLDER="$REPACK_FOLDER/ramdisk"
TEMP_FOLDER="$REPACK_FOLDER/temporary"
TOOLCHAIN_FOLDER="$KERNEL_FOLDER/../toolchains"
PRODUCT_FOLDER="$KERNEL_FOLDER/../products"

# Functions
function check_folders {
	if [ ! -d $OUT_FOLDER ]; then
		echo -e ${yellow}"Could not find output folder. Creating it..."${restore}
		echo -e ${green}"This folder is used to compile the Kernel out of the source code tree."${restore}
		mkdir -p $OUT_FOLDER
		echo ""
	fi;
	if [ ! -d $TOOLCHAIN_FOLDER ]; then
		# Fatal!
		echo -e ${red}"Could not find toolchains folder. Aborting..."${restore}
		echo -e ${yellow}"Read the readme.md for instructions."${restore}
		echo ""
		exit
	fi;
	if [ ! -d $REPACK_FOLDER ]; then
		# Fatal!
		echo -e ${red}"Could not find anykernel folder. Aborting..."${restore}
		echo -e ${yellow}"Read the readme.md for instructions."${restore}
		echo ""
		exit
	fi;
	if [ ! -d $MODULES_FOLDER ]; then
		echo -e ${yellow}"Could not find modules folder. Creating it..."${restore}
		echo -e ${green}"This folder is used to mount the loopback image to store the Kernel modules."${restore}
		mkdir -p $MODULES_FOLDER
		echo ""
	fi;
	if [ ! -d $TEMP_FOLDER ]; then
		echo -e ${yellow}"Could not find temporary folder. Creating it..."${restore}
		echo -e ${green}"This folder is used to strip down the Kernel modules."${restore}
		mkdir -p $TEMP_FOLDER
		echo ""
	fi;
	if [ ! -d $PRODUCT_FOLDER ]; then
		echo -e ${yellow}"Could not find products folder. Creating it..."${restore}
		mkdir -p $PRODUCT_FOLDER
		echo ""
	fi;
}

function checkout {
	# Check the proper AnyKernel2 branch.
	cd $REPACK_FOLDER
	git checkout $TARGET
	cd $KERNEL_FOLDER
	echo ""
}

function ccache_setup {
	if [ $USE_CCACHE == true ]; then
		CCACHE=`which ccache`
	else
		# Empty if USE_CCACHE is not set.
		CCACHE=""
	fi;
	echo -e ${yellow}"Ccache information:"${restore}
	# Print binary location as well if not empty.
	if [ ! -z "$CCACHE" ]; then
		echo "binary location                     $CCACHE"
	fi;
	# Show the more advanced ccache statistics.
	ccache -s
	echo ""
}

function prepare_bacon {
	# Make sure the local .config is gone.
	make mrproper
	if [ -f $OUT_FOLDER/Makefile ]; then
		# Clean everything inside output folder if dirty.
		cd $OUT_FOLDER
		make mrproper
		make clean
		cd $KERNEL_FOLDER
	fi;
	# We must remove the Image.gz-dtb manually if present.
	if [ -f $OUT_FOLDER/arch/$ARCH/boot/$IMAGE ]; then
		rm -fv $OUT_FOLDER/arch/$ARCH/boot/$IMAGE
	fi;
	# Remove the previous Kernel from anykernel folder if present.
	if [ -f $REPACK_FOLDER/$IMAGE ]; then
		rm -fv $REPACK_FOLDER/$IMAGE
	fi;
	# Remove all modules inside temporary folder unconditionally.
	rm -fv $TEMP_FOLDER/*
	# Remove the previous modules image if present.
	if [ -f $RAMDISK_FOLDER/$MODIMAGE ]; then
		rm -fv $RAMDISK_FOLDER/$MODIMAGE
	fi;
	echo ""
	echo -e ${green}"Everything is ready to start..."${restore}
}

function mka_bacon {
	# Clone the source to to output folder and compile over there.
	make -C "$KERNEL_FOLDER" O="$OUT_FOLDER" "$DEFCONFIG"
	make -C "$KERNEL_FOLDER" O="$OUT_FOLDER" "$THREAD"
}

function check_kernel {
	if [ -f $OUT_FOLDER/arch/$ARCH/boot/$IMAGE ]; then
		COMPILATION=sucesss
	else
		# If there's no image, the compilation may have failed.
		COMPILATION=sucks
	fi;
}

function mka_module {
	# Copy the modules to temporary folder to be stripped.
	for i in $(find "$OUT_FOLDER" -name '*.ko'); do
		cp -av "$i" $TEMP_FOLDER/
	done;
	# Strip debugging symbols from modules.
	$STRIP --strip-debug $TEMP_FOLDER/*
	# Give all modules R/W permissions.
	chmod 755 $TEMP_FOLDER/*
	# Create the EXT4 modules image and tune its parameters.
	dd if=/dev/zero of=$REPACK_FOLDER/$MODIMAGE bs=4k count=3000
	mkfs.ext4 $REPACK_FOLDER/$MODIMAGE
	tune2fs -c0 -i0 $REPACK_FOLDER/$MODIMAGE
	echo ""
	echo -e ${red}"Root is needed to use mount, chown and umount commands."${restore}
	# Mount empty modules image to insert the modules.
	sudo mount -o loop $REPACK_FOLDER/$MODIMAGE $MODULES_FOLDER
	# Change the owner to the normal user account so we can copy without 'sudo'.
	sudo chown $USER:$USER -R $MODULES_FOLDER
	# Copy the stripped modules to the image folder.
	for i in $(find "$TEMP_FOLDER" -name '*.ko'); do
		cp -av "$i" $MODULES_FOLDER/;
	done;
	if [ -f $MODULES_FOLDER/wlan.ko ]; then
		# Create qca_cld_wlan.ko linking to the original wlan.ko module.
		echo ""
		echo -e ${yellow}"Creating qca_cld_wlan.ko module symlink..."${restore}
		mkdir -p $MODULES_FOLDER/qca_cld
		cd $MODULES_FOLDER/qca_cld
		ln -s -f /system/lib/modules/wlan.ko qca_cld_wlan.ko
		cd $KERNEL_FOLDER
	fi;
	# Sync after we're done.
	sync
}

function mka_package {
	# Copy the new Kernel to the repack folder.
	cp -fv $OUT_FOLDER/arch/$ARCH/boot/$IMAGE $REPACK_FOLDER/$IMAGE
	if [ "$FMODULE" = yes ]; then
		# Only MX firmware needs modules in /system.
		mka_module
	fi;
	# Show image statistics.
	if [ -f $REPACK_FOLDER/$MODIMAGE ]; then
		echo ""
		echo -e ${yellow}"Modules image statistics:"${restore}
		stat $REPACK_FOLDER/$MODIMAGE
		echo ""
		echo -e ${yellow}"Modules image size:"${restore}
		du -sh $REPACK_FOLDER/$MODIMAGE
		# Move the modules image to ramdisk.
		mv $REPACK_FOLDER/$MODIMAGE $RAMDISK_FOLDER/$MODIMAGE
	fi;
	if [ -f $REPACK_FOLDER/$IMAGE ]; then
		echo ""
		echo -e ${yellow}"Kernel image statistics:"${restore}
		stat $REPACK_FOLDER/$IMAGE
		echo ""
		echo -e ${yellow}"Kernel image size:"${restore}
		du -sh $REPACK_FOLDER/$IMAGE
	fi;
}

function zip_package {
	cd $REPACK_FOLDER
	# Make sure everything is settled before zipping.
	echo -e ${yellow}"Please, wait 10 seconds..."${restore}
	if [ "$FMODULE" = yes ]; then
		# Unmount the modules folder with 'sudo' as well.
		sudo umount -v modules-img
	fi;
	sleep 10 && zip -x@zipexclude -r9 ${ZIPFILE}.zip *
	echo ""
	echo -e ${green}"Successfully built ${ZIPFILE}.zip."${restore}
	# Move the zip file to the 'products' folder to be stored and safe.
	mv ${ZIPFILE}.zip $PRODUCT_FOLDER/
	cd $PRODUCT_FOLDER
	# Create an md5sum file to be checked in recovery.
	md5sum ${ZIPFILE}.zip > ${ZIPFILE}.zip.md5sum
	cd $KERNEL_FOLDER
}

DATE_START=$(date +"%s")
echo -e "${blue}"
echo "                   \                    "
echo "                   /\                   "
echo "                  /  \                  "
echo "                 /    \                 "
echo -e "${restore}"
echo -e "${blink_blue}" "This is the ultimate Kernel build script, $USER. " "${restore}"
echo -e "${blink_green}" "Version: $SCRIPT_VERSION " "${restore}"
echo ""
if [ $USE_CCACHE == true ]; then
	ccache_setup
else
	echo -e ${blue}"Optional:"${restore}
	echo -e ${yellow}"Add 'export USE_CCACHE=true' to your shell configuration to enable ccache."${restore}
	echo ""
fi;

# Look for all helper folders.
check_folders

# Prompt for the flavor if not given.
if [ -z "$FLAVOR" ]; then
	echo -e ${blink_red}"Please, set a build flavor as argument."${restore};
	echo -e ${blink_yellow}"Available:"${restore};
	echo -e ${blue}"MX: EUI based firmware."${restore};
	echo -e ${blue}"LX: LineageOS based firmware."${restore};
	echo "";
	echo "Which is the build flavor?"
	select fchoice in MX LX PERF
	do
	case "$fchoice" in
		"MX")
			FLAVOR="mx"
			FNAME="MX"
			FMODULE="yes"
			break;;
		"LX")
			FLAVOR="lx"
			FNAME="LX"
			FMODULE="no"
			break;;
		"PERF")
			FLAVOR="perf"
			FNAME="PERF"
			FMODULE="yes"
			break;;
	esac
	done
	TARGET="pro3-${FLAVOR}"
	DEFCONFIG=${TARGET}_defconfig
	echo ""
fi;

# Checkout the proper AnyKernel2 branch? Just uncomment.
#checkout

echo "Which is the build tag?"
select choice in SNAPSHOT NIGHTLY DEVEL
do
case "$choice" in
	"SNAPSHOT")
		TAG="SNAPSHOT"
		break;;
	"NIGHTLY")
		TAG="NIGHTLY"
		break;;
	"DEVEL")
		TAG="DEVEL"
		break;;
esac
done

# File to be zipped.
# Example: Lambda-Kernel-MX-DEVEL-03092017.zip.
ZIPFILE="$NAME-Kernel-$FNAME-$TAG-$BUILD_DATE"

# Overlay local version from shell? Just uncomment.
#export LOCALVERSION=-$TAG
#echo ""
#echo -e ${blue}"Using the Linux tag: $LOCALVERSION."${restore}

echo ""
echo "Which toolchain you would like to use?"
select choice in Linaro-6.2 Linaro-5.3 Android-4.9 #Linaro-4.9 (This is a template, add custom choices here...)
do
case "$choice" in
	"Linaro-6.2")
		TOOLCHAIN="Linaro 6.2"
		CROSS_COMPILE="$CCACHE $TOOLCHAIN_FOLDER/aarch64-linux-gnu-6.2/bin/aarch64-linux-gnu-"
		STRIP="$TOOLCHAIN_FOLDER/aarch64-linux-gnu-6.2/bin/aarch64-linux-gnu-strip"
		break;;
	"Linaro-5.3")
		TOOLCHAIN="Linaro 5.3"
		CROSS_COMPILE="$CCACHE $TOOLCHAIN_FOLDER/aarch64-linux-gnu-5.3/bin/aarch64-linux-gnu-"
		STRIP="$TOOLCHAIN_FOLDER/aarch64-linux-gnu-5.3/bin/aarch64-linux-gnu-strip"
		break;;
	"Android-4.9")
		export TOOLCHAIN="Android 4.9"
		CROSS_COMPILE="$CCACHE $TOOLCHAIN_FOLDER/aarch64-linux-android-4.9/bin/aarch64-linux-android-"
		STRIP="$TOOLCHAIN_FOLDER/aarch64-linux-android-4.9/bin/aarch64-linux-android-strip"
		break;;
	#
	# Template:
	# This is a template for any other GCC compiler you'd like to use. Just put
	# the compiler in a given folder under toolchains directory and point it here,
	# the subfolder is used to keep the directory organized. The executables are
	# the only thing that matters, make sure you point them properly taking the
	# prefix 'arm-eabi-' as the normal executable naming for ARM 32-bit toolchains.
	#
	#"Linaro-4.9")
		#export TOOLCHAIN="Linaro 4.9"
		#export CROSS_COMPILE="$CCACHE ${TOOLCHAINS_DIR}/linaro/4.9/bin/arm-eabi-"
		#break;;
esac
done

export CROSS_COMPILE=$CROSS_COMPILE

echo ""
echo "You have chosen to use $TOOLCHAIN."
echo ""

while read -p "Are you ready to start (Y/n)? " achoice
do
case "$achoice" in
	y|Y)
		echo ""
		prepare_bacon
		echo ""
		echo -e ${blue}"Building the Kernel with $THREAD argument..."${restore}
		echo -e ${blue}"Using $TOOLCHAIN GCC toolchain..."${restore}
		echo ""
		mka_bacon
		check_kernel
		break
		;;
	n|N)
		echo ""
		echo "This can't be happening... Tell me you're OK,"
		echo "Snake! Snaaaake!"
		echo ""
		exit
		;;
	* )
		echo ""
		echo "Stop peeing yourself, coward!"
		echo ""
		;;
esac
done

if [ "$COMPILATION" = sucesss ]; then
	echo ""
	while read -p "Pack the Kernel for distribution (Y/n)? " bchoice
	do
	case "$bchoice" in
		y|Y)
			echo ""
			echo -e ${blue}"Packing..."${restore}
			echo ""
			mka_package
			echo ""
			echo -e ${blue}"Zipping..."${restore}
			echo ""
			zip_package
			break
			;;
		n|N)
			echo ""
			echo -e ${yellow}"Kernel available at out/ folder, not packed."${restore}
			break
			;;
		n|N)
			echo ""
			echo "Please, sir. I will not repeat it again!"
			;;
	esac
	done
fi;

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
if [ "$COMPILATION" = sucks ]; then
	echo -e "${blink_red}"
	echo "                 \                  "
	echo "                 /\                 "
	echo "                /  \                "
	echo "               /    \               "
	echo -e "${restore}"
	echo -e ${blink_red}"You tried your best and you failed miserably."${restore}
	echo -e ${blink_red}"The lesson is, NEVER TRY!"${restore}
else if [ "$COMPILATION" = sucesss ]; then
	echo -e "${blink_green}"
	echo "                 \                  "
	echo "                 /\                 "
	echo "                /  \                "
	echo "               /    \               "
	echo -e "${restore}"
	echo -e ${blink_green}"Completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."${restore}
fi;
fi;
