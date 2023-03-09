#!/bin/bash

SCRIPT_DIR=`dirname $0`
source "${SCRIPT_DIR}/common_tools.sh"

generate_cpp_files()
{
    exit_if_argc_ne $# 6
    local PROJECT_ROOT="$1"; shift
    local OUT_SRC_DIR="$1"; shift
    local PACKAGE_NAME="$1"; shift
    local ROOT_MESSAGE="$1"; shift
    local INPUT_PATH="$1"; shift
    local NUM_ITERATIONS="$1"; shift

    cat > "${OUT_SRC_DIR}/PerformanceTest.cpp" << EOF
#include <iomanip>
#include <fstream>
#include <sstream>
#include <google/protobuf/util/json_util.h>

#include "${PACKAGE_NAME}.pb.h"

#if defined(_WIN32) || defined(_WIN64)
#   include <windows.h>
#else
#   include <time.h>
#endif

class PerfTimer
{
public:
    static uint64_t getMicroTime()
    {
#if defined(_WIN32) || defined(_WIN64)
        FILETIME creation, exit, kernelTime, userTime;
        GetThreadTimes(GetCurrentThread(), &creation, &exit, &kernelTime, &userTime);
        return fileTimeToMicro(kernelTime) + fileTimeToMicro(userTime);
#else
        struct timespec ts;
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts);
        return static_cast<uint64_t>(ts.tv_sec) * 1000000 + static_cast<uint64_t>(ts.tv_nsec) / 1000;
#endif
    }

private:
#if defined(_WIN32) || defined(_WIN64)
    static uint64_t fileTimeToMicro(const FILETIME& time)
    {
        uint64_t value = time.dwHighDateTime;
        value <<= 8 * sizeof(time.dwHighDateTime);
        value |= static_cast<uint64_t>(time.dwLowDateTime);
        value /= 10;

        return value;
    }
#endif
};

int main(int argc, char* argv[])
{
    if (argc < 2)
    {
        std::cerr << "No enough arguments!" << std::endl;
        std::cerr << "Usage: " << argv[0] << " jsonFile.json [NUM_ITERATIONS]" << std::endl;
        return 1;
    }

    const char* jsonFileName = argv[1];
    size_t numIterations = $NUM_ITERATIONS;
    if (argc > 2)
    {
        int num = atoi(argv[3]);
        if (num <= 0)
        {
            std::cerr << "Number of iterations must be greater than 0 (" << num << ")!" << std::endl;
            return 1;
        }
        numIterations = static_cast<size_t>(num);
    }

    std::ifstream jsonFile(jsonFileName);
    if (!jsonFile)
    {
        std::cerr << "Failed to read JSON file!" << std::endl;
        return 1;
    }

    std::stringstream jsonString;
    jsonString << jsonFile.rdbuf();

    ${PACKAGE_NAME}::${ROOT_MESSAGE} message;

    auto status = google::protobuf::util::JsonStringToMessage(jsonString.str(), &message);
    if (!status.ok())
    {
        std::cerr << "Failed to initialize message with JSON data!" << std::endl;
        std::cerr << status << std::endl;
        return 1;
    }

    std::string messageData;
    message.SerializeToString(&messageData);

    std::vector<${PACKAGE_NAME}::${ROOT_MESSAGE}> messages;
    messages.resize(numIterations);

    const uint64_t start = PerfTimer::getMicroTime();
    for (size_t i = 0; i < numIterations; ++i)
    {
        messages[i].ParseFromString(messageData);
    }
    const uint64_t stop = PerfTimer::getMicroTime();

    const double totalDuration = static_cast<double>(stop - start) / 1000.;
    const double stepDuration = totalDuration / static_cast<double>(numIterations);
    const double kbSize = static_cast<double>(messageData.size()) / 1000.;

    std::cout << std::fixed << std::setprecision(3);
    std::cout << "Total Duration: " << totalDuration << "ms" << std::endl;
    std::cout << "Iterations:     " << numIterations << std::endl;
    std::cout << "Step Duration:  " << stepDuration << "ms" << std::endl;
    std::cout << "Blob Size:      " << kbSize << "kB" << std::endl;

    // write results to file
    std::ofstream logFile("PerformanceTest.log");
    logFile << std::fixed << std::setprecision(3);
    logFile << totalDuration << "ms " << numIterations << " " << stepDuration << "ms " << kbSize << "kB";

    // serialize to binary file for further analysis
    std::ofstream ofs("${PACKAGE_NAME}.blob", std::ios_base::binary);
    message.SerializeToOstream(&ofs);

    return 0;
}

