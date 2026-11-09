fn main() {
    let sqlite = ohos_native_deps::sqlite_probe();
    let aead = ohos_native_deps::aead_probe();
    let olm = ohos_native_deps::vodozemac_probe();
    println!("HOST_ONLY sqlite={sqlite} aead_len={aead} vodozemac={olm}");
    println!("target_pointer_width={}", std::mem::size_of::<usize>() * 8);
    assert_eq!(sqlite, 1);
    assert_eq!(aead, 6);
    assert_eq!(olm, 1);
}
