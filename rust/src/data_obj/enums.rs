macro_rules! enum_str {
    ($name:ident { $($variant:ident($str:expr), )* }) => {
        #[derive(Clone, Copy, Debug, Eq, PartialEq)]
        pub enum $name {
            $($variant,)*
        }

        impl $name {
            pub fn as_str(&self) -> &'static str {
                match self {
                    $( $name::$variant => $str, )*
                }
            }
        }

        impl ::core::fmt::Display for $name {
            fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> std::fmt::Result {
                match self {
                    $( $name::$variant => write!(f,"{}",$str), )*
                }
            }
        }

        impl ::serde::Serialize for $name {
            fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
                where S: ::serde::Serializer,
            {
                // 将枚举序列化为字符串。
                serializer.serialize_str(match *self {
                    $( $name::$variant => $str, )*
                })
            }
        }

        impl<'de> ::serde::Deserialize<'de> for $name {
            fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
                where D: ::serde::Deserializer<'de>,
            {
                struct Visitor;

                impl<'de> ::serde::de::Visitor<'de> for Visitor {
                    type Value = $name;

                    fn expecting(&self, formatter: &mut ::std::fmt::Formatter) -> ::std::fmt::Result {
                        write!(formatter, "a string for {}", stringify!($name))
                    }

                    fn visit_str<E>(self, value: &str) -> Result<$name, E>
                        where E: ::serde::de::Error,
                    {
                        match value {
                            $( $str => Ok($name::$variant), )*
                            _ => Err(E::invalid_value(::serde::de::Unexpected::Other(
                                &format!("unknown {} variant: {}", stringify!($name), value)
                            ), &self)),
                        }
                    }
                }

                // 从字符串反序列化枚举。
                deserializer.deserialize_str(Visitor)
            }
        }

    }
}

enum_str!(LoginState {
    Unset("unset"),
    Set("set"),
});

impl Default for LoginState {
    fn default() -> Self {
        Self::Unset
    }
}

enum_str!(AfterDownload {
    MoveToTrash("move_to_trash"),
    Delete("delete"),
});

impl Default for AfterDownload {
    fn default() -> Self {
        Self::MoveToTrash
    }
}

enum_str!(SendingTaskState {
    Init("init"),
    Sending("sending"),
    Success("success"),
    Failed("failed"),
    Canceling("canceling"),
    Canceled("canceled"),
});

impl Default for SendingTaskState {
    fn default() -> Self {
        Self::Init
    }
}

enum_str!(ReceivingTaskState {
    Init("init"),
    Receiving("receiving"),
    Success("success"),
    Failed("failed"),
    Canceling("canceling"),
    Canceled("canceled"),
});

impl Default for ReceivingTaskState {
    fn default() -> Self {
        Self::Init
    }
}

enum_str!(FileItemType {
    File("file"),
    Folder("folder"),
});

impl Default for FileItemType {
    fn default() -> Self {
        Self::File
    }
}

enum_str!(SendingTaskErrorType{
    Unset("unset"),
    Unknown("unknown"),
});

impl Default for SendingTaskErrorType {
    fn default() -> Self {
        Self::Unset
    }
}

enum_str!(SendingTaskClearType{
    Unset("unset"),
    ClearSuccess("clear_success"),
    CancelFailed("clear_failed"),
    RetryFailed("retry_failed"),
});

enum_str!(ReceivingTaskClearType{
    Unset("unset"),
    ClearSuccess("clear_success"),
    CancelFailedAndDeleteCloud("cancel_failed_and_delete_cloud"),
    RetryFailed("retry_failed"),
});

enum_str!(SendingTaskType{
    Single("single"),
    PackZip("pack_zip"),
});

impl Default for SendingTaskType {
    fn default() -> Self {
        Self::Single
    }
}
