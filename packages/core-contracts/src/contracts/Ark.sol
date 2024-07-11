// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import {IArk} from "../interfaces/IArk.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @custom:see IArk
 */
abstract contract Ark is IArk, Initializable, ArkAccessManaged {
    using SafeERC20 for IERC20;

    address public raft;
    uint256 public depositCap;
    uint256 public maxAllocation;
    IERC20 public token;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(BaseArkParams memory params) public initializer {
        ArkAccessManaged.initialize(params.accessManager);
        maxAllocation = params.maxAllocation;

        IConfigurationManager manager = IConfigurationManager(
            params.configurationManager
        );
        raft = manager.raft();
        token = IERC20(params.token);
    }

    /* PUBLIC */
    function totalAssets() public view virtual returns (uint256) {}

    function rate() public view virtual returns (uint256) {}

    function harvest() public {}

    /* EXTERNAL - COMMANDER */
    function board(uint256 amount) external onlyCommander {
        token.safeTransferFrom(msg.sender, address(this), amount);
        _board(amount);

        emit Boarded(msg.sender, address(token), amount);
    }

    function disembark(uint256 amount) external onlyCommander {
        _disembark(amount);
        token.safeTransfer(msg.sender, amount);

        emit Disembarked(msg.sender, address(token), amount);
    }

    /* EXTERNAL - GOVERNANCE */
    function setDepositCap(uint256 newCap) external onlyGovernor {}

    function setRaft(address newRaft) external onlyGovernor {}

    /* INTERNAL */
    function _board(uint256 amount) internal virtual;

    function _disembark(uint256 amount) internal virtual;
}
