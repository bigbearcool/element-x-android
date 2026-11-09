import { hilog } from '@kit.PerformanceAnalysisKit';
import native from 'libhm_sdk_diag.so';

// Fixed diagnostic vector. This is not an Asset Store key and not a login secret.
const DIAG_KEY: Uint8Array = new Uint8Array([
  0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
  0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
  0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
  0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11
]);

@Entry
@Component
struct Index {
  @State result: string = '尚未调用';

  build() {
    Column({ space: 16 }) {
      Text('SDK 加密库诊断')
        .fontSize(24)
      Text('只打开锁定 SDK 的 SQLite state/crypto 库。不登录，不同步，不发消息。')
        .fontSize(14)
      Button('初始化加密库')
        .onClick(() => {
          this.openStore();
        })
      Text(this.result)
        .fontSize(16)
    }
    .width('100%')
    .height('100%')
    .padding(24)
  }

  private openStore(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.result = '没有 UI context';
      return;
    }
    const dir = context.filesDir + '/sdk-diag';
    native.openEncryptedStore(dir, DIAG_KEY).then((code: number) => {
      hilog.info(0x0000, 'hm-sdk-diag', 'openEncryptedStore %{public}d', code);
      this.result = code === 0 ? '返回 0：原密钥打开，错误密钥被拒绝' : `返回 ${code}`;
    }).catch((err: Object) => {
      this.result = `调用失败 ${JSON.stringify(err)}`;
    });
  }
}
