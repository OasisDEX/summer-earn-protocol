// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPot {
    function dsr() external view returns (uint256);
    function chi() external view returns (uint256);
    function rho() external view returns (uint256);
}

contract SDAIArk is Ark {
    using SafeERC20 for IERC20;

    IERC4626 public immutable sDAI;
    IPot public immutable pot;

    uint256 private constant RAY = 1e27;
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    constructor(
        address _sDAI,
        address _pot,
        ArkParams memory _params
    ) Ark(_params) {
        sDAI = IERC4626(_sDAI);
        pot = IPot(_pot);

        // Approve sDAI to spend DAI
        config.token.approve(_sDAI, type(uint256).max);
    }

    function rate() public view override returns (uint256) {
        uint256 dsrRate = pot.dsr();
        // Convert DSR (per second rate) to APY
        return _rpow(dsrRate, SECONDS_PER_YEAR, RAY) - RAY;
    }

    function totalAssets() public view override returns (uint256) {
        return sDAI.maxWithdraw(address(this));
    }

    function _board(uint256 amount) internal override {
        sDAI.deposit(amount, address(this));
    }

    function _disembark(uint256 amount) internal override {
        sDAI.withdraw(amount, address(this), address(this));
    }

    function _harvest(
        address,
        bytes calldata
    ) internal override returns (uint256) {
        // SDAI automatically accrues interest, so no manual harvesting is needed
        return 0;
    }

    function _rpow(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    z := base
                }
                default {
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    z := base
                }
                default {
                    z := x
                }
                let half := div(base, 2) // for rounding.
                for {
                    n := div(n, 2)
                } n {
                    n := div(n, 2)
                } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) {
                        revert(0, 0)
                    }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }
                    x := div(xxRound, base)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                            revert(0, 0)
                        }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }
                        z := div(zxRound, base)
                    }
                }
            }
        }
    }
}
