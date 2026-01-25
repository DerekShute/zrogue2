//!
//! Server library stashed here for convenience.  Import on client side
//!
//! Transaction:
//!
//!    HANDSHAKE_REQUEST json ->
//!                  <- HANDSHAKE_RESPONSE json
//!    ENTRY msgpack ->
//!     (TODO)

pub const handshake = @import("protocol/handshake.zig");

//
// Unit Testing
//
comptime {
    _ = @import("protocol/handshake.zig");
}

// EOF
