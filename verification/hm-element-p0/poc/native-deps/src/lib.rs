//! Cross-compile probe for the native pieces Element X's locked SDK actually uses.
//! This is not a Matrix client and it does not implement Olm.

use std::ffi::c_int;

pub fn sqlite_probe() -> c_int {
    match rusqlite::Connection::open_in_memory() {
        Ok(conn) => conn.query_row("SELECT 1", [], |row| row.get::<_, i32>(0)).unwrap_or(-2),
        Err(_) => -1,
    }
}

#[no_mangle]
pub extern "C" fn hm_poc_sqlite_open_memory() -> c_int {
    sqlite_probe()
}

pub fn aead_probe() -> c_int {
    use chacha20poly1305::aead::{Aead, KeyInit};
    use chacha20poly1305::{Key, XChaCha20Poly1305, XNonce};
    // Fixed bytes: this only forces the SDK's store-cipher primitive to link.
    let key = Key::from_slice(&[7u8; 32]);
    let cipher = XChaCha20Poly1305::new(key);
    let nonce = XNonce::from([8u8; 24]);
    let ct = cipher.encrypt(&nonce, b"hm-poc".as_ref()).expect("encrypt");
    let pt = cipher.decrypt(&nonce, ct.as_ref()).expect("decrypt");
    pt.len() as c_int
}

#[no_mangle]
pub extern "C" fn hm_poc_aead_roundtrip_len() -> c_int {
    aead_probe()
}

pub fn vodozemac_probe() -> c_int {
    let account = vodozemac::olm::Account::new();
    let _id = account.curve25519_key();
    1
}

#[no_mangle]
pub extern "C" fn hm_poc_vodozemac_account_linked() -> c_int {
    vodozemac_probe()
}
