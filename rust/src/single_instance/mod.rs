
pub mod error;

pub use self::inner::*;

#[cfg(target_os = "windows")]
mod inner {
    use super::error;
    use error::{Result, SingleInstanceError};
    use std::ptr;
    use widestring::WideCString;
    use winapi::shared::winerror::{ERROR_ALREADY_EXISTS, ERROR_INVALID_HANDLE};
    use winapi::um::errhandlingapi::GetLastError;
    use winapi::um::handleapi::CloseHandle;
    use winapi::um::synchapi::CreateMutexW;
    use winapi::um::winnt::HANDLE;

    /// A struct representing one running instance.
    pub struct SingleInstance {
        handle: Option<HANDLE>,
    }

    unsafe impl Send for SingleInstance {}
    unsafe impl Sync for SingleInstance {}

    impl SingleInstance {
        /// Returns a new SingleInstance object.
        pub fn new(name: &str) -> Result<Self> {
            let name = WideCString::from_str(name)?;
            unsafe {
                let handle = CreateMutexW(ptr::null_mut(), 0, name.as_ptr());
                let last_error = GetLastError();

                // https://docs.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-createmutexexw
                if handle.is_null() || handle == ERROR_INVALID_HANDLE as _ {
                    Err(SingleInstanceError::MutexError(last_error))
                } else if last_error == ERROR_ALREADY_EXISTS {
                    CloseHandle(handle);
                    Ok(SingleInstance { handle: None })
                } else {
                    Ok(SingleInstance {
                        handle: Some(handle),
                    })
                }
            }
        }

        /// Returns whether this instance is single.
        pub fn is_single(&self) -> bool {
            self.handle.is_some()
        }
    }

    impl Drop for SingleInstance {
        fn drop(&mut self) {
            if let Some(handle) = self.handle.take() {
                unsafe {
                    CloseHandle(handle);
                }
            }
        }
    }
}

#[cfg(any(target_os = "linux", target_os="android"))]
mod inner {
    use std::os::unix::ffi::OsStrExt;
    use super::error;
    use error::Result;
    use nix::sys::socket::{self, UnixAddr};
    use nix::unistd;
    use std::os::unix::prelude::RawFd;

    /// A struct representing one running instance.
    pub struct SingleInstance {
        maybe_sock: Option<RawFd>,
    }

    impl SingleInstance {
        /// Returns a new SingleInstance object.
        pub fn new(name: &str) -> Result<Self> {
            let path = std::env::temp_dir().join(name);
            let addr = UnixAddr::new_abstract(path.as_path().as_os_str().as_bytes())?;
            let sock = socket::socket(
                socket::AddressFamily::Unix,
                socket::SockType::Stream,
                // If we fork and exec, then make sure the child process doesn't
                // hang on to this file descriptor.
                socket::SockFlag::SOCK_CLOEXEC,
                None,
            )?;

            let maybe_sock = match socket::bind(sock, &socket::SockAddr::Unix(addr)) {
                Ok(()) => Some(sock),
                Err(nix::errno::Errno::EADDRINUSE) => None,
                Err(e) => return Err(e.into()),
            };

            Ok(Self { maybe_sock })
        }

        /// Returns whether this instance is single.
        pub fn is_single(&self) -> bool {
            self.maybe_sock.is_some()
        }
    }

    impl Drop for SingleInstance {
        fn drop(&mut self) {
            if let Some(sock) = self.maybe_sock {
                // Intentionally discard any close errors.
                let _ = unistd::close(sock);
            }
        }
    }
}

#[cfg(target_os = "macos")]
mod inner {
    use super::error;
    use error::Result;
    use libc::{__error, flock, EWOULDBLOCK, LOCK_EX, LOCK_NB};
    use std::fs::File;
    use std::os::unix::io::AsRawFd;

    /// A struct representing one running instance.
    pub struct SingleInstance {
        _file: File,
        is_single: bool,
    }

    impl SingleInstance {
        /// Returns a new SingleInstance object.
        pub fn new(name: &str) -> Result<Self> {
            let path = std::env::temp_dir().join(name);
            let file = if path.exists() {
                File::open(path)?
            } else {
                File::create(path)?
            };
            unsafe {
                let rc = flock(file.as_raw_fd(), LOCK_EX | LOCK_NB);
                let is_single = rc == 0 || EWOULDBLOCK != *__error();
                Ok(Self {
                    _file: file,
                    is_single,
                })
            }
        }

        /// Returns whether this instance is single.
        pub fn is_single(&self) -> bool {
            self.is_single
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    static UNIQ_ID : &'static str   = "aa2d0258-ffe9-11e7-ba89-0ed5f89f718b";
    #[test]
    fn test_single_instance() {
        {
            let instance_a = SingleInstance::new(UNIQ_ID).unwrap();
            assert!(instance_a.is_single());
            let instance_b = SingleInstance::new(UNIQ_ID).unwrap();
            assert!(!instance_b.is_single());
        }
        let instance_c = SingleInstance::new(UNIQ_ID).unwrap();
        assert!(instance_c.is_single());
    }
}
