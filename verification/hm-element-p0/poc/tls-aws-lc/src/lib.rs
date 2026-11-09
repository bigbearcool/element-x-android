#[no_mangle]
pub extern "C" fn hm_poc_rustls_client_config() -> i32 {
    let _cfg = rustls::ClientConfig::builder()
        .with_root_certificates(rustls::RootCertStore::empty())
        .with_no_client_auth();
    1
}
