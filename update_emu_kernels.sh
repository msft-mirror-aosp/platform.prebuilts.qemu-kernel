#!/bin/bash
set -e

manual_mode=false

if [ $# == 1 ] && [ $1 == '-m' ]
then
	manual_mode=true
elif [ $# != 0 ]
then
	echo  Usage: $0 [-m]
	echo "   -m: manually specify build numbers"
	exit 1
fi

fetchtool='sso_client --location --request_timeout 60 --url'
build_server='https://android-build-uber.corp.google.com'
branch_prefix='kernel-n-dev-android-goldfish-'

# kernel_img[branch]="build_server_output local_file_name"
declare -A kernel_img

kernel_img[3.4-arm]="zImage arm/kernel-qemu-armv7"
kernel_img[3.4-mips]="vmlinux mips/kernel-qemu"
kernel_img[3.4-x86]="bzImage x86/kernel-qemu"
kernel_img[3.10-arm]="zImage arm/ranchu/kernel-qemu"
kernel_img[3.10-arm64]="Image arm64/kernel-qemu"
kernel_img[3.10-mips]="vmlinux mips/ranchu/kernel-qemu"
kernel_img[3.10-mips64]="vmlinux mips64/kernel-qemu"
kernel_img[3.10-x86]="bzImage x86/ranchu/kernel-qemu"
kernel_img[3.10-x86_64]="bzImage x86_64/ranchu/kernel-qemu"
kernel_img[3.10-x86_64-qemu1]="bzImage x86_64/kernel-qemu"

printf "Upgrade emulator kernels\n\n" > emu_kernel.commitmsg

for key in "${!kernel_img[@]}"
do
	branch=$branch_prefix$key
	branch_url=$build_server/builds/$branch-linux-kernel

	# Find the latest build by searching for highest build number since
	# build server doesn't provide the "latest" link.
	build=`$fetchtool $branch_url | \
			sed -rn "s/<li><a href=".*">([0-9]+)<\/a><\/li>/\1/p" | \
			sort -nr | head -n 1`

	if $manual_mode
	then
		read -p "Enter build number for $branch: [$build]" input
		build="${input:-$build}"
	fi

	echo Fetching build $build from branch $branch

	# file_info[0] - kernel image on build server
	# file_info[1] - kernel image in local tree
	file_info=(${kernel_img[$key]})

	$fetchtool $branch_url/$build/${file_info[0]} > ${file_info[1]}

	git add ${file_info[1]}

	printf "$branch - build: $build\n" >> emu_kernel.commitmsg
done

last_3_4_commit=`git log | \
	sed -rn "s/.*Upgrade 3.4 kernel images to ([a-z0-9]+).*/\1/p" | \
	head -n 1`

last_3_10_commit=`git log | \
	sed -rn "s/.*Upgrade 3.10 kernel images to ([a-z0-9]+).*/\1/p" | \
	head -n 1`

if [ ! -d goldfish_cache ]
then
	mkdir goldfish_cache
	git clone https://android.googlesource.com/kernel/goldfish goldfish_cache
fi

pushd goldfish_cache

git fetch origin

git checkout remotes/origin/android-goldfish-3.4
tot_3_4_commit=`git log --oneline -1 | cut -d' ' -f1`
printf "\nUpgrade 3.4 kernel images to ${tot_3_4_commit}\n" >> ../emu_kernel.commitmsg
git log --oneline HEAD...${last_3_4_commit} >> ../emu_kernel.commitmsg

git checkout remotes/origin/android-goldfish-3.10
tot_3_10_commit=`git log --oneline -1 | cut -d' ' -f1`
printf "\nUpgrade 3.10 kernel images to ${tot_3_10_commit}\n" >> ../emu_kernel.commitmsg
git log --oneline HEAD...${last_3_10_commit} >> ../emu_kernel.commitmsg

popd

git commit -t emu_kernel.commitmsg

rm emu_kernel.commitmsg

