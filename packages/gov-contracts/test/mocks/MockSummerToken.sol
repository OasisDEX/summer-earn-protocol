// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {VotingDecayLibrary} from "@summerfi/voting-decay/VotingDecayLibrary.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {IGovernanceRewardsManager} from "../../src/interfaces/IGovernanceRewardsManager.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {IOFT, SendParam, MessagingFee, MessagingReceipt, OFTReceipt, OFTLimit, OFTFeeDetail} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

contract MockSummerToken is ERC20, ERC20Burnable, ISummerToken {
    uint256 private constant INITIAL_SUPPLY = 1e9;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, INITIAL_SUPPLY * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function getVotes(address) external pure override returns (uint256) {
        return 0;
    }

    // Add missing implementations:
    function DOMAIN_SEPARATOR() external pure override returns (bytes32) {
        // Implement or revert
        revert("Not implemented");
    }

    function nonces(address) external pure override returns (uint256) {
        // Implement or revert
        revert("Not implemented");
    }

    function permit(
        address,
        address,
        uint256,
        uint256,
        uint8,
        bytes32,
        bytes32
    ) external pure override {
        // Implement or revert
        revert("Not implemented");
    }

    function delegate(address) external pure {
        revert("Not implemented");
    }

    function delegateBySig(
        address,
        uint256,
        uint256,
        uint8,
        bytes32,
        bytes32
    ) external pure {
        revert("Not implemented");
    }

    function delegates(address) external pure returns (address) {
        revert("Not implemented");
    }

    function getPastTotalSupply(uint256) external pure returns (uint256) {
        revert("Not implemented");
    }

    function getPastVotes(address, uint256) external pure returns (uint256) {
        revert("Not implemented");
    }

    function getRawVotesAt(address, uint256) external pure returns (uint256) {
        revert("Not implemented");
    }

    function addToWhitelist(address) external pure override {
        revert("Not implemented");
    }

    function enableTransfers() external pure override {
        revert("Not implemented");
    }

    function removeFromWhitelist(address) external pure override {
        revert("Not implemented");
    }

    function testSkipper() external pure {
        revert("Not implemented");
    }

    function setDecayManager(address, bool) external pure {
        revert("Not implemented");
    }

    function rewardsManager() external pure returns (address) {
        revert("Not implemented");
    }

    function getDecayFreeWindow() external pure returns (uint40) {
        revert("Not implemented");
    }

    function getDecayFunction()
        external
        pure
        returns (VotingDecayLibrary.DecayFunction)
    {
        revert("Not implemented");
    }

    function getDecayRatePerYear() external pure returns (Percentage) {
        revert("Not implemented");
    }

    function getDecayFactor(address) external pure returns (uint256) {
        return Constants.WAD;
    }

    function getPastDecayFactor(
        address,
        uint256
    ) external pure returns (uint256) {
        revert("Not implemented");
    }

    function getVotingPower(address, uint256) external pure returns (uint256) {
        revert("Not implemented");
    }

    function setDecayRatePerYear(Percentage) external pure {
        revert("Not implemented");
    }

    // Fix the parameter type for setDecayFreeWindow
    function setDecayFreeWindow(uint40) external pure {
        revert("Not implemented");
    }

    function getDecayInfo(
        address
    ) external pure returns (VotingDecayLibrary.DecayInfo memory) {
        revert("Not implemented");
    }

    function setDecayFunction(VotingDecayLibrary.DecayFunction) external pure {
        revert("Not implemented");
    }

    function updateDecayFactor(address) external pure {
        return;
    }

    function getDelegationChainLength(address) external pure returns (uint256) {
        return 0;
    }

    function approvalRequired() external pure override returns (bool) {
        // Mock implementation
        return false;
    }

    function oftVersion()
        external
        pure
        override
        returns (bytes4 interfaceId, uint64 version)
    {
        // Mock implementation
        return (bytes4(keccak256("OFT")), 1);
    }

    function quoteOFT(
        SendParam calldata
    )
        external
        pure
        returns (
            OFTLimit memory oftLimit,
            OFTFeeDetail[] memory oftFeeDetails,
            OFTReceipt memory oftReceipt
        )
    {
        // Properly initialize an empty array for OFTFeeDetail
        OFTFeeDetail[] memory feeDetails = new OFTFeeDetail[](0);

        return (OFTLimit(0, 0), feeDetails, OFTReceipt(0, 0));
    }

    function quoteSend(
        SendParam calldata,
        bool
    ) external pure override returns (MessagingFee memory) {
        // Mock implementation
        return MessagingFee(0, 0);
    }

    function send(
        SendParam calldata,
        MessagingFee calldata,
        address
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory) {
        // Correctly initialize MessagingReceipt with appropriate types
        return (
            MessagingReceipt(bytes32(0), 0, MessagingFee(0, 0)),
            OFTReceipt(0, 0)
        );
    }

    function sharedDecimals() external pure override returns (uint8) {
        // Mock implementation
        return 18;
    }

    function token() external view override returns (address) {
        // Mock implementation
        return address(this);
    }
}
