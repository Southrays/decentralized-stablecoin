// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {Test} from "forge-std/Test.sol";

contract DecentralizedStablecoinTest is Test {
    ///////////////////////////////
    /////     Variables     //////
    /////////////////////////////
    DecentralizedStablecoin private dsc;
    address owner;
    address user;
    uint256 TOKEN_AMOUNT = 100;
    uint256 EXCESS_TOKEN_AMOUNT = 150;
    uint256 ETH_AMOUNT = 10 ether;

    string EXPECTED_NAME = "DecentralizedStablecoin";
    string EXPECTED_SYMBOL = "DSC";

    ///////////////////////////
    /////     SetUp     //////
    /////////////////////////
    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        vm.deal(owner, ETH_AMOUNT);

        vm.startPrank(owner);
        dsc = new DecentralizedStablecoin();
        vm.stopPrank();
    }

    ///////////////////////////////////////
    /////     Constructor Tests     //////
    /////////////////////////////////////
    function testName() public {
        string memory name = dsc.name();
        assertEq(name, EXPECTED_NAME);
    }

    function testSymbol() public {
        string memory symbol = dsc.symbol();
        assertEq(symbol, EXPECTED_SYMBOL);
    }

    ////////////////////////////////
    /////     Mint Tests     //////
    //////////////////////////////
    function test_Mint_RevertsIfToIsZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(DecentralizedStablecoin.DecentralizedStablecoin__NotZeroAddress.selector);
        dsc.mint(address(0), TOKEN_AMOUNT);
        vm.stopPrank();
    }

    function test_Mint_RevertsIfAmountIsZero() public {
        vm.startPrank(owner);
        vm.expectRevert(DecentralizedStablecoin.DecentralizedStablecoin__MustBeMoreThanZero.selector);
        dsc.mint(user, 0);
        vm.stopPrank();
    }

    function test_Mint_Succeeds() public {
        vm.startPrank(owner);
        bool success = dsc.mint(user, TOKEN_AMOUNT);
        vm.stopPrank();

        assertTrue(success);
        assertEq(dsc.balanceOf(user), TOKEN_AMOUNT);
    }

    ////////////////////////////////
    /////     Burn Tests     //////
    //////////////////////////////
    function test_Burn_RevertsIfAmountIsZero() public {
        vm.startPrank(owner);
        vm.expectRevert(DecentralizedStablecoin.DecentralizedStablecoin__MustBeMoreThanZero.selector);
        dsc.burn(0);
        vm.stopPrank();
    }

    function test_Burn_RevertsIfAmountExceedsBalance() public {
        vm.startPrank(owner);
        dsc.mint(user, TOKEN_AMOUNT);
        vm.expectRevert(DecentralizedStablecoin.DecentralizedStablecoin__BurnAmountExceedsBalance.selector);
        dsc.burn(EXCESS_TOKEN_AMOUNT);
        vm.stopPrank();
    }

    function test_Burn_Succeeds() public {
        vm.startPrank(owner);
        dsc.mint(owner, TOKEN_AMOUNT);
        dsc.burn(TOKEN_AMOUNT);
        vm.stopPrank();

        assertEq(dsc.balanceOf(owner), 0);
    }
}
