# hm-element P0 技术实证（2026-11-09）

2026-11-10 真机：`import native from 'libhm_sdk_diag.so'` 为 undefined，`Index.ets:42` 在调用 `openEncryptedStore` 前退出。没有返回码。修正见 `AIR-UPDATE.md`。云端契约检查不能代替这台手机上的下一次点击。

这是隔离 Linux 云环境里的验证记录，不是功能开发，也不是可落地结论。P0 没有全通过。没有 HarmonyOS NEXT 真机、模拟器、DevEco Studio，也没有登录 AppGallery Connect。用户本机的 `/Users/xiangyu/开发项目/hm-element/element-x-android` 没有被改动。没有向 element-hq 推送或开 PR。

## 结论

2026-11-09 的组件探针没有被当成完整 SDK。2026-11-10 在同一 OpenHarmony 工具链上，用锁定提交 `3ff03638028fd9abf58203153722b94b4293a87a` 和原来的 `Cargo.lock`，`cargo build --locked --release --target aarch64-unknown-linux-ohos -p matrix-sdk-ffi` 已链接成功。产物是 ELF64 AArch64 的 `libmatrix_sdk_ffi.so`（146MB，SHA-256 `2bc22e2c720970d015b6f57ce0f66ce487b695ddfe4a7d446a543953c9e12a06`），动态依赖只有 `libc.so`。同一锁文件里的 `aws-lc-sys` 0.45.0 编进去了，没有改版本。

随后的 `ohos-min-bridge` 链接了 `matrix-sdk` 0.19.1 的 client、E2EE、bundled SQLite 和 `rustls-aws-lc-rs`，导出 `hm_sdk_open_encrypted_store`。NAPI 壳 `libhm_sdk_diag.so` 动态依赖这个桥。这些 `.so` 没有在鸿蒙设备或 ArkTS 运行时里执行。未签名 HAP 工程只是源码，DevEco 没有编过，也没有签名。

Element X 的 UniFFI Android 绑定不能直接当鸿蒙绑定。Rust SDK 的登录、同步、E2EE、设备验证、密钥备份、HTTP pusher API 能在源码里对上，但没有在鸿蒙上跑通过。数据库密钥的平台存储要另接 Asset Store；HUKS 里不可导出的密钥喂不进 SDK。Push Kit 的开通前提来自官方文档，不是对本账号的实测。

## 证据矩阵

| 项 | 状态 | 已实测 | 仅静态 / 未测 |
| --- | --- | --- | --- |
| 工具链 | PARTIAL | 上轮负对照仍在：无 OHOS linker 时宿主 `ld` 拒绝 AArch64。本轮完整 `matrix-sdk-ffi` 与桥都用 OpenHarmony clang 15 链成 ELF64 AArch64。 | 未在 HarmonyOS NEXT 设备或模拟器加载。没有 DevEco，没有 HDC 连接。公开 SDK 不是商用 HarmonyOS NEXT SDK。 |
| 完整 SDK 构建 | PASS（交叉链接） | `matrix-sdk-ffi` 0.19.1，`--locked`，默认 features 再加 `sentry,experimental-x509-identity-verification`。27 分 08 秒，退出码 0。符号含 `client_login`、`client_sync_service`、`client_encryption`、`client_set_pusher`、`clientbuilder_sqlite_store`、`encryption_enable_recovery`。`sqlite3_open` 在库内，没有 `sqlite3_key`。 | 未在设备上 `dlopen`。release 配置为 opt-level 2、LTO 关闭、codegen-units 16、jobs 1，用来适应这台云主机内存，不是上游默认的 opt-level 3。 |
| FFI / NAPI | PARTIAL | `libhm_sdk_diag.so` 为 ELF64 AArch64，`NEEDED libohos_min_bridge.so`、`libace_napi.z.so`、`libc++_shared.so`、`libc.so`，导出 `hm_sdk_diag_register`，引用 `hm_sdk_open_encrypted_store`。 | ArkTS 未执行。`libace_napi.z.so` 仍是链接桩。UniFFI 不生成 ArkTS。未签名 HAP 未用 DevEco 编译。 |
| E2EE 与安全存储 | PARTIAL | 桥调用锁定 SDK 的 `Client::builder().sqlite_store_with_config_and_cache_path` 和 `SqliteStoreConfig::key`，并打开 `SqliteStateStore` 与 `SqliteCryptoStore`。主机 x86_64 单测 `host_encrypted_store_rejects_wrong_key` 通过：原密钥打开，改一个比特的密钥被拒绝，返回码 0。加密仍是 SDK 的 StoreCipher。 | 这是 Linux 主机，不是鸿蒙进程，也不是设备上的 Olm 会话。没有登录、同步或 Asset Store。SQLCipher 仍是 BLOCKED。 |
| Push | NOT TESTED（送达）/ 文档为静态核对 | 无。没有 AGC、签名、Push Token、gateway 或真机。 | 官方文档描述了未上架调试路径和测试消息额度。用户所说 1000 条/天没有对照他的 AGC 项目核实。锁屏、杀进程送达未测。 |

