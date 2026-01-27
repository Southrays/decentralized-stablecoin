// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDsc} from "../../../script/DeployDsc.s.sol";
import {DecentralizedStablecoin} from "../../../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";

contract PublicViewTests is Test {
    DeployDsc deployer;
    DecentralizedStablecoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;

    address public constant WETH = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;
    address public constant WBTC = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

    address user;
    uint256 public constant AMOUNT = 10 ether;

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, dscEngine, helperConfig) = deployer.run();

        user = makeAddr("user");
        vm.deal(user, 20 ether);
    }

    ////////////////////////////////////////
    /////     Get Usd Value Tests     /////
    //////////////////////////////////////
    // function testGetUsdValue() public {
    //     vm.prank(user);
    //     dscEngine.depositCollateral(WETH, AMOUNT);
    // }
}
