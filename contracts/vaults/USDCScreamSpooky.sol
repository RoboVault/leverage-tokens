// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../farms/spooky.sol";
import "../lenders/scream.sol";
import "../token.sol";
import "../vaultHelpers.sol";

contract ScreamUSDC is Scream {
    function lendPlatform() public view override returns (address) {
        return 0xE45Ac34E528907d0A0239ab5Db507688070B20bf;
    }
}

contract SpookyUSDC is Spooky {
    function farmLP() public view override returns (address) {
        return 0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c;
    }
    function farmPid() public view override returns (uint256) {
        return 2;
    }
}
    
contract leverageTest is ERC20, ERC20Detailed, ScreamUSDC, SpookyUSDC, RoboController {
    using SafeMath for uint256;
    address constant USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    string constant baseSymbol = "USDC";
    string constant shortSymbol = "FTM";

    constructor() public 
        ERC20Detailed("LEVERAGETEST", "test", 8)
        RoboController(USDC, WFTM)
    {}
}