# 未签名诊断 HAP

这个目录不是已经编好的 HarmonyOS 包。DevEco 没有打开过它，没有签名，没有用 HDC 安装，也没有在手机上运行。

页面只有一个按钮：在应用沙箱的 `sdk-diag` 目录调用 `openEncryptedStore`。原生函数使用锁定的 Matrix Rust SDK，用 32 字节原始密钥打开 state store 和 crypto store，并用改了一个比特的密钥确认打不开。返回 0 才算这次诊断通过。

按钮里的 32 字节是固定测试向量，不是 Asset Store 里的设备密钥，也不是登录口令。

安卓 `adb` 不能用来宣称这个包已在 HarmonyOS NEXT 上跑通。装到真机需要 DevEco、匹配的 HarmonyOS NEXT SDK、调试证书和 `hdc`。