EOF

    # use host paths in generated files
    local DISABLE_SLASHES_CONVERSION=1
    posix_to_host_path "${PROJECT_ROOT}" HOST_PROJECT_ROOT ${DISABLE_SLASHES_CONVERSION}
    posix_to_host_path "${INPUT_PATH}" HOST_INPUT_PATH ${DISABLE_SLASHES_CONVERSION}

    cat > "${OUT_SRC_DIR}/CMakeLists.txt" << EOF
cmake_minimum_required(VERSION 3.1.0)
project(PerformanceTest)

enable_testing()

set(PROJECT_ROOT "${HOST_PROJECT_ROOT}" CACHE PATH "")
set(CMAKE_MODULE_PATH "\${PROJECT_ROOT}/cmake")
set(INPUT_PATH "${HOST_INPUT_PATH}")

# find Protobuf
find_package(Protobuf REQUIRED)

# cmake helpers
include(cmake_utils)

# setup compiler
include(compiler_utils)
compiler_set_static_clibs()
compiler_set_warnings()

file(GLOB_RECURSE SOURCES RELATIVE "\${CMAKE_CURRENT_SOURCE_DIR}" "gen/*.cc" "gen/*.h")

add_executable(\${PROJECT_NAME} PerformanceTest.cpp \${SOURCES})

target_include_directories(\${PROJECT_NAME} PUBLIC
        "\${CMAKE_CURRENT_SOURCE_DIR}/gen"
        "\${PROTOBUF_INCLUDE_DIRS}")
target_link_libraries(\${PROJECT_NAME} \${PROTOBUF_LIBRARIES})

add_test(NAME PerformanceTest COMMAND \${PROJECT_NAME} \${INPUT_PATH})
EOF
}

cpp_perf_test()
{
    exit_if_argc_ne $# 10
    local PROJECT_ROOT="$1"; shift
    local OUT_DIR="$1"; shift
    local BENCHMARK_DIR="$1"; shift
    local BENCHMARK_PROTO="$1"; shift
    local MSYS_WORKAROUND_TEMP=("${!1}"); shift
    local CPP_TARGETS=("${MSYS_WORKAROUND_TEMP[@]}")
    local PACKAGE_NAME="$1"; shift
    local ROOT_MESSAGE="$1"; shift
    local DATASET="$1"; shift
    local NUM_ITERATIONS="$1"; shift
    local SWITCH_RUN_ONLY="$1"; shift

    local OUT_SRC_DIR="${OUT_DIR}/src"
    mkdir -p "${OUT_SRC_DIR}"

    if [[ ${SWITCH_RUN_ONLY} == 0 ]] ; then
        # generate Protocol Buffers API
        mkdir -p "${OUT_SRC_DIR}/gen"
        "${PROTOC}" --cpp_out="${OUT_SRC_DIR}/gen" --proto_path="${BENCHMARK_DIR}" "${BENCHMARK_PROTO}"
        if [ $? -ne 0 ] ; then
            stderr_echo "Failed to run Protocol Buffers compiler!"
            return 1
        fi

        # generate source files
        generate_cpp_files "${PROJECT_ROOT}" "${OUT_SRC_DIR}" "${PACKAGE_NAME}" "${ROOT_MESSAGE}" \
                           "${DATASET}" ${NUM_ITERATIONS}
    fi

    # compile all and test it
    local CMAKE_ARGS=()
    local CTEST_ARGS=("--verbose")
    compile_cpp "${PROJECT_ROOT}" "${OUT_DIR}" "${OUT_SRC_DIR}" CPP_TARGETS[@] CMAKE_ARGS[@] CTEST_ARGS[@] "all"
    if [ $? -ne 0 ] ; then
        return 1
    fi

    return 0
}

