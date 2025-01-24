# Voting Decay Smart Contract

A Solidity library for tracking and managing the decay of voting power in governance systems.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [API Reference](#api-reference)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Overview

The Voting Decay Library provides a flexible and efficient way to implement voting power erosion in
blockchain-based governance systems. It allows for customizable decay rates, supports delegation,
and offers utilities for calculating and updating voting power based on user activity.

## Features

- Customizable decay rates
- Notional amount-based erosion calculation
- Support for delegated voting power
- Time-based modifiers for accurate decay tracking
- Erosion reset mechanisms
- Flexible voting power decay policies
- Easy integration with existing governance systems

## Installation

TODO: Actually publish as foundry package

To install the Voting Decay Library, use the following command:

```bash
forge install yourusername/voting-decay
```

## Usage

Here's a basic example of how to use the Voting Decay Library:

```solidity
pragma solidity ^0.8.0;

import 'voting-decay/VotingDecay.sol';

contract MyGovernance {
  using VotingDecay for VotingDecay.Account;

  mapping(address => VotingDecay.Account) public accounts;

  function vote(uint256 proposalId) external {
    VotingDecay.Account storage account = accounts[msg.sender];
    account.updateDecay();
    uint256 votingPower = account.getCurrentVotingPower();
    // Use votingPower for voting logic
  }

  function refresh() external {
    accounts[msg.sender].refreshDecay();
  }
}
```

## API Reference

### Key Functions

- `calculateDecay(uint256 notionalAmount, uint256 elapsedTime) -> uint256`
- `getCurrentVotingPower(address account) -> uint256`
- `updateDecay(address account)`
- `resetDecay(address account)`
- `applyDecay(address account)`
- `setDecayRate(uint256 rate)`
- `refreshDecay(address account)`

For detailed documentation on each function, please refer to the inline comments in the source code.

## Testing

To run the test suite:

```bash
forge test
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License. This markdown block includes everything from the API
Reference section to the end of the README. You can now easily copy and paste this into your
project's README file.
