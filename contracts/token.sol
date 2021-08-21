// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./vault.sol";
import "./vaultHelpers.sol";
import "./farms/ifarm.sol";
import "./lenders/ilend.sol";


abstract contract RoboController is ReentrancyGuard, Ownable, RoboVault {
    /// functionality allowing for Robo Vault vaults to maintain it's strategic position over time
    /// enable users to deposit and withdraw from Robo Vault vaults
    /// security measures to undeploy funds from strategy to vault reserves 
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    address public strategist = 0xD074CDae76496d81Fab83023fee4d8631898bBAf;
    address public keeper = 0x7642604866B546b8ab759FceFb0C5c24b296B925;
    /// default allocations, thresholds & fees
    uint256 public collatUpper = 550000; 
    uint256 public collatLower = 450000;  
    uint256 public operationalFee = 50000;

    
    uint256 public lastHarvest;

    uint256 public depositFee = 25000;
    uint256 public withdrawalFee = 25000;
    uint256 public reserveAllocation = 50000;
    uint256 public depositLimit = uint256(-1); // max deposit 
    uint256 public cRatioDeploy = 525000;


    // protocal limits & upper, target and lower thresholds for ratio of debt to collateral 
    uint256 constant collatLimit = 750000;

    // upper limit for fees so owner cannot maliciously increase fees
    uint256 constant operationalFeeLimit = 50000;
    uint256 constant profitFeeLimit = 100000;
    uint256 constant withdrawalFeeLimit = 5000; // only applies when funds are removed from strat & not reserves
    uint256 constant reserveAllocationLimit = 50000; 


    event UpdatedStrategist(address newStrategist);
    event UpdatedKeeper(address newKeeper);
    
    constructor (address _base, address _short) public 
        RoboVault(_base, _short) 
    {
        approveContracts();
        lastHarvest = block.timestamp;
    }

    // modifiers 
    modifier onlyAuthorized() {
        require(msg.sender == strategist || msg.sender == owner());
        _;
    }

    modifier onlyKeepers() {
        require(msg.sender == keeper || msg.sender == strategist || msg.sender == owner());
        _;
    }
    
    /// before withdrawing from strat check there is enough liquidity in lending protocal 
    function _liquidityCheck(uint256 _amount) internal view {
        uint256 lendBal = getBaseInLending();
        require(lendBal > _amount, "CREAM Currently has insufficent liquidity of base token to complete withdrawal.");
        
        
    }
    
    function approveContracts() public onlyAuthorized {
        base.safeApprove(lendPlatform(), uint256(-1));
        shortToken.safeApprove(borrowPlatform(), uint256(-1));
        base.safeApprove(routerAddress(), uint256(-1));
        shortToken.safeApprove(routerAddress(), uint256(-1));
        harvestToken.safeApprove(routerAddress(), uint256(-1));
        compToken.safeApprove(routerAddress(), uint256(-1));

    }
        
    function resetApprovals( ) external onlyAuthorized {
        base.safeApprove(lendPlatform(), 0);
        shortToken.safeApprove(borrowPlatform(), 0);
        base.safeApprove(routerAddress(), 0);
        shortToken.safeApprove(routerAddress(), 0);
        harvestToken.safeApprove(routerAddress(), 0);

    }
    
    /// update strategist -> this is the address that receives fees + can complete rebalancing and update strategy thresholds
    /// strategist can also exit leveraged position i.e. withdraw all pooled LP and repay outstanding debt moving vault funds to reserves
    function setStrategist(address _strategist) external onlyAuthorized {
        require(_strategist != address(0));
        strategist = _strategist;
        emit UpdatedStrategist(_strategist);
    }
    /// keeper has ability to copmlete rebalancing functions & also deploy capital to strategy once reserves exceed some threshold
    function setKeeper(address _keeper) external onlyAuthorized {
        require(_keeper != address(0));
        keeper = _keeper;
        emit UpdatedKeeper(_keeper);
    }

    function setSlippageAdj(uint256 _lower, uint256 _upper) external onlyAuthorized{
        slippageAdj = _lower; 
        slippageAdjHigh = _upper;
        
    }


    
    function setCollateralThresholds(uint256 _lower, uint256 _upper, uint256 _target) external onlyAuthorized {
        require(collatLimit > _upper);
        require(_upper >= _target);
        require(_target >= _lower);
        collatUpper = _upper; 
        collatLower = _lower;
    }
    
    function setFundingAllocations(uint256 _reserveAllocation, uint256 _cRatioDeploy) external onlyAuthorized {

        
        require(_reserveAllocation <= reserveAllocationLimit); 
        require(_cRatioDeploy <= collatLimit);
        reserveAllocation = _reserveAllocation;
        cRatioDeploy = _cRatioDeploy; 
        
    }
    
    function setFees(uint256 _withdrawalFee, uint256 _operationalFee, uint256 _profitFee) external onlyAuthorized {
        require(_withdrawalFee <= withdrawalFeeLimit);
        require(_operationalFee <= operationalFeeLimit);
        require(_profitFee <= profitFeeLimit);

        operationalFee = _operationalFee;
        withdrawalFee = _withdrawalFee; 
    }
    /// this is the withdrawl fee when user withdrawal results in removal of funds from strategy (i.e. withdrawal in excess of reserves)
    function _calcWithdrawalFee(uint256 _r) internal view returns(uint256) {
        uint256 _fee = _r.mul(withdrawalFee).div(decimalAdj);
        return(_fee);
    }
    


    /// function to deploy funds when reserves exceed reserve threshold (maximum is five percent)
    function deployStrat() external onlyKeepers {
        _operationalFeeHarvest();
        uint256 bal = base.balanceOf(address(this)); 
        uint256 totalBal = calcPoolValueInToken();
        uint256 reserves = totalBal.mul(reserveAllocation).div(decimalAdj);
        if (bal > reserves){
            _deployCapital(reserves);
        }
        
    }
    // deploy assets according to vault strategy    
    function _deployCapital(uint256 _reserves) internal {
        uint256 _nLoops = 5; 
        uint256 _amount;
        for (uint256 i = 0; i < _nLoops; i++) {

            uint256 bal = base.balanceOf(address(this)); 
            _amount = bal.sub(_reserves);            
            _lendBase(_amount);
            uint256 borrowAmtBase = _amount.mul(cRatioDeploy).div(decimalAdj);
            _borrowBaseEq(borrowAmtBase);
            _swapShortBase(shortToken.balanceOf(address(this)));
            

        }
        uint256 bal = base.balanceOf(address(this)); 
        _amount = bal.sub(_reserves);            
        _lendBase(_amount);

    }

    function _operationalFeeHarvest() internal {
        uint256 timeSinceHarvest = (block.timestamp).sub(lastHarvest);
        uint256 annualAdj = uint256(365).mul(24).mul(60).mul(60);
        uint256 operationalFeeNow = operationalFee.mul(timeSinceHarvest).mul(totalSupply()).div(decimalAdj).div(annualAdj);
        _mint(owner(), operationalFeeNow);
        lastHarvest = block.timestamp;
    }


    function operationalFeeHarvest() external onlyAuthorized {
        _operationalFeeHarvest();
    }
    
    /*
    function _deployCapital(uint256 _amount) external onlyAuthorized {
        uint256 lendDeposit = stratLendAllocation.mul(_amount).div(decimalAdj);
        _lendBase(lendDeposit); 
        uint256 borrowAmtBase = stratDebtAllocation.mul(_amount).div(decimalAdj); 
        uint256 borrowAmt = _borrowBaseEq(borrowAmtBase);
        _addToLP(borrowAmt);
        _depoistLp();
    }
    */

    // user deposits token to vault in exchange for pool shares which can later be redeemed for assets + accumulated yield
    function deposit(uint256 _amount) public nonReentrant
    {
        require(_amount > 0, "deposit must be greater than 0");
        uint256 pool = calcPoolValueInToken();
        
        uint256 _amountAdj = _amount.mul(decimalAdj.sub(depositFee)).div(decimalAdj); 

        base.transferFrom(msg.sender, address(this), _amount);

        // Calculate pool shares
        uint256 shares = 0;
        if (totalSupply() == 0) {
            require(_amount <= depositLimit, "Over deposit Limit");
            shares = _amount;
        } else {
            uint256 currentBalance = (pool.mul(balanceOf(msg.sender)).div(totalSupply());
            require(_amount.add(currentBalance) <= depositLimit, "Over deposit Limit");
            shares = (_amountAdj.mul(totalSupply())).div(pool);
        }
        _mint(msg.sender, shares);
    }

    function depositAll() public {
        uint256 balance = base.balanceOf(msg.sender); 
        deposit(balance); 
    }
    
    // No rebalance implementation for lower fees and faster swaps
    function withdraw(uint256 _shares) public nonReentrant
    {
        require(_shares > 0, "withdraw must be greater than 0");
        
        uint256 ibalance = balanceOf(msg.sender);
        require(_shares <= ibalance, "insufficient balance");
        uint256 pool = calcPoolValueInToken();
        // Calc to redeem before updating balances
        uint256 r = (pool.mul(_shares)).div(totalSupply());
        uint256 fee = _calcWithdrawalFee(r);
        r = r.sub(fee);
        _burn(msg.sender, _shares);
        
        // Check balance
        uint256 b = IERC20(base).balanceOf(address(this));
        if (b < r) {
            // take withdrawal fee for removing from strat 
            _withdrawSome(r);
        }
        
        IERC20(base).safeTransfer(msg.sender, r);
    }
    
    function withdrawAll() public {
        uint256 ibalance = balanceOf(msg.sender);
        withdraw(ibalance);
        
    }

    function _deleverage(uint256 _amount) internal {
        
        uint256 _enoughDeleveraged = 0; 

        uint256 _nLoops = 10; 

        for (uint256 i = 0; i < _nLoops; i++) {
            if (_enoughDeleveraged == 0){
                uint256 maxWithdraw = ((balanceLend().mul(collatLimit).div(decimalAdj)).mul(slippageAdj).div(decimalAdj)).sub(balanceDebt()); 
                if (maxWithdraw >= _amount){
                    _redeemBase(_amount);
                    _enoughDeleveraged = 1;
                }
                if (maxWithdraw <  _amount){
                    _redeemBase(maxWithdraw);
                    _swapBaseShort(maxWithdraw); 
                    _repayDebt();
                }
            }
        }
    } 

    function undeployFromStrat(uint256 _amount) external onlyAuthorized {
      _withdrawSome(_amount);
    }

    /// function to remove funds from strategy when users withdraws funds in excess of reserves 
    function _withdrawSome(uint256 _amount) internal {
        _deleverage(_amount);

    }

    /// rebalances RoboVault strat position to within target collateral range 
    function rebalanceCollateral() external onlyKeepers {
        uint256 shortPos = balanceDebt();
        uint256 lendPos = balanceLend();
        _operationalFeeHarvest();
        // ratio of amount borrowed to collateral 
        uint256 collatRat = calcCollateral(); 
        
        if (collatRat > collatUpper) {
            uint256 maxWithdraw = ((balanceLend().mul(collatLimit).div(decimalAdj)).mul(slippageAdj).div(decimalAdj)).sub(balanceDebt()); 
            _redeemBase(maxWithdraw);
            _swapBaseShort(maxWithdraw); 
            _repayDebt();

            
        }
        
        if (collatRat < collatLower) {
            uint256 adjAmount = (collatLimit.sub(calcCollateral())).mul(balanceLend()).div(decimalAdj);
            uint256 borrowAmt = _borrowBaseEq(adjAmount);
            _swapShortBase(shortToken.balanceOf(address(this)));
            if (adjAmount < base.balanceOf(address(this))){
                _lendBase(adjAmount);
            } else {
                _lendBase(base.balanceOf(address(this)));
            }

            
        }

    }
    

    
    function getPricePerFullShare() public view returns(uint256) {
        uint256 bal = calcPoolValueInToken();
        uint256 supply = totalSupply();
        return bal.mul(decimalAdj).div(supply);
    }
    

}