## 1. 仓库与锁定版本

| 层 | 锁定点 | 许可证 |
| --- | --- | --- |
| 本 fork `develop` | `010fe5a25d55214a3c9c764406a67598ad4e6f5f`，与 `element-hq/element-x-android` 的 `develop` 相同。提交说明为 Merge pull request #8092。fork 上没有 hm-element 自己的提交。 | 仓库根 `LICENSE` 为 AGPL-3.0。源文件 SPDX：`AGPL-3.0-only OR LicenseRef-Element-Commercial`。公开克隆只带 AGPL；商业许可是与 Element 的另签协议，不在本仓库授权里。 |
| Android 绑定 | `org.matrix.rustcomponents:sdk-android:26.11.05`，发布 `sdk-v26.11.05`（2026-11-05）。绑定仓提交 `c1664f712bed33488b10f33232fb424faf257d49`。 | 该仓根目录没有 LICENSE 文件。绑定由 Apache-2.0 的 SDK 生成。 |
| Rust SDK | `matrix-rust-sdk` `3ff03638028fd9abf58203153722b94b4293a87a`（2026-11-05，`chore: Bump vodozemac`）。`matrix-sdk-ffi` 0.19.1。工作区 `rust-version = 1.96`。 | Apache-2.0。`matrix-sdk-crypto`、`matrix-sdk-sqlite`、`matrix-sdk-store-encryption` 同为 Apache-2.0。 |
| UniFFI | 0.32.1。README 写明后端为 Kotlin、Swift、Python、Ruby；第三方有 C#、Go，以及 Gobley 的 Kotlin Multiplatform。没有 ArkTS、NAPI、OHOS。 | MPL-2.0。 |
| JNA | Element X 使用 `net.java.dev.jna:jna:5.19.1` 加载 Android `.so`。 | POM 为 LGPL-2.1-or-later 或 Apache-2.0。鸿蒙 NAPI 不走 JNA。 |
| Olm | `vodozemac` 0.11.2。 | Apache-2.0。 |
| 会话库 SQLCipher | `net.zetetic:sqlcipher-android:4.19.1`，只服务 Element 自己的 SQLDelight 会话库。 | POM 指向 Zetetic 许可页，没有给出 SPDX 标识。这是 Android AAR。 |
| Rust 存储 | `rusqlite` 0.40.2，`bundled` 特征，不是 SQLCipher。字段加密在 `matrix-sdk-store-encryption`：XChaCha20-Poly1305，口令路径 PBKDF2-HMAC-SHA256（200_000 轮）或 HKDF-SHA256。 | 随 SDK，Apache-2.0。 |
| TLS | FFI 默认特征 `rustls-aws-lc-rs`。工作区 `rustls` 0.23.46。锁文件 `aws-lc-rs` 1.18.1、`aws-lc-sys` 0.45.0。 | 2026-11-09 探针曾解到 1.19.0 / 0.47.0。2026-11-10 的完整构建改回锁文件里的 1.18.1 / 0.45.0，并编进 `libmatrix_sdk_ffi.so`。 |

复用边界：

- Apache-2.0 的 Rust SDK 可以被一个新的鸿蒙客户端调用，但要自己做 NAPI，不能把 `sdk-android` AAR、Kotlin UniFFI 或 JNA 当成鸿蒙接口。
- `target_os` 在该 Rust 目标上是 `linux`，`target_env` 是 `ohos`。`cfg(target_os = "android")` 的 JNI、logcat、`rustls-platform-verifier` 不会编进去。
- Element X 的 Kotlin/Compose 是 AGPL-3.0-only（或另签商业许可）。公开 AGPL 文本不允许在其条款之外再加限制。若商店限制版要加客户端额外限制，不应把 AGPL 代码编进去；限制只应落在自有客户端，并且不能表述成限制他人自部署 homeserver 或联邦。这是许可证文本边界，不是法律意见。

