//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";


/**
 * @title DecentralizedStablecoin
 * @author Southrays
 * Collateral: Exogenous (wETH & wBTC) 
 * Minting: Algorithmic
 * Relative Stability: Pegged 1:1 to USD
 * 
 * This is the ERC20 contract for the Decentralized Stablecoin (DSC).
 */
contract DecentralizedStablecoin is ERC20Burnable, Ownable {
    ////////////////////////////
    /////     Errors     //////
    //////////////////////////
    error DecentralizedStablecoin__MustBeOwner(); 
    error DecentralizedStablecoin__MustBeMoreThanZero(); 
    error DecentralizedStablecoin__NotZeroAddress(); 
    error DecentralizedStablecoin__BurnAmountExceedsBalance();


    ///////////////////////////////
    /////     Variables     //////
    /////////////////////////////

    /////////////////////////////////
    /////     Constructor     //////
    ///////////////////////////////
    constructor() ERC20("DecentralizedToken", "DSC") Ownable(msg.sender) {}

    /**
     * This function can only be called by the owner to burn DecentralizedToken (DSC).
     * The owner is the DSCEngine contract.
     * This function burns a specific amount of DecentralizedToken (DSC) from the caller's account.
     * This function ensures that the amount to be burned is greater than zero and does not exceed the caller's balance.
     * @param _amount The amount of DecentralizedToken (DSC) to burn
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) revert DecentralizedStablecoin__MustBeMoreThanZero();
        if (balance < _amount) revert DecentralizedStablecoin__BurnAmountExceedsBalance();
        super.burn(_amount);
    }


    /**
     * This function can only be called by the owner to mint new DecentralizedToken (DSC).
     * The owner is the DSCEngine contract.
     * This function ensures that the recipient address is not the zero address and that the amount to be minted is greater than zero.
     * This function mints a specific amount of DecentralizedToken (DSC) to the specified address.
     * @param _to The address to mint the tokens to.
     * @param _amount The amount of DecentralizedToken (DSC) to mint.
     */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) revert DecentralizedStablecoin__NotZeroAddress();
        if (_amount <= 0) revert DecentralizedStablecoin__MustBeMoreThanZero();
        _mint(_to, _amount);
        return true;
    }
}