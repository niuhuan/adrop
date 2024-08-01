use aes_gcm::aes::Aes256;
use aes_gcm::{Aes256Gcm, AesGcm, KeyInit};
use aes_gcm::aead::consts::U12;
use aes_gcm::aead::stream::{Decryptor, DecryptorBE32, Encryptor, EncryptorBE32, StreamBE32};
use base64::Engine;

pub fn encryptor_from_key(
    password: &[u8],
) -> anyhow::Result<Encryptor<AesGcm<Aes256, U12>, StreamBE32<AesGcm<Aes256, U12>>>> {
    let key_bytes = md5::compute(password).0;
    let key_hex = hex::encode(key_bytes);
    let key = key_hex.as_bytes();
    let nonce_slice = &key_bytes[0..7];
    let cipher = Aes256Gcm::new_from_slice(key)?;
    let encryptor = EncryptorBE32::from_aead(cipher, nonce_slice.into());
    Ok(encryptor)
}

pub fn encrypt_buff(buff: &[u8], password: &[u8]) -> anyhow::Result<Vec<u8>> {
    let encryptor = encryptor_from_key(password)?;
    let final_vec = encryptor
        .encrypt_last(buff)
        .map_err(|e| anyhow::anyhow!("加密时出错: {}", e))?;
    Ok(final_vec)
}

pub fn encrypt_buff_to_base64(buff: &[u8], password: &[u8]) -> anyhow::Result<String> {
    let final_vec = encrypt_buff(buff, password)?;
    let final_base64 = base64::prelude::BASE64_URL_SAFE.encode(final_vec.as_slice());
    Ok(final_base64)
}

pub fn encrypt_file_name(file_name: &str, password: &[u8]) -> anyhow::Result<String> {
    Ok(encrypt_buff_to_base64(file_name.as_bytes(), password)?)
}

pub fn decryptor_from_key(
    password: &[u8],
) -> anyhow::Result<Decryptor<AesGcm<Aes256, U12>, StreamBE32<AesGcm<Aes256, U12>>>> {
    let key_bytes = md5::compute(password).0;
    let key_hex = hex::encode(key_bytes);
    let key = key_hex.as_bytes();
    let nonce_slice = &key_bytes[0..7];
    let cipher = Aes256Gcm::new_from_slice(key)?;
    let decryptor = DecryptorBE32::from_aead(cipher, nonce_slice.into());
    Ok(decryptor)
}

pub fn decrypt_buff(buff: &[u8], password: &[u8]) -> anyhow::Result<Vec<u8>> {
    let encryptor = decryptor_from_key(password)?;
    let final_buff = encryptor
        .decrypt_last(buff)
        .map_err(|e| anyhow::anyhow!("解密时出错(1): {}", e))?;
    Ok(final_buff)
}

pub fn decrypt_base64(base64_str: &str, password: &[u8]) -> anyhow::Result<Vec<u8>> {
    let final_vec = base64::prelude::BASE64_URL_SAFE.decode(base64_str.as_bytes())?;
    decrypt_buff(final_vec.as_slice(), password)
}

pub fn decrypt_file_name(file_name: &str, password: &[u8]) -> anyhow::Result<String> {
    decrypt_base64(file_name, password)
        .and_then(|v| String::from_utf8(v).map_err(|e| anyhow::anyhow!("解码时出错: {}", e)))
}
