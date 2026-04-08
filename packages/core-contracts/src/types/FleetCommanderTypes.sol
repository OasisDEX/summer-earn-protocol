// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "../interfaces/IArk.sol";

import {IFleetCommanderRewardsManager} from "../interfaces/IFleetCommanderRewardsManager.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @notice Configuration parameters for the FleetCommander contract
 * @param name The name of the fleet commander (ERC20)
 * @param details A string containing additional information about the fleet commander
 * @param symbol The symbol of the fleet commander share token (ERC20)
 * @param configurationManager The address of the ConfigurationManager contract
 * @param accessManager The address of the ProtocolAccessManager contract
 * @param asset The address of the underlying asset for the fleet
 * @param initialMinimumBufferBalance The initial minimum balance to be kept in the buffer ark
 * @param initialRebalanceCooldown The initial cooldown period between rebalancing operations
 * @param depositCap The initial total deposit cap for the fleet
 * @param initialTipRate The initial rate for tips/fees
 */
struct FleetCommanderParams {
    string name;
    string details;
    string symbol;
    address configurationManager;
    address accessManager;
    address asset;
    uint256 initialMinimumBufferBalance;
    uint256 initialRebalanceCooldown;
    uint256 depositCap;
    Percentage initialTipRate;
}

/**
 * @notice Configuration parameters for the FleetCommanderWhitelist contract
 * @param name The name of the fleet commander (ERC20)
 * @param details A string containing additional information about the fleet commander
 * @param symbol The symbol of the fleet commander share token (ERC20)
 * @param configurationManager The address of the ConfigurationManager contract
 * @param accessManager The address of the ProtocolAccessManagerV2 contract
 * @param asset The address of the underlying asset for the fleet
 * @param initialMinimumBufferBalance The initial minimum balance to be kept in the buffer ark
 * @param initialRebalanceCooldown The initial cooldown period between rebalancing operations
 * @param depositCap The initial total deposit cap for the fleet
 * @param initialTipRate The initial rate for tips/fees
 * @param isOperatorGatewayOpen Initial status of the operator gateway.
 *      Entry (deposit/mint) and exit (withdraw/redeem) operations are gated by the operator gateway.
 *      When the gateway is closed, only accounts with the OPERATOR_ROLE can perform these actions.
 *      When the gateway is open, all whitelisted accounts can perform these actions.
 */
struct FleetCommanderWhitelistParams {
    string name;
    string details;
    string symbol;
    address configurationManager;
    address accessManager;
    address asset;
    uint256 initialMinimumBufferBalance;
    uint256 initialRebalanceCooldown;
    uint256 depositCap;
    Percentage initialTipRate;
    bool isOperatorGatewayOpen;
}

/**
 * @notice Configuration parameters for the FleetCommanderDao contract
 * @param name The name of the fleet commander (ERC20)
 * @param details A string containing additional information about the fleet commander
 * @param symbol The symbol of the fleet commander share token (ERC20)
 * @param configurationManager The address of the ConfigurationManager contract
 * @param accessManager The address of the ProtocolAccessManager contract
 * @param asset The address of the underlying asset for the fleet
 * @param initialMinimumBufferBalance The initial minimum balance to be kept in the buffer ark
 * @param initialRebalanceCooldown The initial cooldown period between rebalancing operations
 * @param depositCap The initial total deposit cap for the fleet
 * @param initialTipRate The initial rate for tips/fees
 * @param tipJar The address of the tip jar contract
 */
struct FleetCommanderDaoParams {
    string name;
    string details;
    string symbol;
    address configurationManager;
    address accessManager;
    address asset;
    uint256 initialMinimumBufferBalance;
    uint256 initialRebalanceCooldown;
    uint256 depositCap;
    Percentage initialTipRate;
    address tipJar;
}

/**
 * @title FleetConfig
 * @notice Configuration parameters for the FleetCommander contract
 * @dev This struct encapsulates the mutable configuration settings of a FleetCommander.
 *      These parameters can be updated during the contract's lifecycle to adjust its behavior.
 */
struct FleetConfig {
    /**
     * @notice The buffer Ark associated with this FleetCommander
     * @dev This Ark is used as a temporary holding area for funds before they are allocated
     *      to other Arks or when they need to be quickly accessed for withdrawals.
     */
    IArk bufferArk;
    /**
     * @notice The minimum balance that should be maintained in the buffer Ark
     * @dev This value is used to ensure there's always a certain amount of funds readily
     *      available for withdrawals or rebalancing operations. It's denominated in the
     *      smallest unit of the underlying asset (e.g., wei for ETH).
     */
    uint256 minimumBufferBalance;
    /**
     * @notice The maximum total value of assets that can be deposited into the FleetCommander
     * @dev This cap helps manage the total assets under management and can be used to
     *      implement controlled growth strategies. It's denominated in the smallest unit
     *      of the underlying asset.
     */
    uint256 depositCap;
    /**
     * @notice The maximum number of rebalance operations in a single rebalance
     */
    uint256 maxRebalanceOperations;
    /**
     * @notice The address of the staking rewards contract
     */
    address stakingRewardsManager;
}