## 2. 工具链

云镜像原先是 rustc 1.83.0。SDK 要求 rustc 1.96，所以另装了 stable 1.99.1（2026-10-13，LLVM 23.1.1），并 `rustup target add aarch64-unknown-linux-ohos`。`rustc --print cfg --target aarch64-unknown-linux-ohos` 显示 `target_os="linux"`、`target_env="ohos"`、`panic="unwind"`，且 sysroot 里有该目标的 rlib。仅有 target list 不算通过。

负对照见 `logs/04-hello-without-linker.log`：rustc 已发出 AArch64 目标文件，宿主 `/usr/bin/ld` 报 `Relocations in generic ELF (EM: 183)`，`cargo` 退出码 101。

正向链接使用华为云公开包：

- URL：`https://repo.huaweicloud.com/openharmony/os/7.0-Beta1/ohos-sdk-windows_linux-public.tar.gz`
- SHA-256：`435e45941e15de6f4149140d69bcab298357c0302d7f24a896602021ccbbb982`，与同目录 `.sha256` 一致
- 只解了 `ohos-sdk/linux/native-linux-x64-26.0.0.25-Beta.zip`
- clang 为 `OHOS (dev) clang version 15.0.4`
- 按 rustc 手册包了一层 `-target aarch64-linux-ohos --sysroot=... -D__MUSL__`

`libhello_ohos.so` 链接成功。没有把宿主 x86_64 构建说成鸿蒙通过。宿主探针是另一次 `cargo run --bin host_only`，日志写明 host 为 `x86_64-unknown-linux-gnu`。

工具链风险：OHOS clang 是 LLVM 15，rustc 是 LLVM 23。OHOS 自带的 `llvm-nm` 读 Rust 目标文件会报 attribute 不兼容；GNU `readelf`/`nm` 能读 ELF 头和符号，链接器也接受了这些 ELF。这只说明当前这种非 LTO 链接可以完成，不说明后续 bitcode/LTO 可用。

## 3. 原生依赖

AArch64 staticlib `libohos_native_deps.a` 中的目标文件 `Machine: AArch64`，并含 `sqlite3_open`、`hm_poc_sqlite_open_memory`、`hm_poc_vodozemac_account_linked`、`hm_poc_aead_roundtrip_len`。

`libohos_tls_aws_lc.a` 的对象同样是 AArch64。它链接的是 rustls 0.23.46 加上 cargo 解析出的 aws-lc-rs 1.19.0，不是 SDK 锁文件里的 aws-lc-sys 0.45.0。没有做 TLS 握手。

SQLCipher 探针一次失败即停止。`rusqlite` 的 `bundled-sqlcipher` 编译 `sqlcipher/sqlite3.c` 时找不到 `openssl/crypto.h`。该 sysroot 下没有 OpenSSL 头或 `libcrypto`。没有再去编 OpenSSL。Element 的 SQLCipher 是 Android AAR；Rust SDK 这条路径用的是普通 bundled SQLite 加应用层 StoreCipher，不是整库 SQLCipher。

## 4. NAPI 与 UniFFI

`bindings/matrix-sdk-ffi` 的 crate 类型是 `cdylib`、`staticlib`、`lib`，注释写的是 Android 与 iOS。`xtask` 只生成 Kotlin 和 Swift。OHOS 不会命中 `platform/mod.rs` 里的 `cfg(target_os = "android")`。

最小 PoC 是 `poc/napi/napi_async.cpp`：`napi_create_promise` + `napi_create_async_work`，工作线程调用 Rust `hm_poc_add`，完成时 resolve。模块用 `napi_module_register` 注册，名字 `hm_poc`。`poc/napi/ArkTsSketch.ets` 只是调用形状，文件头写明未执行。

这不证明 ArkTS 能加载它，也不证明 HarmonyOS NEXT 的打包器认这个 constructor 注册方式。

## 5. 登录、同步、E2EE、密钥与 pusher

以下符号都在锁定提交的 `bindings/matrix-sdk-ffi` 里，Element X 已通过 `org.matrix.rustcomponents.sdk` 调用：

