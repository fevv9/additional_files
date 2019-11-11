#!/bin/bash

cmakecheck() {
  REQ=3.5
  V=`cmake --version | head -1 | awk '{print $3}'`
  echo $V
  dpkg --compare-versions $V "lt" $REQ
  if [ $? -eq 0 ]; then
    echo "ERROR: Update cmake, requre $REQ found $V"
    exit 1
  fi
}

getsrc() {
   cd $BTOP
   git clone --depth 1 https://git.llvm.org/git/llvm.git/ llvm
   git clone --depth 1 https://git.llvm.org/git/clang.git/ llvm/tools/clang
   git clone --depth 1 https://git.llvm.org/git/lld.git/ llvm/tools/lld
   git clone --depth 1 https://git.llvm.org/git/compiler-rt.git compiler-rt
}

mkllvm() {
  cd $BTOP
  mkdir -p obj-llvm
  cd obj-llvm
  cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DLLVM_DEFAULT_TARGET_TRIPLE:STRING=hexagon-unknown-linux -DCMAKE_INSTALL_PREFIX:PATH=`pwd -P`/../install ../llvm
  make -j 16 all install
}
mkcompiler_rt() {
  cd $BTOP
  T=`pwd -P`
  mkdir -p obj-crt
  cd obj-crt && \
  cmake -G 'Unix Makefiles'  \
	-DLLVM_CONFIG_PATH=../obj-llvm/bin/llvm-config \
	-DCMAKE_CROSSCOMPILING:BOOL=TRUE \
	-DCOMPILER_RT_BUILD_BUILTINS=BOOL=TRUE\
	-DCMAKE_C_COMPILER=$T/install/bin/clang \
	-DCMAKE_INSTALL_PREFIX:PATH=$T/install \
	-DCMAKE_C_COMPILER_FORCED=1 \
	-DCMAKE_CXX_COMPILER_FORCED=1 \
	-DCMAKE_SIZEOF_VOID_P=4 \
	-DCAN_TARGET_hexagon=1 \
	-DCOMPILER_RT_SUPPORTED_ARCH=hexagon \
	../compiler-rt && \
   make install-compiler-rt
}
getkernel() {
  cd $BTOP
  git clone --depth 1 git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git linux
}

configkernel() {
  cd $BTOP
  T=`pwd -P`
  cd linux &&
  make O=../obj-linux ARCH=hexagon CC=$T/install/bin/clang LD=$T/install/bin/ld.lld KBUILD_VERBOSE=1 comet_defconfig
}
mkkernel() {
  cd $BTOP
  T=`pwd -P`
  cd obj-linux &&
  make  -j 8 KBUILD_VERBOSE=1 ARCH=hexagon OBJDUMP=$T/install/bin/llvm-objdump CC=$T/install/bin/clang LD=$T/install/bin/ld.lld LIBGCC=$T/install/lib/linux/libclang_rt.builtins-hexagon.a vmlinux
}

#
# This is only needed if you don't have a recent version of cmake 
# already in your $PATH
PATH=/pkg/qct/software/cmake/3.5.2/bin:$PATH
BTOP=`pwd`
cmakecheck
getsrc
mkllvm
mkcompiler_rt
getkernel
configkernel
mkkernel