/**
 * @title FleetConfigWhitelist
 * @notice Configuration parameters for the FleetCommanderWhitelist contract
 */
struct FleetConfigWhitelist {
    /**
     * @notice The buffer Ark associated with this FleetCommanderWhitelist
     * @dev This Ark is used as a temporary holding area for funds before they are allocated
     *      to other Arks or when they need to be quickly accessed for withdrawals.
     */
    IArk bufferArk;
    /**
     * @notice The minimum balance that should be maintained in the buffer Ark
     * @dev This value is used to ensure there's always a certain amount of funds readily
     *      available for withdrawals or rebalancing operations. It's denominated in the
     *      smallest unit of the underlying asset (e.g., wei for ETH).
     */
    uint256 minimumBufferBalance;
    /**
     * @notice The maximum total value of assets that can be deposited into the FleetCommanderWhitelist
     * @dev This cap helps manage the total assets under management and can be used to
     *      implement controlled growth strategies. It's denominated in the smallest unit
     *      of the underlying asset.
     */
    uint256 depositCap;
    /**
     * @notice The maximum number of rebalance operations in a single rebalance
     */
    uint256 maxRebalanceOperations;
    /**
     * @notice The address of the staking rewards contract
     */
    address stakingRewardsManager;
    /**
     * @notice If true, the operator gateway is open to everyone (subject to whitelist)
     * @dev Entry (deposit/mint) and exit (withdraw/redeem) operations are gated by the operator gateway.
     *      When the gateway is closed, only accounts with the OPERATOR_ROLE can perform these actions.
     *      When the gateway is open, all whitelisted accounts can perform these actions.
     */
    bool isOperatorGatewayOpen;
}

/**
 * @title FleetConfigDao
 * @notice Configuration parameters for the FleetCommanderDao contract
 * @dev This struct encapsulates the mutable configuration settings of a FleetCommanderDao.
 *      These parameters can be updated during the contract's lifecycle to adjust its behavior.
 */
struct FleetConfigDao {
    /**
     * @notice The buffer Ark associated with this FleetCommanderDao
     * @dev This Ark is used as a temporary holding area for funds before they are allocated
     *      to other Arks or when they need to be quickly accessed for withdrawals.
     */
    IArk bufferArk;
    /**
     * @notice The minimum balance that should be maintained in the buffer Ark
     * @dev This value is used to ensure there's always a certain amount of funds readily
     *      available for withdrawals or rebalancing operations. It's denominated in the
     *      smallest unit of the underlying asset (e.g., wei for ETH).
     */
    uint256 minimumBufferBalance;
    /**
     * @notice The maximum total value of assets that can be deposited into the FleetCommanderDao
     * @dev This cap helps manage the total assets under management and can be used to
     *      implement controlled growth strategies. It's denominated in the smallest unit
     *      of the underlying asset.
     */
    uint256 depositCap;
    /**
     * @notice The maximum number of rebalance operations in a single rebalance
     */
    uint256 maxRebalanceOperations;
    /**
     * @notice Kept for backward compatibility with the old staking rewards manager
     */
    address _stakingRewardsManager;
    /**
     * @notice The address of the tip jar (DAO vaults do not use the global tip jar)
     */
    address tipJar;
}

/**
 * @notice Data structure for the rebalance event
 * @param fromArk The address of the Ark from which assets are moved
 * @param toArk The address of the Ark to which assets are moved
 * @param amount The amount of assets being moved
 * @param boardData The data to be passed to the `board` function of the `toArk`
 * @param disembarkData The data to be passed to the `disembark` function of the `fromArk`
 * @dev if the `boardData` or `disembarkData` is not needed, it should be an empty byte array
 */
struct RebalanceData {
    address fromArk;
    address toArk;
    uint256 amount;
    bytes boardData;
    bytes disembarkData;
}

/**
 * @title ArkData
 * @dev Struct to store information about an Ark.
 * This struct holds the address of the Ark and the total assets it holds.
 * @dev used in the caching mechanism for the FleetCommander
 */
struct ArkData {
    /// @notice The address of the Ark.
    address arkAddress;
    /// @notice The total assets held by the Ark.
    uint256 totalAssets;
}
