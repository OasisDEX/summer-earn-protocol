// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

contract FleetCommanderTestMock {
    address private _asset;
    uint256 public maxDepositAmount;
    bool public shouldRevertAsset;
    bool public shouldRevertMaxDeposit;

    constructor(address __asset) {
        _asset = __asset;
        maxDepositAmount = type(uint256).max;
    }

    function setAsset(address __asset) external {
        _asset = __asset;
    }

    function setMaxDeposit(uint256 _maxDeposit) external {
        maxDepositAmount = _maxDeposit;
    }

    function setShouldRevertAsset(bool _shouldRevert) external {
        shouldRevertAsset = _shouldRevert;
    }

    function setShouldRevertMaxDeposit(bool _shouldRevert) external {
        shouldRevertMaxDeposit = _shouldRevert;
    }

    function asset() external view returns (address) {
        if (shouldRevertAsset) {
            revert("Asset reverted");
        }
        return _asset;
    }

    function maxDeposit(address) external view returns (uint256) {
        if (shouldRevertMaxDeposit) {
            revert("MaxDeposit reverted");
        }
        return maxDepositAmount;
    }
}
