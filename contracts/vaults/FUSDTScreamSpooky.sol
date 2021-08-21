// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../farms/spooky.sol";
import "../lenders/scream.sol";
import "../token.sol";
import "../vaultHelpers.sol";

contract ScreamFUSDT is Scream {
    function lendPlatform() public view override returns (address) {
        return 0x02224765BC8D54C21BB51b0951c80315E1c263F9;
    }
}

contract SpookyFUSDT is Spooky {
    function farmLP() public view override returns (address) {
        return 0x5965E53aa80a0bcF1CD6dbDd72e6A9b2AA047410;
    }
    function farmPid() public view override returns (uint256) {
        return 1;
    }
}
    
contract rvFUSDTScreamSpooky is ERC20, ERC20Detailed, ScreamFUSDT, SpookyFUSDT, RoboController {
    using SafeMath for uint256;
    address constant FUSDT = 0x049d68029688eAbF473097a2fC38ef61633A3C7A;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    constructor() public 
        ERC20Detailed("Robo Vault FUSDT Scream Spooky", "rvFUSDTa", 6)
        RoboController(FUSDT, WFTM)
    {}
}