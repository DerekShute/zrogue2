# Networking protocol

The messages sent and received as part of the network protocol leverage the enums and
so forth from the regular game library but not the whole thing: msgpack does not support
array pack and it seems wise to distinguish the protocol from the internals.

There will probably be a translation constructor
