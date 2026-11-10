# 相对上一份交接包的增量

真机已经用合法调试签名安装并启动了 `com.hm.element.sdkdiag`。点击初始化后 `Index.ets:42` 报 `Cannot read property openEncryptedStore of undefined`，`import native from 'libhm_sdk_diag.so'` 得到 undefined。当时没有 `openEncryptedStore` 返回码，不能把原生加载或加密库打开算通过。签名 HAP 的 SHA-256 是 `bf4f6586c45e31414b56553c6e20cd075157de0b64fbf744ae76e8e89ff663d8`。

## 云端查到的两个缺口

模块名本身是对齐的：so 里有字符串 `hm_sdk_diag`，导出 `hm_sdk_diag_register`，并带 `.init_array`。导入名 `libhm_sdk_diag.so` 与官方规则一致。

上一份包有两处和官方加载约定不符，都会让这次 import 变成 undefined：

1. `entry/oh-package.json5` 的 `dependencies` 是空的，没有 `"libhm_sdk_diag.so": "file:./src/main/cpp/types/libhm_sdk_diag"`。官方说明要在模块的 oh-package 里声明这个 file 依赖后，ArkTS 的 `import ... from 'libhm_sdk_diag.so'` 才会绑到 NAPI 模块。
2. 旧的 `libhm_sdk_diag.so` 是 C++，`DT_NEEDED` 含 `libc++_shared.so`，而交接包按约定没有塞入 OpenHarmony 的那份库。依赖 so 没进包时，加载失败同样表现为 import undefined。现场报告只确认了两个自带 so 在 HAP 里，没有 dlopen 日志，所以不能断定是哪一条先触发。

这次同时补上这两处。新的 `libhm_sdk_diag.so` 用 C 重链，动态依赖只剩 `libohos_min_bridge.so`、`libace_napi.z.so`、`libc.so`。`check-libcxx.sh` 会把 `memcpy`/`memset` 标成 libc，不再要求它们出现在 `libc++_shared.so` 里，并优先使用 `llvm-readelf` / `llvm-nm`。

云端脚本 `scripts/check-native-module.sh` 在修改前失败、修改后通过。它没有执行 ArkTS，不能代替真机。

## 怎么更新本机目录

本机目录是 `/Users/bigbear/Developer/hm-element-p0-diag/hm-sdk-diag-handoff/hap-diag`。只覆盖下面这些文件，不要整目录替换：

- `entry/oh-package.json5`
- `entry/libs/arm64-v8a/libhm_sdk_diag.so`
- `entry/src/main/cpp/napi_sdk_diag.c`
- 删除不再使用的 `entry/src/main/cpp/napi_sdk_diag.cpp`
- 上级 `scripts/check-libcxx.sh` 和 `scripts/check-native-module.sh`

不要覆盖：

- `build-profile.json5`（里面已有 SDK 字符串 `26.0.0` 和本 bundle 的调试签名）
- `hvigor/hvigor-config.json5`（已是 `modelVersion` 6.26.0）
- `local.properties`、`.p12`、`.cer`、`.p7b` 以及任何签名材料
- 其他应用的工程

覆盖后在该 `hap-diag` 目录执行一次 `ohpm install`，让 file 依赖写进锁定，再用原来的 DevEco 调试签名重新构建安装。bundle 仍是 `com.hm.element.sdkdiag`。

下一轮真机只看这个应用：返回码 0 表示测试向量能打开 SDK 加密库且错一比特的密钥被拒绝；停掉再打开仍只说明这个诊断库还在。这个 32 字节向量不是 Asset Store 密钥。没有登录和 sync，不能当成 E2EE 聊天已经通过。