# Run a single benchmark with a single dataset.
run_benchmark()
{
    exit_if_argc_ne $# 9
    local PROJECT_ROOT="$1"; shift
    local BENCHMARKS_SRC_DIR="$1"; shift
    local BENCHMARKS_OUT_DIR="$1"; shift
    local BENCHMARK="$1"; shift
    local DATASET="$1"; shift
    local MSYS_WORKAROUND_TEMP=("${!1}"); shift
    local CPP_TARGETS=("${MSYS_WORKAROUND_TEMP[@]}")
    local NUM_ITERATIONS="$1"; shift
    local SWITCH_RUN_ONLY="$1"; shift
    local LOG_FILE="$1"; shift

    local BENCHMARK_DIR="${BENCHMARK%/*}"
    local BENCHMARK_PROTO="${BENCHMARK##*/}"
    local PACKAGE_NAME="${BENCHMARK_PROTO%.*}"
    local DATASET_FILENAME="${DATASET##*/}"
    local DATASET_NAME="${DATASET_FILENAME%.*}"

    local FIRST_MESSAGE
    FIRST_MESSAGE=$(grep -m 1 -w "message" "${BENCHMARKS_SRC_DIR}/${BENCHMARK}" | cut -d\  -f2)
    if [ $? -ne 0 ] ; then
        stderr_echo "Failed to get the root object (first struct)!"
        return 1
    fi

    local TEST_OUT_DIR="${BENCHMARKS_OUT_DIR}/${PACKAGE_NAME}_${DATASET_NAME}"

    if [[ ${#CPP_TARGETS[@]} != 0 ]] ; then
        cpp_perf_test "${PROJECT_ROOT}" "${TEST_OUT_DIR}/cpp" \
                      "${BENCHMARKS_SRC_DIR}/${BENCHMARK_DIR}" "${BENCHMARK_PROTO}" CPP_TARGETS[@] \
                      ${PACKAGE_NAME} ${FIRST_MESSAGE} "${DATASET}" ${NUM_ITERATIONS} ${SWITCH_RUN_ONLY}
        if [ $? -ne 0 ] ; then
            return 1
        fi

        local BLOBS=($("${FIND}" "${TEST_OUT_DIR}/cpp" -iname "${PACKAGE_NAME}.blob"))
        if [ ${#BLOBS[@]} -eq 0 ] ; then
            stderr_echo "Failed to find blobs created by performance test!"
            return 1
        fi
        local BLOB=${BLOBS[0]} # all blobs are same
        local ZIP_FILE=${BLOB/%blob/zip}
        "${ZIP}" "${ZIP_FILE}" "${BLOB}" > /dev/null
        if [ $? -ne 0 ] ; then
            stderr_echo "Failed to zip blob created by performance test!"
            return 1
        fi
        local ZIP_SIZE="$(du --block-size=1000 ${ZIP_FILE} | cut -f1)kB"

        local LOGS=($("${FIND}" "${TEST_OUT_DIR}/cpp" -iname "PerformanceTest.log"))
        local TARGET
        for LOG in ${LOGS[@]} ; do
            TARGET="${LOG#"${TEST_OUT_DIR}/cpp/"}"
            TARGET="C++ (${TARGET%%/*})"
            RESULTS=($(cat ${LOG}))
            printf "| %-22s | %-22s | %-22s | %10s | %10s | %10s | %10s | %10s |\n" \
                    "${BENCHMARK_PROTO}" "${DATASET_FILENAME}" "${TARGET}" \
                    ${RESULTS[0]} ${RESULTS[1]} ${RESULTS[2]} ${RESULTS[3]} "${ZIP_SIZE}" >> "${LOG_FILE}"
        done
    fi

    return 0
}

# Run requested benchmarks with all available datasets.
run_benchmarks()
{
    exit_if_argc_ne $# 8
    local PROJECT_ROOT="$1"; shift
    local BENCHMARKS_SRC_DIR="$1"; shift
    local BENCHMARKS_OUT_DIR="$1"; shift
    local MSYS_WORKAROUND_TEMP=("${!1}"); shift
    local BENCHMARKS=("${MSYS_WORKAROUND_TEMP[@]}")
    local DATASETS_DIR="$1"; shift
    local MSYS_WORKAROUND_TEMP=("${!1}"); shift
    local CPP_TARGETS=("${MSYS_WORKAROUND_TEMP[@]}")
    local NUM_ITERATIONS="$1"; shift
    local SWITCH_RUN_ONLY="$1"; shift

    local LOG_FILE="${BENCHMARKS_OUT_DIR}/benchmarks.log"
    rm -f ${LOG_FILE}
    printf "| %-22s | %-22s | %-22s | %10s | %10s | %10s | %10s | %10s |\n" \
           "Benchmark" "Dataset" "Target" "Total Time" "Iterations" "Step Time" "Blob Size" "Zip Size" >> \
           "${LOG_FILE}"
    printf "| %-22s | %-22s | %-22s | %10s | %10s | %10s | %10s | %10s |\n" \
            "$(for i in {1..22} ; do echo -n "-" ; done)" \
            "$(for i in {1..22} ; do echo -n "-" ; done)" \
            "$(for i in {1..22} ; do echo -n "-" ; done)" \
            "$(for i in {1..10} ; do echo -n "-" ; done)" \
            "$(for i in {1..10} ; do echo -n "-" ; done)" \
            "$(for i in {1..10} ; do echo -n "-" ; done)" \
            "$(for i in {1..10} ; do echo -n "-" ; done)" \
            "$(for i in {1..10} ; do echo -n "-" ; done)" >> "${LOG_FILE}"

    if [[ ! -d "${DATASETS_DIR}" ]] ; then
        stderr_echo "Datasets dir '${DATASETS_DIR}' does not exists!"
        return 1
    fi

    local DATASETS
    for BENCHMARK in ${BENCHMARKS[@]} ; do
        local DATASETS=($("${FIND}" "${DATASETS_DIR}/${BENCHMARK%/*}" -iname "*.json" ! -iname "*.schema.*"))
        if [[ ${#DATASETS[@]} == 0 ]] ; then
            stderr_echo "No datasets found for the benchmark '${BENCHMARK}'!"
            return 1
        fi

        for DATASET in ${DATASETS[@]} ; do
            run_benchmark "${PROJECT_ROOT}" "${BENCHMARKS_SRC_DIR}" "${BENCHMARKS_OUT_DIR}" "${BENCHMARK}" \
                          "${DATASET}" CPP_TARGETS[@] ${NUM_ITERATIONS} ${SWITCH_RUN_ONLY} ${LOG_FILE}
            if [[ $? -ne 0 ]] ; then
                stderr_echo "Benchmark ${BENCHMARK_DIR} failed!"
                return 1
            fi
        done
    done

    echo
    cat "${LOG_FILE}"
}

# Get benchmarks to run based on the include / exclude patterns.
get_benchmarks()
{
    exit_if_argc_ne $# 3
    local BENCHMARKS_SRC_DIR="$1"; shift
    local MSYS_WORKAROUND_TEMP=("${!1}"); shift
    local PATTERNS=("${MSYS_WORKAROUND_TEMP[@]}")
    local BENCHMARKS_OUT="$1"; shift

    local FIND_EXPRESSION=()
    for i in ${!PATTERNS[@]} ; do
        FIND_EXPRESSION+=("(")
    done
    for i in ${!PATTERNS[@]} ; do
        local PATTERN="${PATTERNS[$i]}"
        if [[ $PATTERN == "i:"* ]] ; then
            PATTERN="${PATTERN#i:}"
            if [ $i -gt 0 ] ; then
                FIND_EXPRESSION+=("-o")
            fi
            FIND_EXPRESSION+=("-ipath" "${BENCHMARKS_SRC_DIR}/${PATTERN}")
        elif [[ $PATTERN == "x:"* ]] ; then
            PATTERN="${PATTERN#x:}"
            if [ $i -gt 0 ] ; then
                FIND_EXPRESSION+=("-a")
            fi
            FIND_EXPRESSION+=("!" "-ipath" "${BENCHMARKS_SRC_DIR}/${PATTERN}")
        else
            stderr_echo "Unexpected pattern!"
            return 1
        fi
        FIND_EXPRESSION+=(")")
    done

    local BENCHMARKS_ARR=(
        $("${FIND}" "${BENCHMARKS_SRC_DIR}" -mindepth 2 -maxdepth 2 -type f "${FIND_EXPRESSION[@]}" | sort)
    )

    for i in ${!BENCHMARKS_ARR[@]} ; do
        eval ${BENCHMARKS_OUT}[$i]="${BENCHMARKS_ARR[$i]#${BENCHMARKS_SRC_DIR}/}"
    done
}

# Print help message.
print_help()
{
    cat << EOF
Description:
    Runs performance tests on given zserio sources with zserio release compiled in release-ver directory.

Usage:
    $0 [-h] [-e] [-p] [-r] ][-o <dir>] [-d <dir>] [-c <config>] [-i <pattern>]... [-x <pattern>]...
            generator...

Arguments:
    -h, --help              Show this help.
    -e, --help-env          Show help for enviroment variables.
    -p, --purge             Purge test build directory.
    -r, --run-only          Run already compiled PerformanceTests again.
    -o <dir>, --output-directory <dir>
                            Output directory where tests will be run.
    -d <dir>, --datasets-directory <dir>
                            Directory containing datasets. Optional, default is "datasets" folder
                            in projet root.
    -n <num>, --num-iterations <num>
                            Number of iterations. Optional, default is 100.
    -i <pattern>, --include <pattern>
                            Include benchmarks matching the specified pattern. Can be specified multiple times.
    -x <pattern>, --exclude <pattern>
                            Exclude benchmarks matching the specified pattern. Can be specified multiple times.
    generator               Specify the generator to test.

Generator can be:
    cpp-linux32-gcc         Generate C++ sources and compile them for linux32 target (gcc).
    cpp-linux64-gcc         Generate C++ sources and compile them for for linux64 target (gcc).
    cpp-linux32-clang       Generate C++ sources and compile them for linux32 target (Clang).
    cpp-linux64-clang       Generate C++ sources and compile them for for linux64 target (Clang).
    cpp-windows64-mingw     Generate C++ sources and compile them for for windows64 target (MinGW64).
    cpp-windows64-msvc      Generate C++ sources and compile them for for windows64 target (MSVC).

Example:
    $0 cpp-linux64-gcc

EOF
}

# Parse all command line arguments.
#
# Return codes:
# -------------
# 0 - Success. Arguments have been successfully parsed.
# 1 - Failure. Some arguments are wrong or missing.
# 2 - Help switch is present. Arguments after help switch have not been checked.
# 3 - Environment help switch is present. Arguments after help switch have not been checked.
parse_arguments()
{
    exit_if_argc_lt $# 7
    local PARAM_CPP_TARGET_ARRAY_OUT="$1"; shift
    local SWITCH_OUT_DIR_OUT="$1"; shift
    local SWITCH_DATASETS_DIR_OUT="$1"; shift
    local SWITCH_NUM_ITERATIONS_OUT="$1"; shift
    local SWITCH_BENCHMARKS_PATTERN_ARRAY_OUT="$1"; shift
    local SWITCH_PURGE_OUT="$1"; shift
    local SWITCH_RUN_ONLY_OUT="$1"; shift

    eval ${SWITCH_NUM_ITERATIONS_OUT}=100
    eval ${SWITCH_PURGE_OUT}=0
    eval ${SWITCH_RUN_ONLY_OUT}=0

    local NUM_PARAMS=0
    local PARAM_ARRAY=()
    local NUM_PATTERNS=0
    local ARG="$1"
    while [ $# -ne 0 ] ; do
        case "${ARG}" in
            "-h" | "--help")
                return 2
                ;;

            "-e" | "--help-env")
                return 3
                ;;

            "-p" | "--purge")
                eval ${SWITCH_PURGE_OUT}=1
                shift
                ;;

            "-r" | "--run-only")
                eval ${SWITCH_RUN_ONLY_OUT}=1
                shift
                ;;

            "-o" | "--output-directory")
                eval ${SWITCH_OUT_DIR_OUT}="$2"
                shift 2
                ;;

            "-d" | "--datasets-directory")
                eval ${SWITCH_DATASETS_DIR_OUT}="$2"
                shift 2
                ;;

            "-n" | "--num-iterations")
                shift
                local ARG="$1"
                if [ -z "${ARG}" ] ; then
                    stderr_echo "Number of iterations is not set!"
                    echo
                    return 1
                fi
                eval ${SWITCH_NUM_ITERATIONS_OUT}="${ARG}"
                shift
                ;;

            "-i" | "--include")
                shift
                local ARG="$1"
                if [ -z "${ARG}" ] ; then
                    stderr_echo "Include pattern is not set!"
                    echo
                    return 1
                fi
                eval ${SWITCH_BENCHMARKS_PATTERN_ARRAY_OUT}[${NUM_PATTERNS}]="i:${ARG}"
                NUM_PATTERNS=$((NUM_PATTERNS + 1))
                shift
                ;;

            "-x" | "--exclude")
                shift
                local ARG="$1"
                if [ -z "${ARG}" ] ; then
                    stderr_echo "Exclude pattern is not set!"
                    echo
                    return 1
                fi
                eval ${SWITCH_BENCHMARKS_PATTERN_ARRAY_OUT}[${NUM_PATTERNS}]="x:${ARG}"
                NUM_PATTERNS=$((NUM_PATTERNS + 1))
                shift
                ;;

            "-"*)
                stderr_echo "Invalid switch '${ARG}'!"
                echo
                return 1
                ;;

            *)
                PARAM_ARRAY[NUM_PARAMS]=${ARG}
                NUM_PARAMS=$((NUM_PARAMS + 1))
                shift
                ;;
        esac
        ARG="$1"
    done

    local NUM_CPP_TARGETS=0
    for PARAM in "${PARAM_ARRAY[@]}" ; do
        case "${PARAM}" in
            "cpp-linux32-"* | "cpp-linux64-"* | "cpp-windows64-"*)
                eval ${PARAM_CPP_TARGET_ARRAY_OUT}[${NUM_CPP_TARGETS}]="${PARAM#cpp-}"
                NUM_CPP_TARGETS=$((NUM_CPP_TARGETS + 1))
                ;;

            *)
                stderr_echo "Invalid argument '${PARAM}'!"
                echo
                return 1
        esac
    done

    if [[ ${!SWITCH_PURGE_OUT} == 0 ]] ; then
        if [[ "${!SWITCH_DATASETS_DIR_OUT}" == "" ]] ; then
            stderr_echo "Datasets directory is not set!"
            echo
            return 1
        fi

        if [[ ${NUM_PARAMS} == 0 ]] ; then
            stderr_echo "No generator set!"
            echo
            return 1
        fi
    fi

    return 0
}

