// SPDX-License-Identifier: MIT
pragma solidity =0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20d6.sol";

contract FaucetERC20d6 is ERC20d6, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 value
    ) ERC20d6(name, symbol) {
        if( value > 0 ){
            _mint(msg.sender, value);
        }
    }
    function mint(uint256 value) public onlyOwner {
        _mint(msg.sender, value);
    }
    function mint(address to, uint256 value) public onlyOwner {
        _mint(to, value);
    }
}
