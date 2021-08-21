// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "./vaultHelpers.sol";
import "./farms/ifarm.sol";
import "./lenders/ilend.sol";

interface Icomptroller {
  function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
}

abstract contract RoboVault is ERC20, ERC20Detailed, ILend, IFarm {
    /// functionality allowing Robo Vault vaults to interaction with other contracts such as lending, creating LP & harvesting rewards  
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 constant decimalAdj = 1000000; // variable used when calculating (equivant to 1 / 100% for float like operations )
    uint256 public slippageAdj = 990000;
    uint256 public slippageAdjHigh = 1010000;

    IERC20 base;
    IERC20 shortToken;
    IERC20 lp = IERC20(farmLP());
    IERC20 lp_harvestToken = IERC20(farmTokenLp());
    IERC20 harvestToken = IERC20(farmToken());
    IERC20 lend_tokens = IERC20(lendPlatform());
    IERC20 compToken = IERC20(compTokenAddress());
    IERC20 compLP = IERC20(compLpAddress());

    constructor(address _baseToken, address _shortToken) public {
        base = IERC20(_baseToken);
        shortToken = IERC20(_shortToken);

        Icomptroller comptroller = Icomptroller(comptrollerAddress());
        address[] memory cTokens = new address[](1);
        cTokens[0] = lendPlatform();
        comptroller.enterMarkets(cTokens);
    }

    // calculate total value of vault assets 
    function calcPoolValueInToken() public view returns(uint256){
        uint256 collateral = balanceLend();
        uint256 reserves = balanceReserves();
        uint256 debt = balanceDebt();
        uint256 shortInWallet = balanceShortBaseEq(); 
        return (reserves + collateral  - debt + shortInWallet ) ; 
    }





    // calculate debt / collateral - used to trigger rebalancing of debt & collateral 
    function calcCollateral() public view returns(uint256){
        uint256 debt = balanceDebt();
        uint256 collateral = balanceLend();
        uint256 collatRatio = debt.mul(decimalAdj).div(collateral); 
        return (collatRatio);
    }

    function calcLeverage() public view returns(uint256){
        uint256 debt = balanceDebt();
        uint256 collateral = balanceLend();
        uint256 leverageRatio = collateral.mul(decimalAdj).div(collateral.sub(debt)); 
        return (leverageRatio);
    }

    // current % of vault assets held in reserve - used to trigger deployment of assets into strategy
    function calcReserves() public view returns(uint256){
        uint256 bal = base.balanceOf(address(this)); 
        uint256 totalBal = calcPoolValueInToken();
        uint256 reservesRatio = bal.mul(decimalAdj).div(totalBal);
        return (reservesRatio); 
    }


    function convertShortToBaseLP(uint256 _amount) public view returns(uint256){
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        return (_amount.mul(baseLP).div(shortLP));
    } 



    // value of borrowed tokens in value of base tokens
    function balanceDebt() public view returns(uint256) {
        uint256 debt = borrowBalanceStored(address(this));
        return (convertShortToBaseLP(debt));
    }
    
    
    // reserves 
    function balanceReserves() public view returns(uint256){
        return (base.balanceOf(address(this)));
    }
    
    function balanceShort() public view returns(uint256){
        return (shortToken.balanceOf(address(this)));
    }
    
    function balanceShortBaseEq() public view returns(uint256){
        return (convertShortToBaseLP(shortToken.balanceOf(address(this))));
    }
    
    function balanceLend() public view returns(uint256){
        uint256 b = lend_tokens.balanceOf(address(this));
        return (b.mul(lendExchangeRateStored()).div(1e18));
    }

    // lend base tokens to lending platform 
    function _lendBase(uint256 amount) internal {
        lendMint(amount);
    }
    
    // borrow tokens woth _amount of base tokens 
    function _borrowBaseEq(uint256 _amount) internal returns(uint256) {
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 borrowamount = _amount.mul(shortLP).div(baseLP);
        _borrow(borrowamount);
        return (borrowamount);
    }

    function _borrow(uint256 borrowAmount) internal {
        borrow(borrowAmount);
    }
    
    // automatically repays debt using any short tokens held in wallet up to total debt value
    function _repayDebt() internal {
        uint256 _bal = shortToken.balanceOf(address(this)); 
        if (_bal == 0)
            return;

        uint256 _debt =  borrowBalanceStored(address(this)); 
        if (_bal < _debt){
            borrowRepay(_bal);
        }
        else {
            borrowRepay(_debt);
        }
    }

    
    function getDebtShort() public view returns(uint256) {
        uint256 _debt =  borrowBalanceStored(address(this)); 
        return(_debt);
    }
    
    function _getShortInLp() internal view returns (uint256) {
        uint256 short_lp = shortToken.balanceOf(address(lp)); 
        return (short_lp);          
    }
    
    function getBaseInLending() public view returns (uint256) {
        uint256 bal = base.balanceOf(lendPlatform());
        return(bal);
    }
    
    function getBaseInLp() public view returns (uint256) {
        uint256 base_lp = base.balanceOf(address(lp));
        return (base_lp);
    }
    
    function _getHarvestInHarvestLp() internal view returns(uint256) {
        uint256 harvest_lp = harvestToken.balanceOf(farmTokenLp());
        return harvest_lp;          
    }
    
    function _getShortInHarvestLp() internal view returns(uint256) {
        uint256 shortToken_lp = shortToken.balanceOf(farmTokenLp());
        return shortToken_lp;          
    }
    
    function _redeemBase(uint256 _redeem_amount) internal {
        lendRedeemUnderlying(_redeem_amount); 
    }

    function countLpPooled() public view returns(uint256){
        uint256 lpPooled = farmUserInfo(farmPid(), address(this));
        return lpPooled;
    }
    

    function _pathBaseToShort() internal virtual view returns (address[] memory) {
        address[] memory pathSwap = new address[](2);
        pathSwap[0] = address(base);
        pathSwap[1] = address(shortToken);
        return pathSwap;
    }

    function _pathShortToBase() internal virtual view returns (address[] memory) {
        address[] memory pathSwap = new address[](2);
        pathSwap[0] = address(shortToken);
        pathSwap[1] = address(base);
        return pathSwap;
    }

    function _swapBaseShort(uint256 _amount) internal {
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 amountOutMin = _amount.mul(shortLP).mul(slippageAdj).div(baseLP).div(decimalAdj);
        farmSwapExactTokensForTokens(_amount, amountOutMin, _pathBaseToShort(), address(this), block.timestamp + 120);
    }
    
    function _swapShortBase(uint256 _amount) internal {
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 amountOutMin = _amount.mul(baseLP).mul(slippageAdj).div(decimalAdj).div(shortLP);
        farmSwapExactTokensForTokens(_amount, amountOutMin, _pathShortToBase(), address(this), block.timestamp + 120);
    }
    
    function _swapBaseShortExact(uint256 _amountOut) internal {
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 amountInMax = _amountOut.mul(baseLP).mul(slippageAdjHigh).div(decimalAdj).div(shortLP);
        farmSwapExactTokensForTokens(_amountOut, amountInMax, _pathBaseToShort(), address(this), block.timestamp + 120);
    }
}

