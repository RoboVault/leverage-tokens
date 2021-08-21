// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../vaultHelpers.sol";
import "../farms/spirit.sol";
import "../lenders/cream.sol";
import "../token.sol";

contract CreamETHFTM is Cream {
    function lendPlatform() public view override returns (address) {
        return 0xcc3E89fBc10e155F1164f8c9Cf0703aCDe53f6Fd;
    }
}

contract SpiritETHFTM is Spirit {
    function farmLP() public view override returns (address) {
        return 0x613BF4E46b4817015c01c6Bb31C7ae9edAadc26e;
    }
    function farmPid() public view override returns (uint256) {
        return 3;
    }
}
    
contract rvETHSpirit is ERC20, ERC20Detailed, CreamETHFTM, SpiritETHFTM, RoboController {
    using SafeMath for uint256;
    address constant ETH = 0x74b23882a30290451A17c44f4F05243b6b58C76d;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    constructor() public 
        ERC20Detailed("Robo Vault ETH Spirit", "rvETHb", 18)
        RoboController(ETH, WFTM)
    {}
}