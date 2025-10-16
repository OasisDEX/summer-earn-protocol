## Institutional Contracts (Whitelist-only)

This package contains verbatim copies of the institutional whitelist contracts extracted from `core-contracts` and `access-contracts`.

- Source files are copied without modification.
- Imports remain unchanged and will reference other packages; remappings will be added later.

Contracts included:
- `src/contracts/institutional/HarborCommandWhitelist.sol`
- `src/contracts/institutional/TipJarWhitelist.sol`
- `src/contracts/institutional/FleetCommanderConfigProviderWhitelist.sol`
- `src/contracts/institutional/FleetCommanderWhitelist.sol`
- `src/contracts/ProtocolAccessManagedWhitelist.sol`
- `src/contracts/ProtocolAccessManagerWhitelist.sol`

Build will fail until remappings are configured to resolve imports against the original packages.