- 登录：`Client::login`、`custom_login_with_jwt`、`login_with_email`，以及 OAuth/二维码登录在 Kotlin `RustMatrixAuthenticationService` 中的包装。
- 同步：`Client::sync_service()` 返回 `SyncServiceBuilder`（sliding sync）。
- 加密：`Client::encryption()`。恢复与备份：`enable_backups`、`enable_recovery`、`recover`、`recover_and_reset`、`recover_and_fix_backup`。
- 设备验证：`get_session_verification_controller`，再进入 SAS。Element 侧接口是 `SessionVerificationService`。
- Pusher：`set_pusher` / `delete_pusher`。HTTP 数据含 `url`、`format`、`default_payload`。`PushFormat` 只有 `EventIdOnly`。Element 固定使用 `PushFormat.EVENT_ID_ONLY`。

可复用的主机测试：`crates/matrix-sdk-crypto` 源码里有约 101 处测试属性，本次没有跑。已跑的是 `matrix-sdk-store-encryption` 库单测，10 通过、0 失败，耗时 0.01 秒。日志 `15-host-sdk-store-encryption-test.log`。这是 Linux x86_64 上的字段加密单测，不是设备上的 Olm/Megolm，也没有 homeserver。

安全存储衔接，不新造算法：

1. SDK 数据库本身是普通 SQLite。私密字段由 SDK 内的 StoreCipher 加密。应用只提供 32 字节随机密钥或高熵口令，通过 `SqliteStoreBuilder.key` / `highEntropyPassphrase` 传入。
2. Element 把这个密钥再放进 SQLCipher 会话库；SQLCipher 的密钥放在 Tink `EncryptedFile` 里，主密钥 URI 是 `android-keystore://...`。这三层都依赖 Android，不能搬到鸿蒙。
3. 鸿蒙对应物是 Asset Store（`@ohos.security.asset`）：短敏感数据以密文存放，读取时把明文交回应用。官方说明它依赖 HUKS，在安全环境里加解密，适合密码、Token 这类短数据，不适合当大库。
4. HUKS 生成的密钥除公钥外只能在 HUKS 内使用，业务拿不到原始字节。SDK 的 `key(&[u8])` 要的是进程内字节，所以不能把“不可导出的 HUKS 密钥”直接当成 StoreCipher 的 key。可行衔接是：随机 32 字节由应用生成，作为 Asset 的 `SECRET` 存取，再原样交给 SDK。算法仍是 SDK 里的 XChaCha20-Poly1305 / Olm，不在鸿蒙侧重写。
5. 这个衔接没有在设备上调用过。卸载是否保留由 Asset 的 `IS_PERSISTENT` 决定，本次未测。

## 6. Push Kit

核对的官方页面：

- 开通：<https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-config-setting>（页面写 Last updated: 2026-09-10）
- 入门：<https://developer.huawei.com/consumer/cn/doc/harmonyOS-Guides/push-gettingstart>（检索摘要写更新于 2026-09-14）
- 介绍与消息类型：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-kit-introduction>
- 通知消息：<https://developer.huawei.com/consumer/cn/doc/harmonyOS-Guides/push-send-alert>
- Token：<https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-get-token>
- 频控说明：<https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/push-faq-5>

文档里的开通顺序是：AGC 创建项目和应用，在“增长 > Push Kit”开通，设置数据处理位置，然后签名。调试与发布是分开的步骤。调试要求调试证书、注册调试设备、开通 Push Kit 后再申请调试 Profile 并手动签名；DevEco Studio 6.0.0 Beta5 起还可以在 IDE 里勾选 Push Kit 自动签名。开通页没有把“应用已上架”写成调试前提。它也没有单独写“个人开发者未上架 HAP 一定可以”。本环境没有登录 AGC，不能把文档描述当成该账号已经开通。

非穿戴设备的数据处理位置固定为中国大陆，不含港澳台。文档写明数据处理位置与服务器位置或用户所在地不一致时，推送会失败。这限制的是 Push Kit 通道，不是 Matrix 联邦。

测试消息要设 `testMessage=true`。文档写每个项目每个自然日最多 1000 条测试消息，所有设备共用，不是每设备 1000 条；单次请求的 Token 数不超过 10 个。超限回执码 256。这是文档额度，不是对用户 AGC 项目的实测，也不能当成已经可用的配额。

