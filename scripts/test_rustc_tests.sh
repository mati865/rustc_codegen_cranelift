#!/usr/bin/env bash
set -e

cd $(dirname "$0")/../

source ./scripts/setup_rust_fork.sh

echo "[TEST] Test suite of rustc"
pushd rust

command -v rg >/dev/null 2>&1 || cargo install ripgrep

rm -r src/test/ui/{extern/,unsized-locals/,lto/,linkage*} || true
for test in $(rg --files-with-matches "lto|// needs-asm-support|// needs-unwind" src/test/{ui,incremental}); do
  rm $test
done

for test in $(rg -i --files-with-matches "//(\[\w+\])?~[^\|]*\s*ERR|// error-pattern:|// build-fail|// run-fail|-Cllvm-args" src/test/ui); do
  rm $test
done

git checkout -- src/test/ui/issues/auxiliary/issue-3136-a.rs # contains //~ERROR, but shouldn't be removed
git checkout -- src/test/ui/proc-macro/pretty-print-hack/

# missing features
# ================

# requires stack unwinding
rm src/test/incremental/change_crate_dep_kind.rs
rm src/test/incremental/issue-80691-bad-eval-cache.rs # -Cpanic=abort causes abort instead of exit(101)

# requires compiling with -Cpanic=unwind
rm -r src/test/ui/macros/rfc-2011-nicer-assert-messages/
rm -r src/test/run-make/test-benches

# vendor intrinsics
rm src/test/ui/sse2.rs # cpuid not supported, so sse2 not detected
rm src/test/ui/intrinsics/const-eval-select-x86_64.rs # requires x86_64 vendor intrinsics
rm src/test/ui/simd/array-type.rs # "Index argument for `simd_insert` is not a constant"
rm src/test/ui/simd/intrinsic/generic-bitmask-pass.rs # simd_bitmask unimplemented
rm src/test/ui/simd/intrinsic/generic-as.rs # simd_as unimplemented
rm src/test/ui/simd/intrinsic/generic-arithmetic-saturating-pass.rs # simd_saturating_add unimplemented
rm src/test/ui/simd/intrinsic/float-math-pass.rs # simd_fcos unimplemented
rm src/test/ui/simd/intrinsic/generic-gather-pass.rs # simd_gather unimplemented
rm src/test/ui/simd/intrinsic/generic-select-pass.rs # simd_select_bitmask unimplemented
rm src/test/ui/simd/issue-85915-simd-ptrs.rs # simd_gather unimplemented
rm src/test/ui/simd/issue-89193.rs # simd_gather unimplemented
rm src/test/ui/simd/simd-bitmask.rs # simd_bitmask unimplemented

# exotic linkages
rm src/test/ui/issues/issue-33992.rs # unsupported linkages
rm src/test/incremental/hashes/function_interfaces.rs # same
rm src/test/incremental/hashes/statics.rs # same

# variadic arguments
rm src/test/ui/abi/mir/mir_codegen_calls_variadic.rs # requires float varargs
rm src/test/ui/abi/variadic-ffi.rs # requires callee side vararg support

# unsized locals
rm -r src/test/run-pass-valgrind/unsized-locals

# misc unimplemented things
rm src/test/ui/intrinsics/intrinsic-nearby.rs # unimplemented nearbyintf32 and nearbyintf64 intrinsics
rm src/test/ui/target-feature/missing-plusminus.rs # error not implemented
rm src/test/ui/fn/dyn-fn-alignment.rs # wants a 256 byte alignment
rm -r src/test/run-make/emit-named-files # requires full --emit support
rm src/test/ui/abi/stack-probes.rs # stack probes not yet implemented
rm src/test/ui/simd/intrinsic/ptr-cast.rs # simd_expose_addr intrinsic unimplemented

# optimization tests
# ==================
rm src/test/ui/codegen/issue-28950.rs # depends on stack size optimizations
rm src/test/ui/codegen/init-large-type.rs # same
rm src/test/ui/issues/issue-40883.rs # same
rm -r src/test/run-make/fmt-write-bloat/ # tests an optimization

# backend specific tests
# ======================
rm src/test/incremental/thinlto/cgu_invalidated_when_import_{added,removed}.rs # requires LLVM
rm src/test/ui/abi/stack-protector.rs # requires stack protector support

# giving different but possibly correct results
# =============================================
rm src/test/ui/mir/mir_misc_casts.rs # depends on deduplication of constants
rm src/test/ui/mir/mir_raw_fat_ptr.rs # same
rm src/test/ui/consts/issue-33537.rs # same

# doesn't work due to the way the rustc test suite is invoked.
# should work when using ./x.py test the way it is intended
# ============================================================
rm -r src/test/run-make/emit-shared-files # requires the rustdoc executable in build/bin/
rm -r src/test/run-make/unstable-flag-required # same
rm -r src/test/run-make/rustdoc-* # same
rm -r src/test/run-make/issue-88756-default-output # same
rm -r src/test/run-make/remap-path-prefix-dwarf # requires llvm-dwarfdump

# genuine bugs
# ============
rm src/test/incremental/spike-neg1.rs # errors out for some reason
rm src/test/incremental/spike-neg2.rs # same
rm src/test/ui/issues/issue-74564-if-expr-stack-overflow.rs # gives a stackoverflow before the backend runs
rm src/test/ui/mir/ssa-analysis-regression-50041.rs # produces ICE
rm src/test/ui/type-alias-impl-trait/assoc-projection-ice.rs # produces ICE

rm src/test/ui/simd/intrinsic/generic-reduction-pass.rs # simd_reduce_add_unordered doesn't accept an accumulator for integer vectors

# bugs in the test suite
# ======================
rm src/test/ui/backtrace.rs # TODO warning
rm src/test/ui/simple_global_asm.rs # TODO add needs-asm-support
rm src/test/ui/test-attrs/test-type.rs # TODO panic message on stderr. correct stdout
# not sure if this is actually a bug in the test suite, but the symbol list shows the function without leading _ for some reason
rm -r src/test/run-make/native-link-modifier-bundle
rm src/test/ui/process/nofile-limit.rs # TODO some AArch64 linking issue

rm src/test/ui/stdio-is-blocking.rs # really slow with unoptimized libstd

echo "[TEST] rustc test suite"
RUST_TEST_NOCAPTURE=1 COMPILETEST_FORCE_STAGE0=1 ./x.py test --stage 0 src/test/{codegen-units,run-make,run-pass-valgrind,ui,incremental}
popd
