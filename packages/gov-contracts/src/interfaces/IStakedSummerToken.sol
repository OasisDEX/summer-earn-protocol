// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStakedSummerToken is IERC20 {
    function mint(address _to, uint256 _amount) external;

    function burn(uint256 _amount) external;

    function burnFrom(address _from, uint256 _amount) external;

    function addStakingModule(address _stakingModule) external;

    error xSumr_InvalidStakingModule(string message);
    error xSumr__NotImplemented();
    error xSumr__NotAuthorized();
    error xSumr_TransferNotAllowed();

    event StakingModuleAdded(address indexed stakingModule);
    event StakingModuleRemoved(address indexed stakingModule);
}
