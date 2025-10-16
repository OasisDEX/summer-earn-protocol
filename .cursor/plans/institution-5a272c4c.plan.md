<!-- 5a272c4c-c20a-4938-9165-eab63fb49c28 8bbd5f34-de4c-4424-929f-efeb953a075e -->
# Fix Registry + Add Institutional Bases

### Changes to existing files
1. IInstitutionalVaultRegistryErrors.sol
   - Rename error `InstitutionDisabled` → `InstitutionIsDisabled`
2. IInstitutionalVaultRegistryEvents.sol
   - Fix NatSpec param mismatch; remove stray `institution` param doc
   - Keep `InstitutionAdded(bytes32 id, address configurationManager, address protocolAccessManager, address admiralsQuarters)` (4 args)
   - Keep `InstitutionAdmiralsQuartersUpdated(...)` and `InstitutionReplaced(...)`
   - Keep `InstitutionDisabled` event name OR rename to `InstitutionDeactivated` to avoid clash; prefer keeping event and renaming the error (see #1)
3. IInstitutionalVaultRegistry.sol
   - Keep API signatures returning tuple; `getInstitution(bytes32)` returns (configurationManager, protocolAccessManager, admiralsQuarters, harborCommand, active)
   - `addInstitution(bytes32, address, address, address, address)` (individual args)
4. InstitutionalVaultRegistry.sol
   - Struct `Institution { address configurationManager; address protocolAccessManager; address admiralsQuarters; bool active; }`
   - Implement `getInstitution` to compute `harborCommand` via `IConfigurationManager(configurationManager).harborCommand()` and return the 5-tuple
   - Fix destructuring calls in getters to match tuple
   - Use `InstitutionIsDisabled` error in `disableInstitution`, `updateAdmiralsQuarters`, and `replaceInstitution`
   - `addInstitution` takes individual args, validates non-zero, stores struct, `active=true`, emits 4-arg `InstitutionAdded`
   - `replaceInstitution` disables old (emit event), adds new via struct, emits `InstitutionAdded` and `InstitutionReplaced`

### New base contracts
- Add `packages/core-contracts/src/contracts/institution/InstitutionalRegistryAware.sol`
  - Stores `bytes32 institutionId` and `IInstitutionalVaultRegistry registry`
  - Constructor `(address registry, bytes32 institutionId)`
  - Internal getters: `_configurationManager()`, `_protocolAccessManager()`, `_admiralsQuarters()`, `_harborCommand()`
- Add `packages/core-contracts/src/contracts/institution/InstitutionalWhitelistBase.sol`
  - `abstract` inherits `Whitelist` + `InstitutionalRegistryAware`
  - Provides `onlyWhitelisted(_msgSender())` gating utilities for inheritors
  - NatSpec documents use with `AdmiralsQuartersWhitelist` + `FleetCommanderWhitelist`

### Minimal tests (Foundry)
- `test/institution/InstitutionalVaultRegistry.t.sol`
  - addInstitution success + events; duplicate add reverts; disable reverts on disabled; updateAdmiralsQuarters emits; replaceInstitution disables old and adds new
- `test/institution/InstitutionalRegistryAware.t.sol`
  - Deploy mock registry + entry; Instantiate a mock vault inheriting `InstitutionalWhitelistBase`; assert getters return registry values; test onlyWhitelisted gating including open mode via `address(0)` whitelisting

### Questions
1. Confirm we derive `harborCommand` from `ConfigurationManager` (not stored in registry)?
   - a) Yes (derive via IConfigurationManager)
   - b) No (store explicitly in registry)
2. Do you want the base to include multicall (`ProtectedMulticallWhitelist`) or keep it lean with just `Whitelist` + registry awareness?
   - a) Lean (`Whitelist` + registry aware)
   - b) Include `ProtectedMulticallWhitelist`

### To-dos

- [ ] Add IInstitutionalVaultRegistryErrors.sol with defined errors
- [ ] Add IInstitutionalVaultRegistryEvents.sol with add/disable/update/replace events
- [ ] Add IInstitutionalVaultRegistry.sol with getters and governor-only management API
- [ ] Implement InstitutionalVaultRegistry.sol with access control, validation, and events
- [ ] Write NatSpec docs explaining single-source-of-truth and replacement policy