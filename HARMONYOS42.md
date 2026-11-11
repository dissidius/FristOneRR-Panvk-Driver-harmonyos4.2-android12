# Huawei Kirin 990 / HarmonyOS 4.2 MEM_IMPORT compatibility

This fork tracks the *binary release repository* of FristOneRR PanVK. The
original release contains no editable driver source. **The original
v3.7.0 binary is not patched and should not be described as fixed.**

The developer's publicly available source is located at
https://github.com/FristOneRR-Admin/FristOneRR-Panvk-Source .
The patch in `patches/0001-huawei-kirin990-jm-mem-import-32.patch`
targets the following **pinned** source revision:

`efd07bab401b263a9ac114560ecdb9a2934f5d43`

It adds a 32-byte `MEM_IMPORT` ioctl fallback for legacy Huawei
job-manager kernels when the normal 24-byte request returns `ENOTTY`.
The fallback leaves CSF kernels unchanged and covers both DMA-buffer and
external host-memory import paths. This is an experimental port of the
approach confirmed in the MaliSX2 HarmonyOS fix; it is not yet tested
with the FristOneRR driver on a Kirin 990.

## Apply to source

```bash
git clone https://github.com/FristOneRR-Admin/FristOneRR-Panvk-Source.git
cd FristOneRR-Panvk-Source
git checkout efd07bab401b263a9ac114560ecdb9a2934f5d43
curl -L https://raw.githubusercontent.com/dissidius/FristOneRR-Panvk-Driver-harmonyos4.2-android12/main/patches/0001-huawei-kirin990-jm-mem-import-32.patch -o huawei.patch
git apply --check huawei.patch
git apply huawei.patch
```

The `Verify Huawei Kirin 990 source patch` workflow checks that this
patch applies cleanly. **It does not compile an Android driver ZIP.**
A source build and testing on HarmonyOS 4.2 are still required, using
the corresponding Android configuration and toolchain. Do not install
unrelated Linux/aarch64 release artifacts as Android drivers.
