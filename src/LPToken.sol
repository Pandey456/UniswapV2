//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20 {
    address public pool;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        pool = msg.sender;
    }

    modifier onlyPool() {
        require(msg.sender == pool, "Only Pool Can Perform this action");
        _;
    }

    function mint(address _to, uint256 _amount) external onlyPool {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyPool {
        _burn(_from, _amount);
    }
}
