// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {FleetCommanderFactory} from "../../src/contracts/FleetCommanderFactory.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {FactoryArkConfig} from "../../src/interfaces/IFleetCommanderFactory.sol";
import {CompoundV3Ark} from "../../src/contracts/arks/CompoundV3Ark.sol";
import {AaveV3Ark} from "../../src/contracts/arks/AaveV3Ark.sol";
import {BaseArkParams} from "../../src/types/ArkTypes.sol";

/**
 * @title Deposit test suite for FleetCommanderFactory
 */
contract FleetCommanderFactoryTest is
    Test,
    ArkTestHelpers,
    FleetCommanderTestBase
{
    FleetCommanderFactory public fleetCommanderFactory;
    address public immutable USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public immutable AAVE_V3_POOL =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public immutable COMPOUND_V3_USDC =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;

    function setUp() public {
        FleetCommanderFactory fleetCommanderFactoryImp = new FleetCommanderFactory();
        fleetCommanderFactory = FleetCommanderFactory(
            Clones.clone(address(fleetCommanderFactoryImp))
        );

        vm.prank(governor);
        accessManager.grantFactoryRole(address(fleetCommanderFactory));

        fleetCommanderFactory.initialize(
            address(fleetCommanderImp),
            address(accessManager)
        );
    }

    function test_CreateFleetCommander() public {
        FactoryArkConfig[] memory arkConfigs = new FactoryArkConfig[](2);

        bytes memory encodedParams = abi.encode(
            address(fleetCommanderFactory),
            AAVE_V3_POOL
        );
        console.logBytes(encodedParams);

        arkConfigs[0] = FactoryArkConfig({
            baseArkParams: BaseArkParams({
                accessManager: address(accessManager),
                token: USDC,
                configurationManager: address(configurationManager),
                maxAllocation: 10000 * 10 ** 6
            }),
            specificArkParams: abi.encode(
                address(fleetCommanderFactory),
                AAVE_V3_POOL
            ),
            arkImplementation: address(mockArkImp)
        });

        arkConfigs[1] = FactoryArkConfig({
            baseArkParams: BaseArkParams({
                accessManager: address(accessManager),
                token: USDC,
                configurationManager: address(configurationManager),
                maxAllocation: 10000 * 10 ** 6
            }),
            specificArkParams: abi.encode(
                address(fleetCommanderFactory),
                COMPOUND_V3_USDC
            ),
            arkImplementation: address(mockArkImp)
        });

        vm.startPrank(governor);
        FleetCommander newFleetCommander = FleetCommander(
            fleetCommanderFactory.createFleetCommander(
                fleetCommanderParams,
                arkConfigs
            )
        );
        vm.stopPrank();

        assertEq(newFleetCommander.arks().length, 2);
    }
}
