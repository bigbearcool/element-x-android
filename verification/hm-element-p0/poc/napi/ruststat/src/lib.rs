#[no_mangle]
pub extern "C" fn hm_poc_add(a: u32, b: u32) -> u32 {
    a.wrapping_add(b)
}