正式消息若不申请自分类，会被当成资讯营销类，文档写单设备单应用每日 2 条或 5 条。

消息结构按文档应是：

1. 端上 `pushService.getToken()`。只有 AGC 开通推送后这个调用才会返回 Token。未测。
2. 端上调用 SDK `set_pusher`：`url` 指向自建 Huawei gateway，`format` 为 `EventIdOnly`，`pushkey` 用网关能识别设备的键。Element 的 `defaultPayload` 形如 `{"cs":"..."}`，这里的 `cs` 是推送客户端路由秘密，不是 Megolm 密钥，也不是消息明文。鸿蒙实现不应把 Olm/Megolm 密钥或明文放进 pusher payload 或华为消息体。
3. homeserver 按 event id 通知 gateway。gateway 用服务账号 JWT 调 Push Kit REST v3：`https://push-api.cloud.huawei.com/v3/[projectId]/messages:send`。消息体只带房间、事件号、未读数这类元信息。文档限制消息体不超过 4096 字节，不含 Token。
4. 通知消息由系统展示在通知中心、锁屏和横幅，用户点击后拉起应用。应用再 sync，用本地 SDK 解密。
5. 介绍页对后台消息的描述是：进程在前台则把内容交给应用；进程不在前台则缓存，等应用下次启动再交。它不是“杀进程后立刻在后台解密”的通道。因此杀进程后的正确动作是系统通知把用户或应用拉起来，再由 SDK 拉取并解密。锁屏展示和杀进程后的实际到达都没有在真机上测。

## 下一步最小真机实验

条件：一台 HarmonyOS NEXT 手机、DevEco、已在 AGC 创建但可以不上架的应用、调试证书、已注册的调试设备、调试 Profile、中国大陆网络。个人开发者身份是否被该账号的 Push Kit 接受，仍要在 AGC 里看一次，不能用这次文档核对代替。

1. 把 `libhm_poc.so` 放进一个空 HAP，ArkTS 调用 `addAsync(2, 3)`，期望 Promise 为 5。只验证加载和异步桥，不验证 Matrix。
2. 生成 32 字节随机数，用 Asset Store 的 `SECRET` 写入再读出，交给一个只调用 SDK `SqliteStoreBuilder.key` 的原生模块，杀掉进程后仍能打开同一个库。不改 StoreCipher，不把 HUKS 不可导出密钥当成 SDK key。
3. 开通 Push Kit 后取 Token。自建 gateway 只转发 `room_id`、`event_id` 和未读数，`testMessage=true`。各做一次锁屏到达和杀进程后点击通知再 sync。消息里不放密钥或明文。记录的是这一台设备和这一天的结果，不是 1000 条额度已被证实。

## 日志索引

| 文件 | 内容 |
| --- | --- |
| `logs/03-rustc-ohos-target.txt` | rustc 1.99.1 与 OHOS target cfg |
| `logs/04-hello-without-linker.log` | 无 OHOS linker 的失败 |
| `logs/05-sdk-sha256.txt` | 公开 SDK 校验和 |
| `logs/06-hello-with-ohos-linker.log` | hello 链接成功 |
| `logs/07-native-deps.log` | SQLite、vodozemac、AEAD 交叉编译成功 |
| `logs/08-tls-aws-lc.log` | rustls/aws-lc 交叉编译成功 |
| `logs/09-sqlcipher.log` | SQLCipher 因缺少 OpenSSL 头失败 |
| `logs/12-build-script-stdout.log` | 上述构建的退出码汇总 |
| `logs/13-host-only-probe.log` | 主机探针，不是鸿蒙 |
| `logs/15-host-sdk-store-encryption-test.log` | SDK 存储加密单测，主机，10 通过 |
| `logs/16-elf-evidence.txt` | 两个 `.so` 的 ELF 头、NEEDED 和符号 |
| `logs/20-full-sdk-build.log` | 锁定 `matrix-sdk-ffi` 的 OHOS 构建，退出码 0 |
| `logs/26-host-sdk-store-test.log` | 主机上错误密钥被拒绝，1 通过。不是鸿蒙 |
| `logs/27-elf-sdk.txt` | FFI、桥、NAPI 的 ELF 依赖 |
| `logs/28-ffi-symbols.txt` | login/sync/encryption/sqlite/pusher 符号 |
| `logs/29-bridge-sha256.txt` | 三个产物的 SHA-256 |
| `hap-diag/` | 未签名诊断工程，DevEco 未编译 |
| `evidence/libhello_ohos.so` | AArch64 hello |
| `evidence/libhm_poc.so` | AArch64 NAPI 壳 |

