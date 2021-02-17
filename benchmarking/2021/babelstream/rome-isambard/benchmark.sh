#!/bin/bash

set -eu
DEFAULT_COMPILER=gcc-9.1
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run|run-large [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  gcc-9.1"
  echo "  intel-2020"
  echo "  aocc-2.1"
  echo "  pgi-19.10" 
  echo "  hipsycl"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos"
  echo "  sycl"
  echo "  ocl"
  echo
  echo "The default configuration is '$DEFAULT_COMPILER'."
  echo "The default programming model is '$DEFAULT_MODEL'."
  echo
}

# Process arguments
if [ $# -lt 1 ]; then
  usage
  exit 1
fi

ACTION=$1
COMPILER=${2:-$DEFAULT_COMPILER}
MODEL=${3:-$DEFAULT_MODEL}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export CONFIG="rome"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
case "$COMPILER" in
  cce-10.0)
    module load PrgEnv-cray
    module swap cce cce/10.0.0
    module swap craype-{broadwell,x86-rome}
    MAKE_OPTS="COMPILER=CRAY TARGET=CPU EXTRA_FLAGS='-march=znver2'"
    ;;
  gcc-10.2)
    module load gcc/10.2.0
    MAKE_OPTS="COMPILER=GNU TARGET=CPU EXTRA_FLAGS='-march=znver2'"
    ;;
  llvm-11.0)
    module load llvm/11.0
    MAKE_OPTS="COMPILER=CLANG TARGET=CPU EXTRA_FLAGS='-march=znver2'"
    ;;
  oneapi-2021.1)
    module load gcc/10.2.0
    loadOneAPI /lustre/projects/bristol/modules/intel/oneapi/2021.1/setvars.sh
    MAKE_OPTS="COMPILER=GNU"
    ;;
  *)
    echo
    echo "Invalid compiler '$COMPILER'."
    exit 1
    ;;
esac
export MODEL="$MODEL"
# Handle actions
if [ "$ACTION" == "build" ]; then

  # Fetch source code
  fetch_src

  # Perform build
  rm -f $RUN_DIR/$BENCHMARK_EXE

  # Select Makefile to use
  case "$MODEL" in
  omp)
    MAKE_FILE="OpenMP.make"
    BINARY="omp-stream"
    ;;
  kokkos)
    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=EPYC DEVICE=OpenMP"
    ;;
  ocl)
    CL_HEADER_DIR="$PWD/OpenCL-Headers-2020.06.16"
    # XXX BabelStream should really just ship with CL headers
    if [ ! -d "$CL_HEADER_DIR" ]; then
      wget https://github.com/KhronosGroup/OpenCL-Headers/archive/v2020.06.16.tar.gz
      tar -xf v2020.06.16.tar.gz
    fi
    MAKE_OPTS+=" EXTRA_FLAGS='-I$CL_HEADER_DIR'"
    MAKE_FILE="OpenCL.make"
    BINARY="ocl-stream"
    ;;
  *)
    echo
    echo "Invalid model '$MODEL'."
    exit 1
    ;;
  esac

  if ! eval make -f $MAKE_FILE -C $SRC_DIR -B $MAKE_OPTS -j $(nproc); then
    echo
    echo "Build failed."
    echo
    exit 1
  fi

  # Rename binary
  mkdir -p $RUN_DIR
  mv $SRC_DIR/$BINARY $RUN_DIR/$BENCHMARK_EXE

elif [ "$ACTION" == "run" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o BabelStream-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run.job
elif [ "$ACTION" == "run-large" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o BabelStream-large-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run-large.job
else
  echo
  echo "Invalid action"
  usage
  exit 1
fi
