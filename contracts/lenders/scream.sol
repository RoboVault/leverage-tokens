// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../vaultHelpers.sol";
import "./ilend.sol";

interface BORROW {
    /// interface for borrowing from CREAM
    function borrow(uint256 borrowAmount) external returns (uint256); 
    function borrowBalanceStored(address account) external view returns (uint);
    function repayBorrow(uint repayAmount) external; /// borrowAmount: The amount of the underlying borrowed asset to be repaid. A value of -1 (i.e. 2^256 - 1) can be used to repay the full amount.
}

interface LEND {
    /// interface for depositing into CREAM
    function mint(uint256 mintAmount) external; 
    function redeem(uint redeemTokens) external; 
    function redeemUnderlying(uint redeemAmount) external; 
    function balanceOf(address owner) external view returns (uint256); 
    function exchangeRateCurrent() external view returns (uint256);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    function balanceOfUnderlying(address) external view returns (uint256);
}

interface REWARDS {
    function claimComp(address holder) external;
}

abstract contract Scream is ILend {

    /*
    * Cream common addresses
    */
    function borrowPlatform() public view virtual override returns (address) {
        return 0x5AA53f03197E08C4851CAD8C92c7922DA5857E5d;
    }
    function comptrollerAddress() public view override returns (address) {
        return 0x260E596DAbE3AFc463e75B6CC05d8c46aCAcFB09;
    }
    function compTokenAddress() public view override returns (address) {
        return 0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475;
    }
    function compLpAddress() public view override returns (address) {
        return 0x30872e4fc4edbFD7a352bFC2463eb4fAe9C09086;
    }

    /*
    * Borrow Methods
    */
    function borrow(uint256 _borrowAmount) internal override returns (uint256) {
        return BORROW(borrowPlatform()).borrow(_borrowAmount);
    } 
    function borrowBalanceStored(address _account) internal view override returns (uint) {
        return BORROW(borrowPlatform()).borrowBalanceStored(_account);
    }
    function borrowRepay(uint _repayAmount) internal override {
        BORROW(borrowPlatform()).repayBorrow(_repayAmount);
    }

    /*
    * Lend Methods
    */
    function lendMint(uint256 _mintAmount) internal override {
        LEND(lendPlatform()).mint(_mintAmount);
    }
    function lendRedeem(uint _redeemTokens) internal override {
        LEND(lendPlatform()).redeem(_redeemTokens);
    }
    function lendRedeemUnderlying(uint _redeemAmount) internal override {
        LEND(lendPlatform()).redeemUnderlying(_redeemAmount);
    }
    function lendBalanceOf(address _owner) internal view override returns (uint256) {
        return LEND(lendPlatform()).balanceOf(_owner);
    }
    function lendExchangeRateCurrent() internal view override returns (uint256) {
        return LEND(lendPlatform()).exchangeRateCurrent();
    }
    function lendExchangeRateStored() internal view override returns (uint) {
        return LEND(lendPlatform()).exchangeRateStored();
    }
    function lendGetCash() internal view override returns (uint) {
        return LEND(lendPlatform()).getCash();
    }
    function lendBalanceOfUnderlying(address _addr) internal view override returns (uint256) {
        return LEND(lendPlatform()).balanceOfUnderlying(_addr);
    }

    function claimComp() internal override {
        REWARDS(comptrollerAddress()).claimComp(address(this));
    }
}

        