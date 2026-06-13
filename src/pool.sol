// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions
// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LPToken} from "./LPToken.sol";
//import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract pool {
    /* State Variables */
    address public immutable token0;
    address public immutable token1;
    /* Veriables */
    uint256 public totalLpToken = 0;
    uint256 public qtyToken0; //X
    uint256 public qtyToken1; //Y
    uint256 public product; //K
    // address public immutable i_poolTokenAddress;
    LPToken public lpToken;

    /*constructor */
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
        //AVOID dynamic name and symbol generation to SAVE GAS
        /*
        string memory symbol0 = IERC20Metadata(_token0).symbol();
        string memory symbol1 = IERC20Metadata(_token1).symbol();
        string memory lpName = string.concat(
            "Liquidity Pool ",
            symbol0,
            "-",
            symbol1
        );
        string memory lpSymbol = string.concat("LP-", symbol0, "-", symbol1);

        lpToken = new LPToken(lpName, lpSymbol);
        */
        lpToken = new LPToken("LP_Token", "LPTKN");
    }

    /* Functions*/

    function addLiquidity(uint256 _qtyToken0, uint256 _qtyToken1) public {
        bool success1 = IERC20(token0).transferFrom(
            msg.sender,
            address(this),
            _qtyToken0
        );
        bool success2 = IERC20(token1).transferFrom(
            msg.sender,
            address(this),
            _qtyToken1
        );
        require(success1 && success2, "Transfered failed");
        //get the number of LP token to be minted
        uint256 _LpTokenToMint = mintLpToken(_qtyToken0, _qtyToken1);
        //create the liquidity pool
        qtyToken0 += _qtyToken0;
        qtyToken1 += _qtyToken1;

        totalLpToken += _LpTokenToMint;
        product = qtyToken0 * qtyToken1;
    }

    /* To give the number of LP token to be printed */
    function mintLpToken(
        uint256 _qtyToken0,
        uint256 _qtyToken1
    ) private returns (uint256) {
        if (totalLpToken == 0) {
            uint256 mintLpQty = Math.sqrt(_qtyToken0 * _qtyToken1);

            lpToken.mint(msg.sender, mintLpQty);
            return mintLpQty;
        } else {
            uint256 x = (_qtyToken0 * totalLpToken) / qtyToken0;
            uint256 y = (_qtyToken1 * totalLpToken) / qtyToken1;
            uint256 mintLpQty = x > y ? y : x;
            lpToken.mint(msg.sender, mintLpQty);
            return mintLpQty;
        }
    }
}
