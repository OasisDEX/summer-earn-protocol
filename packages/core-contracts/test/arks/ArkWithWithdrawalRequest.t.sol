// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ArkTestBase} from "./ArkTestBase.sol";
import {ArkWithWithdrawalRequest} from "../../src/contracts/ArkWithWithdrawalRequest.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract USDTLikeMock is MockERC20 {
    constructor() {
        initialize("USDT", "USDT", 6);
    }

    // USDT-like approve that reverts if modifying a non-zero allowance to a non-zero amount
    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        if (amount != 0 && _allowance[msg.sender][spender] != 0) {
            revert("USDT: approve from non-zero to non-zero");
        }
        return super.approve(spender, amount);
    }
}

contract MockRouter {
    address public sellToken;
    address public buyToken;
    constructor(address _sellToken, address _buyToken) {
        sellToken = _sellToken;
        buyToken = _buyToken;
    }
    function swap(uint256 amountIn, uint256 amountOutMin) external {
        IERC20(sellToken).transferFrom(msg.sender, address(this), amountIn);
        IERC20(buyToken).transfer(msg.sender, amountOutMin);
    }
}

contract MockArkWithWithdrawalRequest is ArkWithWithdrawalRequest {
    constructor(
        ArkParams memory params,
        uint256 slippage
    ) ArkWithWithdrawalRequest(params, slippage) {}

    function setCommander(address _commander) external {
        config.commander = _commander;
    }

    function expose_swap(
        address sellToken,
        address buyToken,
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes memory swapCalldata
    ) external returns (uint256) {
        return
            _swap(
                sellToken,
                buyToken,
                router,
                amountIn,
                amountOutMin,
                swapCalldata
            );
    }

    function expose_boardToBufferArk(uint256 amount) external {
        _boardToBufferArk(amount);
    }

    function expose_whitelistRouter(address router, bool status) external {
        whitelistedRouters[router] = status;
    }

    // Abstract overrides
    function _board(uint256, bytes calldata) internal override {}
    function _disembark(uint256, bytes calldata) internal override {}
    function _harvest(
        bytes calldata
    ) internal override returns (address[] memory, uint256[] memory) {
        return (new address[](0), new uint256[](0));
    }
    function _validateBoardData(bytes calldata) internal override {}
    function _validateDisembarkData(bytes calldata) internal override {}
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        return 0;
    }
    function assetsInWithdrawalQueue() external view returns (uint256) {
        return 0;
    }
    function claimWithdrawal() external {}
    function isWithdrawalClaimRequired() external view returns (bool) {
        return false;
    }
    function requestWithdrawal(uint256) external {}
    function withdrawUsingSwap(uint256, bytes calldata) external {}
    function withdrawalRequestId() external view returns (uint256) {
        return 0;
    }
}

contract ArkWithWithdrawalRequestTest is ArkTestBase {
    MockArkWithWithdrawalRequest public ark;
    USDTLikeMock public asset;
    USDTLikeMock public sellToken;
    MockRouter public router;
    address public testBufferArk;

    function setUp() public {
        initializeCoreContracts();

        asset = new USDTLikeMock();
        sellToken = new USDTLikeMock();

        (
            address _commander,
            address _bufferArk
        ) = setupFleetCommanderWithBufferArk(address(asset), "Fleet");
        testBufferArk = _bufferArk;
        router = new MockRouter(address(sellToken), address(asset));

        ArkParams memory params = ArkParams({
            name: "Mock Ark",
            details: "Details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(asset),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: Percentage.wrap(0)
        });

        ark = new MockArkWithWithdrawalRequest(params, 0); // slippage = 0

        // Register Ark with ConfigurationManager so we can bypass some checks?
        // Let's just manually set commander.
        ark.setCommander(_commander);

        // Give router some assets
        asset.mint(address(router), 1000000);
    }

    function test_ForceApprove_Swap() public {
        ark.expose_whitelistRouter(address(router), true);
        sellToken.mint(address(ark), 1000);

        // Pre-approve the router to simulate non-zero allowance
        vm.startPrank(address(ark));
        sellToken.approve(address(router), 1);
        vm.stopPrank();

        // Ensure that our USDT mock reverts on naive approve
        vm.startPrank(address(ark));
        vm.expectRevert("USDT: approve from non-zero to non-zero");
        sellToken.approve(address(router), 1000);
        vm.stopPrank();

        // expose_swap uses forceApprove, so it should succeed!
        bytes memory swapCalldata = abi.encodeWithSelector(
            MockRouter.swap.selector,
            500,
            500
        );
        ark.expose_swap(
            address(sellToken),
            address(asset),
            address(router),
            500,
            500,
            swapCalldata
        );

        assertEq(asset.balanceOf(address(ark)), 500);
    }

    function test_ForceApprove_BoardToBufferArk() public {
        asset.mint(address(ark), 1000);

        address _bufferArk = testBufferArk;

        // Pre-approve the bufferArk to simulate non-zero allowance
        vm.startPrank(address(ark));
        asset.approve(_bufferArk, 1);
        vm.stopPrank();

        // Ensure mock reverts on naive approve
        vm.startPrank(address(ark));
        vm.expectRevert("USDT: approve from non-zero to non-zero");
        asset.approve(_bufferArk, 1000);
        vm.stopPrank();

        // Mock board call so it doesn't revert with CallerIsNotAuthorizedToBoard
        vm.mockCall(
            _bufferArk,
            abi.encodeWithSignature("board(uint256,bytes)"),
            ""
        );

        // Should succeed because of forceApprove
        ark.expose_boardToBufferArk(1000);
    }
}
