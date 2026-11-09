#[no_mangle]
pub extern "C" fn hm_poc_sqlcipher_feature_linked() -> i32 {
    match rusqlite::Connection::open_in_memory() {
        Ok(_) => 1,
        Err(_) => -1,
    }
}