main()
{
    # get the project root, absolute path is necessary only for CMake
    local PROJECT_ROOT
    convert_to_absolute_path "${SCRIPT_DIR}/.." PROJECT_ROOT

    local PARAM_CPP_TARGET_ARRAY=()
    local SWITCH_OUT_DIR="${PROJECT_ROOT}"
    local SWITCH_DATASETS_DIR="${PROJECT_ROOT}"/datasets
    local SWITCH_NUM_ITERATIONS
    local SWITCH_BENCHMARKS_PATTERN_ARRAY=()
    local SWITCH_PURGE
    local SWITCH_RUN_ONLY
    parse_arguments PARAM_CPP_TARGET_ARRAY SWITCH_OUT_DIR SWITCH_DATASETS_DIR SWITCH_NUM_ITERATIONS \
                    SWITCH_BENCHMARKS_PATTERN_ARRAY SWITCH_PURGE SWITCH_RUN_ONLY "$@"
    local PARSE_RESULT=$?
    if [ ${PARSE_RESULT} -eq 2 ] ; then
        print_help
        return 0
    elif [ ${PARSE_RESULT} -eq 3 ] ; then
        print_help_env
        return 0
    elif [ ${PARSE_RESULT} -ne 0 ] ; then
        return 1
    fi

    echo "Protobuf Benchmarks by Zserio"
    echo

    convert_to_absolute_path "${SWITCH_OUT_DIR}" SWITCH_OUT_DIR

    local BUILD_DIR="${SWITCH_OUT_DIR}/build"
    local BENCHMARKS_SRC_DIR="${PROJECT_ROOT}"/benchmarks
    local BENCHMARKS_OUT_DIR="${BUILD_DIR}"/benchmarks

    if [[ ${SWITCH_PURGE} != 0 ]] ; then
        echo "Purging benchmark directory."
        echo
        rm -rf "${BENCHMARKS_OUT_DIR}/"

        if [[ ${#PARAM_CPP_TARGET_ARRAY[@]} == 0 ]] ; then
            return 0  # purge only
        fi
    fi
    mkdir -p "${BENCHMARKS_OUT_DIR}"

    set_global_common_variables
    if [ $? -ne 0 ] ; then
        return 1
    fi

    if [[ ${#PARAM_CPP_TARGET_ARRAY[@]} -ne 0 ]] ; then
        set_global_cpp_variables "${PROJECT_ROOT}"
        if [ $? -ne 0 ] ; then
            return 1
        fi
    fi

    # get benchmarks to run
    local BENCHMARKS=()
    get_benchmarks "${BENCHMARKS_SRC_DIR}" SWITCH_BENCHMARKS_PATTERN_ARRAY[@] BENCHMARKS
    if [ $? -ne 0 ] ; then
        return 1
    fi

    if [[ ${#BENCHMARKS[@]} == 0 ]] ; then
        echo "No benchmarks to run!"
        return 1
    fi

    # print information
    echo "Benchmarks output directory: ${BENCHMARKS_OUT_DIR}"
    echo "Datasets directory: ${SWITCH_DATASETS_DIR}"
    echo

    run_benchmarks "${PROJECT_ROOT}" "${BENCHMARKS_SRC_DIR}" "${BENCHMARKS_OUT_DIR}" BENCHMARKS[@] \
                   "${SWITCH_DATASETS_DIR}" PARAM_CPP_TARGET_ARRAY[@] ${SWITCH_NUM_ITERATIONS} \
                   ${SWITCH_RUN_ONLY}
    if [[ $? -ne 0 ]] ; then
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]] ; then
    main "$@"
fi
