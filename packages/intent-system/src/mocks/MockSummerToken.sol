// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockSummerToken
 * @notice Mock Summer token contract for testing the intent system
 * @dev Simple ERC20 token with minting capability for testing
 */
contract MockSummerToken is ERC20 {
    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20("Mock Summer Token", "MSUMMER") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints tokens to a specified address (for testing)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
