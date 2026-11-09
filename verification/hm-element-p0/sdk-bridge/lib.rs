//! Diagnostic bridge. It links the locked `matrix-sdk` client and opens the
//! same SQLite stores with `SqliteStoreConfig::key`. It does not log in, sync,
//! or replace the SDK cipher.

use std::ffi::{CStr, c_char, c_int};
use std::path::Path;
use std::ptr;
use std::slice;

use matrix_sdk::{Client, SqliteCryptoStore, SqliteStateStore, SqliteStoreConfig};

const KEY_LEN: usize = 32;

/// Open the SDK state and crypto stores with a 32-byte raw key, then prove a
/// different key cannot reopen the state store.
///
/// Returns 0 when the original key opens both stores and the wrong key is
/// rejected. Does not contact a homeserver.
///
/// # Safety
/// `path` must be a NUL-terminated UTF-8 string. `key` must point at `key_len`
/// bytes. The key is not logged.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn hm_sdk_open_encrypted_store(
    path: *const c_char,
    key: *const u8,
    key_len: usize,
) -> c_int {
    if path.is_null() || key.is_null() {
        return -1;
    }
    if key_len != KEY_LEN {
        return -2;
    }
    let path = match unsafe { CStr::from_ptr(path) }.to_str() {
        Ok(path) => path,
        Err(_) => return -3,
    };
    let key = unsafe { slice::from_raw_parts(key, KEY_LEN) };
    let runtime = match tokio::runtime::Builder::new_current_thread().enable_all().build() {
        Ok(runtime) => runtime,
        Err(_) => return -4,
    };
    runtime.block_on(open_stores(path, key))
}

async fn open_stores(path: &str, key: &[u8]) -> c_int {
    let config = SqliteStoreConfig::new(path).key(Some(key));
    // Type-check and retain the client builder the real session uses.
    // `homeserver_url` only stores the string; `build()` is intentionally not called.
    let _builder = Client::builder()
        .homeserver_url("http://127.0.0.1:9")
        .sqlite_store_with_config_and_cache_path(config.clone(), None::<&Path>);

    if SqliteStateStore::open_with_config(&config).await.is_err() {
        return -5;
    }
    if SqliteCryptoStore::open_with_config(&config).await.is_err() {
        return -6;
    }

    let mut wrong = [0u8; KEY_LEN];
    wrong.copy_from_slice(key);
    wrong[0] ^= 0xff;
    let wrong_config = SqliteStoreConfig::new(path).key(Some(&wrong));
    if SqliteStateStore::open_with_config(&wrong_config).await.is_ok() {
        // The SDK accepted a different key. That would mean this open did not
        // keep the original store cipher.
        return -7;
    }
    0
}

/// Unused pointer anchor so a C caller can confirm the symbol is the bridge
/// and not a plaintext stub. Always returns 32.
#[unsafe(no_mangle)]
pub extern "C" fn hm_sdk_store_key_len() -> usize {
    let _ = ptr::null::<Client>();
    KEY_LEN
}

#[cfg(test)]
mod tests {
    use std::ffi::CString;
    use std::time::{SystemTime, UNIX_EPOCH};

    use super::hm_sdk_open_encrypted_store;

    #[test]
    fn host_encrypted_store_rejects_wrong_key() {
        let nanos = SystemTime::now().duration_since(UNIX_EPOCH).expect("clock").as_nanos();
        let dir = std::env::temp_dir().join(format!("hm-sdk-store-{nanos}"));
        std::fs::create_dir_all(&dir).expect("temp dir");
        let path = CString::new(dir.to_str().expect("utf8 path")).expect("path");
        let key = [0x11u8; 32];
        let rc = unsafe { hm_sdk_open_encrypted_store(path.as_ptr(), key.as_ptr(), key.len()) };
        let _ = std::fs::remove_dir_all(&dir);
        assert_eq!(rc, 0, "expected encrypted open to accept the key and reject a different key, rc={rc}");
    }
}
