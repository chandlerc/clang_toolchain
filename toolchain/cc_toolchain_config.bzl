"""A Starlark cc_toolchain configuration rule"""

load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "feature",
    "feature_set",
    "flag_group",
    "flag_set",
    "tool",
    "tool_path",
    "variable_with_value",
    "with_feature_set",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

all_compile_actions = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.assemble,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.cpp_module_codegen,
]

all_cpp_compile_actions = [
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
    ACTION_NAMES.cpp_module_codegen,
]

preprocessor_compile_actions = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.cpp_header_parsing,
    ACTION_NAMES.cpp_module_compile,
]

codegen_compile_actions = [
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.linkstamp_compile,
    ACTION_NAMES.assemble,
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.cpp_module_codegen,
]

all_link_actions = [
    ACTION_NAMES.cpp_link_executable,
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
]

def _impl(ctx):
    # Rather than hard coding, I'd like to compute these by searching the PATH
    # for `clang`, and then the dirname of that path to compute `llvm_bindir`.
    # Then I would compute `llvm_prefix` as `llvm_bindir + "/.."`. But I don't
    # know how to get at PATH-based search for the first, and the builtin
    # includes below want the prefix to not have `/../` sequences in it which
    # would require either manually resolving them (which could be wrong but
    # preserves more symlinks) or using realpath.
    llvm_prefix = "/usr/local/google/home/chandlerc"
    llvm_bindir = llvm_prefix + "/bin"

    tool_paths = [
        tool_path(name = "ar", path = llvm_bindir + "/llvm-ar"),
        tool_path(name = "ld", path = llvm_bindir + "/ld.lld"),
        tool_path(name = "cpp", path = llvm_bindir + "/clang-cpp"),
        tool_path(name = "gcc", path = llvm_bindir + "/clang"),
        tool_path(name = "dwp", path = llvm_bindir + "/llvm-dwp"),
        tool_path(name = "gcov", path = llvm_bindir + "/llvm-cov"),
        tool_path(name = "nm", path = llvm_bindir + "/llvm-nm"),
        tool_path(name = "objcopy", path = llvm_bindir + "/llvm-objcopy"),
        tool_path(name = "objdump", path = llvm_bindir + "/llvm-objdump"),
        tool_path(name = "strip", path = llvm_bindir + "/llvm-strip"),
    ]

    action_configs = [
        action_config(action_name = name, enabled = True, tools = [tool(path = llvm_bindir + "/clang")])
        for name in [ACTION_NAMES.c_compile]
    ] + [
        # action_config(action_name = name, enabled = True, tools = [tool(path = "header_parsing_wrapper.sh")])
        action_config(action_name = name, enabled = True, tools = [tool(path = llvm_bindir + "/clang++")])
        for name in all_cpp_compile_actions
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = llvm_bindir + "/clang++")])
        for name in all_link_actions
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = llvm_bindir + "/llvm-ar")])
        for name in [ACTION_NAMES.cpp_link_static_library]
    ] + [
        action_config(action_name = name, enabled = True, tools = [tool(path = llvm_bindir + "/llvm-strip")])
        for name in [ACTION_NAMES.strip]
    ]

    default_compile_flags_feature = feature(
        name = "default_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
                flag_groups = ([
                    flag_group(
                        flags = [
                            "-Wall",
                            "-Wextra",
                            "-Wthread-safety",
                            "-Wself-assign",
                            "-fcolor-diagnostics",
                        ],
                    ),
                ]),
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_header_parsing,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["-MD", "-MF", "%{dependency_file}"],
                        expand_if_available = "dependency_file",
                    ),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_codegen,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["-frandom-seed=%{output_file}"],
                        expand_if_available = "output_file",
                    ),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_codegen,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(flags = ["-fPIC"], expand_if_available = "pic"),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["-gsplit-dwarf"],
                        expand_if_available = "per_object_debug_info_file",
                    ),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["-D%{preprocessor_defines}"],
                        iterate_over = "preprocessor_defines",
                    ),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["-include", "%{includes}"],
                        iterate_over = "includes",
                        expand_if_available = "includes",
                    ),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["-iquote", "%{quote_include_paths}"],
                        iterate_over = "quote_include_paths",
                    ),
                    flag_group(
                        flags = ["-I%{include_paths}"],
                        iterate_over = "include_paths",
                    ),
                    flag_group(
                        flags = ["-isystem", "%{system_include_paths}"],
                        iterate_over = "system_include_paths",
                    ),
                ],
            ),
            flag_set(
                actions = all_compile_actions,
                flag_groups = ([
                    flag_group(
                        flags = ["-g"],
                    ),
                ]),
                with_features = [with_feature_set(features = ["dbg"])],
            ),
            flag_set(
                actions = all_compile_actions,
                flag_groups = ([
                    flag_group(
                        flags = [
                            "-g0",
                            "-O3",
                            "-DNDEBUG",
                            "-ffunction-sections",
                            "-fdata-sections",
                            # Even when optimizing, preserve frame pointers for profiling.
                            "-fno-omit-frame-pointer",
                            "-mno-omit-leaf-frame-pointer",
                        ],
                    ),
                ]),
                with_features = [with_feature_set(features = ["opt"])],
            ),
            flag_set(
                actions = all_cpp_compile_actions,
                flag_groups = ([
                    flag_group(
                        flags = [
                            "-std=c++17",
                            "-stdlib=libc++",
                        ],
                    ),
                ]),
            ),
            flag_set(
                actions = all_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = ["%{user_compile_flags}"],
                        iterate_over = "user_compile_flags",
                        expand_if_available = "user_compile_flags",
                    ),
                ],
            ),
            flag_set(
                actions = all_compile_actions,
                flag_groups = ([
                    flag_group(
                        flags = [
                            "-no-canonical-prefixes",
                            "-Wno-builtin-macro-redefined",
                            "-D__DATE__=\"redacted\"",
                            "-D__TIMESTAMP__=\"redacted\"",
                            "-D__TIME__=\"redacted\"",
                        ],
                    ),
                ]),
            ),
            flag_set(
                actions = all_compile_actions,
                flag_groups = [
                    flag_group(
                        expand_if_available = "source_file",
                        flags = ["-c", "%{source_file}"],
                    ),
                    flag_group(
                        expand_if_available = "output_assembly_file",
                        flags = ["-S"],
                    ),
                    flag_group(
                        expand_if_available = "output_preprocess_file",
                        flags = ["-E"],
                    ),
                    flag_group(
                        expand_if_available = "output_file",
                        flags = ["-o", "%{output_file}"],
                    ),
                ],
            ),
        ],
    )

    default_link_flags_feature = feature(
        name = "default_link_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.cpp_link_dynamic_library,
                    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                ],
                flag_groups = [flag_group(flags = ["-shared"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["%{linkstamp_paths}"],
                        iterate_over = "linkstamp_paths",
                        expand_if_available = "linkstamp_paths",
                    ),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["-o", "%{output_execpath}"],
                        expand_if_available = "output_execpath",
                    ),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.cpp_link_executable,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["-pie"],
                        expand_if_available = "force_pic",
                    ),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = ([
                    flag_group(
                        flags = [
                            "-fuse-ld=lld",
                            "-Wl,-no-as-needed",
                            # Force the C++ standard library to be statically
                            # linked. This works even with libc++ despite the
                            # name, however we have to manually link the ABI
                            # library and libunwind.
                            "-static-libstdc++",
                            # Link with libc++.
                            "-stdlib=libc++",
                            # Link with Clang's runtime library. This is always
                            # linked statically.
                            #"-rtlib=compiler-rt",
                        ],
                    ),
                ]),
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["-L%{library_search_directories}"],
                        iterate_over = "library_search_directories",
                        expand_if_available = "library_search_directories",
                    ),
                ],
            ),
            flag_set(
                flag_groups = [
                    flag_group(
                        iterate_over = "runtime_library_search_directories",
                        flags = [
                            "-Wl,-rpath,$ORIGIN/%{runtime_library_search_directories}",
                        ],
                        expand_if_available =
                            "runtime_library_search_directories",
                    ),
                ],
                actions = all_link_actions,
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["-Wl,--gdb-index"],
                        expand_if_available = "is_using_fission",
                    ),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["-Wl,-S"],
                        expand_if_available = "strip_debug_symbols",
                    ),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        iterate_over = "libraries_to_link",
                        flag_groups = [
                            flag_group(
                                flags = ["-Wl,--start-lib"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                            ),
                            flag_group(
                                flags = ["-Wl,-whole-archive"],
                                expand_if_true =
                                    "libraries_to_link.is_whole_archive",
                            ),
                            flag_group(
                                flags = ["%{libraries_to_link.object_files}"],
                                iterate_over = "libraries_to_link.object_files",
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                            ),
                            flag_group(
                                flags = ["%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file",
                                ),
                            ),
                            flag_group(
                                flags = ["%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "interface_library",
                                ),
                            ),
                            flag_group(
                                flags = ["%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "static_library",
                                ),
                            ),
                            flag_group(
                                flags = ["-l%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "dynamic_library",
                                ),
                            ),
                            flag_group(
                                flags = ["-l:%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "versioned_dynamic_library",
                                ),
                            ),
                            flag_group(
                                flags = ["-Wl,-no-whole-archive"],
                                expand_if_true = "libraries_to_link.is_whole_archive",
                            ),
                            flag_group(
                                flags = ["-Wl,--end-lib"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                            ),
                        ],
                        expand_if_available = "libraries_to_link",
                    ),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["%{user_link_flags}"],
                        iterate_over = "user_link_flags",
                        expand_if_available = "user_link_flags",
                    ),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.cpp_link_static_library,
                ] + all_link_actions,
                flag_groups = [
                    flag_group(
                        expand_if_available = "linker_param_file",
                        flags = ["@%{linker_param_file}"],
                    ),
                ],
            ),
        ],
    )

    sysroot_feature = feature(
        name = "sysroot",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions + all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["--sysroot=%{sysroot}"],
                        expand_if_available = "sysroot",
                    ),
                ],
            ),
        ],
    )

    default_archiver_flags_feature = feature(
        name = "default_archiver_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.cpp_link_static_library],
                flag_groups = [
                    flag_group(flags = ["rcsD"]),
                    flag_group(
                        flags = ["%{output_execpath}"],
                        expand_if_available = "output_execpath",
                    ),
                ],
            ),
            flag_set(
                actions = [ACTION_NAMES.cpp_link_static_library],
                flag_groups = [
                    flag_group(
                        iterate_over = "libraries_to_link",
                        flag_groups = [
                            flag_group(
                                flags = ["%{libraries_to_link.name}"],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file",
                                ),
                            ),
                            flag_group(
                                flags = ["%{libraries_to_link.object_files}"],
                                iterate_over = "libraries_to_link.object_files",
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                            ),
                        ],
                        expand_if_available = "libraries_to_link",
                    ),
                ],
            ),
        ],
    )

    use_module_maps = feature(
        name = "use_module_maps",
        requires = [feature_set(features = ["module_maps"])],
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.Cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    # These flag groups are separate so they do not expand to
                    # the cross product of the variables.
                    flag_group(flags = ["-fmodule-name=%{module_name}"]),
                    flag_group(
                        flags = ["-fmodule-map-file=%{module_map_file}"],
                    ),
                ],
            ),
        ],
    )

    # Tell bazel we support module maps in general, so they will be generated
    # for all c/c++ rules.
    # Note: not all C++ rules support module maps; thus, do not imply this
    # feature from other features - instead, require it.
    module_maps = feature(
        name = "module_maps",
        enabled = True,
        implies = [
            # "module_map_home_cwd",
            # "module_map_without_extern_module",
            # "generate_submodules",
        ],
    )

    layering_check = feature(
        name = "layering_check",
        implies = ["use_module_maps"],
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(flags = [
                        "-fmodules-strict-decluse",
                        "-Wprivate-header",
                    ]),
                    flag_group(
                        iterate_over = "dependent_module_map_files",
                        flags = [
                            "-fmodule-map-file=%{dependent_module_map_files}",
                        ],
                    ),
                ],
            ),
        ],
    )
    fuzzer = feature(
        name = "fuzzer",
        flag_sets = [
            flag_set(
                actions = all_compile_actions + all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["-fsanitize=fuzzer,address"],
                    ),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = ([
                    flag_group(
                        flags = [
                            "-static-libsan",
                        ],
                    ),
                ]),
            ),
        ],
    )

    features = [
        feature(
            name = "no_legacy_features",
        ),
        feature(
            name = "supports_pic",
            enabled = True,
        ),
        feature(
            name = "supports_start_end_lib",
            enabled = True,
        ),
        default_compile_flags_feature,
        default_archiver_flags_feature,
        default_link_flags_feature,
        feature(name = "supports_dynamic_linker", enabled = True),
        feature(name = "dbg"),
        feature(name = "opt"),
        sysroot_feature,
        fuzzer,
        module_maps,
        layering_check,
        use_module_maps,
    ]

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        action_configs = action_configs,
        cxx_builtin_include_directories = [
            llvm_prefix + "/lib64/clang/11.0.0/include",
            llvm_prefix + "/include/c++/v1",
            llvm_prefix + "/include",
            "/usr/local/include",
            "/usr/include/x86_64-linux-gnu",
            "/usr/include",
            llvm_prefix + "/lib64/clang/11.0.0/share/asan_blacklist.txt",
        ],
        toolchain_identifier = "local",
        host_system_name = "local",
        target_system_name = "local",
        target_cpu = "k8",
        target_libc = "local",
        compiler = "local",
        abi_version = "local",
        abi_libc_version = "local",
        tool_paths = tool_paths,
    )

cc_toolchain_config = rule(
    implementation = _impl,
    provides = [CcToolchainConfigInfo],
)
