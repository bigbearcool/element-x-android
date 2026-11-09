// NOT EXECUTED. No HarmonyOS SDK, emulator, or device is available here.
// UniFFI Kotlin bindings are not this interface. This sketch only shows the
// call shape that would be tried on a real HAP after the .so is packaged.

import native from 'libhm_poc.so';

export async function addOnWorkerThread(a: number, b: number): Promise<number> {
  return native.addAsync(a, b);
}
