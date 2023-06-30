#!/bin/bash

set -eu

BASE="$PWD"
ONEAPI=oneapi-2023.1
NVHPC=nvhpc-23.5
GCC=gcc-13.1
ACFL=acfl-23.04.1

ROCM=rocm-4.5.1
AOMP=aomp-16.0.3

# cloverleaf=false
# bude=true
babelstream=true

declare -A models
models["tbb"]=true
models["omp"]=true
models["cuda"]=true
models["hip"]=true
models["sycl"]=true
models["kokkos"]=true
models["std-indices"]=true
models["std-indices-dplomp"]=true

export LARGE=true

build_and_submit() { # platform, compiler, model, action, impl
    echo "[exec] build $5 $1 $2 $3 "
    "../$1/benchmark.sh" build "$2" "$3"
    echo "[exec] $5 $4 $1 $2 $3"
    "../$1/benchmark.sh" "$4" "$2" "$3"
}

bench() { # platform, compiler,  action, models...
    local impl
    impl="$(basename "$(dirname "$PWD")")"
    if [ "${!impl}" = true ]; then
        for m in "${@:4}"; do
            if [ "${models[$m]}" = true ]; then
                build_and_submit "$1" "$2" "$m" "$3" "$impl"
            fi
        done
    fi
}

bench_once() {
    # echo "No"
    bench "$1" "$2" "run" "${@:3}"
}

# bench_scale() {
#     # echo "No"
#     # bench "$1" "$2" "run" "${@:3}"
#     # bench "$1" "$2" "run-scale" "${@:3}"
# }

babelstream_gcc_cpu_models=(
    kokkos omp tbb
    std-indices
    std-indices-dplomp
)

babelstream_nvhpc_cpu_models=(
    kokkos omp
    std-indices
)

babelstream_nvhpc_gpu_models=(
    kokkos cuda omp
    std-indices
)

babelstream_aomp_gpu_models=(
    kokkos hip omp
)

babelstream_rocm_gpu_models=(
    hip # kokkos needs hipcc>= 5.2
)

generic_gcc_cpu_models=(
    kokkos omp tbb
    std-indices std-indices-dplomp
)

generic_nvhpc_cpu_models=(
    kokkos omp std-indices
)

generic_nvhpc_gpu_models=(
    kokkos cuda omp std-indices
)

case "$1" in
p3)
    cd "$BASE/babelstream/results"
    module unload cce
    # bench_once milan-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    # module load cce
    # bench_once milan-isambard $GCC "${babelstream_gcc_cpu_models[@]}"

    # bench_once a100-isambard $NVHPC "${babelstream_nvhpc_gpu_models[@]}"
    bench_once mi100-isambard $AOMP "${babelstream_aomp_gpu_models[@]}"
    # bench_once mi100-isambard $ROCM "${babelstream_rocm_gpu_models[@]}"

    # cd "$BASE/bude/results"
    # module unload cce
    # bench_once milan-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # module load cce
    # # bench_once milan-isambard $GCC "${generic_gcc_cpu_models[@]}"

    # bench_once a100-isambard $NVHPC "${generic_nvhpc_gpu_models[@]}"

    # cd "$BASE/cloverleaf/results"
    # module unload cce
    # bench_once milan-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # module load cce
    # bench_once milan-isambard $GCC "${generic_gcc_cpu_models[@]}"

    # bench_once a100-isambard $NVHPC "${generic_nvhpc_gpu_models[@]}"
    ;;
p2)
    cd "$BASE/babelstream/results"
    bench_once icl-isambard $ONEAPI "${babelstream_gcc_cpu_models[@]}"
    bench_once icl-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_once icl-isambard $GCC "${babelstream_gcc_cpu_models[@]}"

    bench_once v100-isambard $NVHPC "${babelstream_nvhpc_gpu_models[@]}"

    # cd "$BASE/bude/results"
    # # bench_once icl-isambard $ONEAPI "${generic_gcc_cpu_models[@]}"
    # bench_once icl-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # # bench_once icl-isambard $GCC "${generic_gcc_cpu_models[@]}"

    # bench_once v100-isambard $NVHPC "${generic_nvhpc_gpu_models[@]}"

    # cd "$BASE/cloverleaf/results"
    # bench_once icl-isambard $ONEAPI "${generic_gcc_cpu_models[@]}"
    # bench_once icl-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once icl-isambard $GCC "${generic_gcc_cpu_models[@]}"

    # bench_once v100-isambard $NVHPC "${generic_nvhpc_gpu_models[@]}"
    ;;

aws-g3)
    cd "$BASE/babelstream/results"
    bench_once graviton3-aws $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_once graviton3-aws $GCC "${babelstream_gcc_cpu_models[@]}"
    bench_once graviton3-aws $ACFL "${babelstream_gcc_cpu_models[@]}"

    # cd "$BASE/bude/results"
    # bench_once graviton3-aws $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # # bench_once graviton3-aws $GCC "${generic_gcc_cpu_models[@]}"
    # # bench_once graviton3-aws $ACFL "${generic_gcc_cpu_models[@]}"

    # cd "$BASE/cloverleaf/results"
    # bench_once graviton3-aws $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once graviton3-aws $GCC "${generic_gcc_cpu_models[@]}"
    # bench_once graviton3-aws $ACFL "${generic_gcc_cpu_models[@]}"
    ;;
xci)
    cd "$BASE/babelstream/results"
    bench_once tx2-isambard $NVHPC "${babelstream_nvhpc_cpu_models[@]}"
    bench_once tx2-isambard $GCC "${babelstream_gcc_cpu_models[@]}"

    # cd "$BASE/bude/results"
    # bench_once tx2-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once tx2-isambard $GCC "${generic_gcc_cpu_models[@]}"

    # cd "$BASE/cloverleaf/results"
    # bench_once tx2-isambard $NVHPC "${generic_nvhpc_cpu_models[@]}"
    # bench_once tx2-isambard $GCC "${generic_gcc_cpu_models[@]}"
    ;;
*)
    echo "Bad platform $1"
    ;;
esac

echo "All done!"