## 7. 2026-11-10 完整 SDK 构建

精确命令在 `logs/20-full-sdk-preamble.txt` 和 `poc/scripts/build-full-sdk.sh`。工作区没有改 SDK 业务代码。为了让新桥包能被 `--locked` 接受，`Cargo.lock` 只增加了本地包 `ohos-min-bridge` 0.0.0 这 8 行，没有改任何第三方版本或 checksum。`ruma` 仍是锁文件里的 git rev `0ed7fba34213f18a628a56f527c6cc795cd7eef5`。

Android 发布脚本 `xtask` 的 FullSDK 特征是在默认特征之上再加 `sentry,experimental-x509-identity-verification`。这次构建用的就是这组。默认特征已经包含 `bundled-sqlite`、`rustls-aws-lc-rs`，并且 `matrix-sdk` 依赖打开了 `e2e-encryption`。没有为 OHOS 改 `cfg`，也没有换 TLS 后端。

| 产物 | 机器 | 动态依赖 | 说明 |
| --- | --- | --- | --- |
| `libmatrix_sdk_ffi.so` 146MB | AArch64 | `libc.so` | 完整 FFI。动态符号包括 `uniffi_matrix_sdk_ffi_fn_method_client_login`、`client_sync_service`、`client_encryption`、`client_set_pusher`、`clientbuilder_sqlite_store`、`encryption_enable_recovery`。库内有 `sqlite3_open`，没有 `sqlite3_key`。SHA-256 `2bc22e2c720970d015b6f57ce0f66ce487b695ddfe4a7d446a543953c9e12a06`。 |
| `libohos_min_bridge.so` 21MB | AArch64 | `libc.so` | 导出 `hm_sdk_open_encrypted_store`、`hm_sdk_store_key_len`。SHA-256 以 `logs/29-bridge-sha256.txt` 为准。 |
| `libhm_sdk_diag.so` 37KB | AArch64 | `libohos_min_bridge.so`、`libace_napi.z.so`、`libc++_shared.so`、`libc.so` | NAPI 模块名 `hm_sdk_diag`，异步调用上面的打开函数。 |

桥的打开函数要求 32 字节原始密钥，调用 `SqliteStoreConfig::key`，再打开 state store 和 crypto store。它另外用翻了一个比特的密钥再打开同目录，只有这次失败才返回 0。`Client::builder().homeserver_url(...).sqlite_store_with_config_and_cache_path(...)` 只把配置留在 builder 里，没有调用 `build()`，所以不会访问网络或账号。SQLCipher 仍然因缺少 OpenSSL 头而 BLOCKED；这里没有改用无密钥的普通库冒充加密。

`hap-diag/` 是未签名的诊断工程，只有一页按钮，用来在沙箱目录上调用 `openEncryptedStore`。它没有聊天界面。DevEco、签名、HDC 和真机都没有跑过。HarmonyOS NEXT 调试要用 HDC。安卓 ADB 不能当作这次原生库已经在鸿蒙上跑通。

云端没有连接用户的手机，也没有登录 AGC。真机实验要由主代理通过用户本机的 Air 做，条件是：

1. HarmonyOS NEXT 手机，已打开开发者模式，`hdc list targets` 能看到设备。
2. 安装 DevEco，以及与该手机匹配的 HarmonyOS NEXT SDK。公开 OpenHarmony 7.0-Beta1 native clang 只能交叉链接，不能代替 DevEco 编 HAP。
3. AGC 调试证书、已注册的这台设备、调试 Profile。没有这些就不能装签名包。本次没有登录 AGC。
4. 把 `libohos_min_bridge.so`、`libhm_sdk_diag.so`，以及 OpenHarmony sysroot 里的 `libc++_shared.so` 放进 `entry/libs/arm64-v8a/`。
5. 用 DevEco 编未上架的调试 HAP，`hdc install`，点页面按钮。返回 0 表示原始密钥能打开 SDK 的 state/crypto 库，且错误密钥被拒绝。这仍不是登录或收消息。
6. 诊断页里的 32 字节是固定测试向量，不是 Asset Store 密钥。接到 Asset Store 之前，不要把它当成正式设备密钥。
