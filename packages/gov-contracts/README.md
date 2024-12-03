# Summer Governance Contracts

This package contains the core governance contracts for the Summer protocol.

## Main Contracts

### SummerGovernor.sol

`SummerGovernor` is the main governance contract for the Summer protocol. It extends various OpenZeppelin governance modules and includes custom functionality such as whitelisting and voting decay.

Key features:
- Cross-chain proposal execution
- Whitelisting system for proposers
- Integration with LayerZero for cross-chain messaging
- Custom voting power calculation with decay

### SummerToken.sol

`SummerToken` is the governance token for the Summer protocol. It extends OpenZeppelin's ERC20 implementation and includes additional features.

Key features:
- ERC20 with voting capabilities
- Integration with LayerZero's OFT (Omnichain Fungible Token)
- Built-in vesting wallet creation

### SummerVestingWallet.sol

`SummerVestingWallet` is a custom vesting wallet implementation for the Summer protocol.

Key features:
- Two vesting schedules: 6-month cliff and 2-year quarterly vesting
- Built on top of OpenZeppelin's VestingWallet

## Foundry

This project uses Foundry, a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

### Usage

#### Build

```shell
$ forge build
```

#### Test

```shell
$ forge test
```

#### Format

```shell
$ forge fmt
```

#### Gas Snapshots

```shell
$ forge snapshot
```

#### Anvil (Local Ethereum node)

```shell
$ anvil
```

#### Deploy

```shell
$ forge script script/DeployGovernance.s.sol:DeployGovernanceScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

#### Cast (Contract interaction)

```shell
$ cast <subcommand>
```

#### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Documentation

For more detailed information about Foundry, visit: https://book.getfoundry.sh/

### Audits

- [ChainSecurity](./audits/chainsecurity-audit.pdf)
