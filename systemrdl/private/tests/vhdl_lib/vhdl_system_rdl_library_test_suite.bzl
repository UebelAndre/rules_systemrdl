"""Starlark tests for `vhdl_system_rdl_library`."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_verilog//verilog:verilog_library.bzl", "verilog_library")
load("@rules_vhdl//vhdl:vhdl_info.bzl", "VhdlInfo")
load("@rules_vhdl//vhdl:vhdl_library.bzl", "vhdl_library")
load("//systemrdl:vhdl_system_rdl_library.bzl", "vhdl_system_rdl_library")

# The registered test toolchain in this repo only declares the `regblock`
# exporter, so these analysis tests point `vhdl_system_rdl_library` at it
# via the `exporter` attr. The wrapping into `VhdlInfo` (library / standard /
# deps handling) is exporter-agnostic, so this exercises the same code path
# that a `regblock-vhdl`-registered toolchain would.

def _vhdl_provider_test_impl(ctx):
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)
    vhdl = target[VhdlInfo]

    asserts.equals(env, [], vhdl.data.to_list(), "data should be empty")
    asserts.equals(env, [], vhdl.deps.to_list(), "deps should be empty")
    asserts.equals(env, "", vhdl.top_entity, "top_entity should be empty")
    asserts.equals(env, "atxmega_spi", vhdl.library, "library should default to `label.name` of `lib`")
    asserts.equals(env, "", vhdl.standard, "standard should default to the empty string")

    return analysistest.end(env)

vhdl_system_rdl_library_provider_test = analysistest.make(
    _vhdl_provider_test_impl,
)

def _vhdl_explicit_library_test_impl(ctx):
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)
    vhdl = target[VhdlInfo]

    asserts.equals(env, "custom_lib_name", vhdl.library, "explicit `library` attr should be forwarded to `VhdlInfo.library`")
    asserts.equals(env, "2008", vhdl.standard, "explicit `standard` attr should be forwarded to `VhdlInfo.standard`")

    return analysistest.end(env)

vhdl_system_rdl_library_explicit_library_test = analysistest.make(
    _vhdl_explicit_library_test_impl,
)

def _vhdl_transitive_verilog_deps_test_impl(ctx):
    env = analysistest.begin(ctx)

    target = analysistest.target_under_test(env)
    vhdl = target[VhdlInfo]

    # `VerilogInfo` doesn't carry a label; identify each entry via the srcs it exposes.
    verilog_src_basenames = []
    for entry in vhdl.verilog_deps.to_list():
        verilog_src_basenames.extend([f.basename for f in entry.srcs.to_list()])

    asserts.true(
        env,
        "leaf_verilog.v" in verilog_src_basenames,
        "expected transitive `verilog_deps` to include the leaf Verilog library src, found `{}`".format(verilog_src_basenames),
    )

    return analysistest.end(env)

vhdl_system_rdl_library_transitive_verilog_deps_test = analysistest.make(
    _vhdl_transitive_verilog_deps_test_impl,
)

def vhdl_system_rdl_library_test_suite(*, name, **kwargs):
    """Entry point for `vhdl_system_rdl_library` analysis tests.

    Args:
        name: The name of the generated `test_suite`.
        **kwargs: Additional keyword arguments forwarded to `test_suite`.
    """
    vhdl_system_rdl_library(
        name = "atxmega_spi_lib",
        exporter = "regblock",
        lib = "//systemrdl/private/tests/simple:atxmega_spi",
    )

    vhdl_system_rdl_library_provider_test(
        name = "vhdl_system_rdl_library_provider_test",
        target_under_test = ":atxmega_spi_lib",
    )

    vhdl_system_rdl_library(
        name = "atxmega_spi_lib_explicit",
        exporter = "regblock",
        lib = "//systemrdl/private/tests/simple:atxmega_spi",
        library = "custom_lib_name",
        standard = "2008",
    )

    vhdl_system_rdl_library_explicit_library_test(
        name = "vhdl_system_rdl_library_explicit_library_test",
        target_under_test = ":atxmega_spi_lib_explicit",
    )

    # A vhdl_system_rdl_library dep chain that transitively pulls in a
    # Verilog library via `vhdl_library.verilog_deps` — the test asserts
    # the rule re-exposes that Verilog entry on its own
    # `VhdlInfo.verilog_deps`.
    verilog_library(
        name = "leaf_verilog",
        srcs = ["leaf_verilog.v"],
    )

    vhdl_library(
        name = "mid_vhdl_with_verilog_dep",
        verilog_deps = [":leaf_verilog"],
    )

    vhdl_system_rdl_library(
        name = "atxmega_spi_lib_with_transitive_verilog_dep",
        exporter = "regblock",
        lib = "//systemrdl/private/tests/simple:atxmega_spi",
        deps = [":mid_vhdl_with_verilog_dep"],
    )

    vhdl_system_rdl_library_transitive_verilog_deps_test(
        name = "vhdl_system_rdl_library_transitive_verilog_deps_test",
        target_under_test = ":atxmega_spi_lib_with_transitive_verilog_dep",
    )

    native.test_suite(
        name = name,
        tests = [
            ":vhdl_system_rdl_library_provider_test",
            ":vhdl_system_rdl_library_explicit_library_test",
            ":vhdl_system_rdl_library_transitive_verilog_deps_test",
        ],
        **kwargs
    )
