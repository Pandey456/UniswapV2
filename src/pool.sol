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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract pool is ERC20, ReentrancyGuard {
    /* State Variables */
    address public token0;
    address public token1;
    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    /* Variables */
    address constant DEAD_ADDRESS = address(1);
    uint256 public qtyToken0; //X
    uint256 public qtyToken1; //Y
    bool internal isInitialized;
    address public immutable i_FactoryAdddress;

    /* Events */
    event Mint(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        uint256 lpshares
    );
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut
    );
    event RemovedLiquidity(
        address indexed sender,
        uint256 lpTokenIn,
        uint256 tokenOut0,
        uint256 tokenOut1
    );

    /*constructor */
    constructor() ERC20("LP_Token", "LPTKN") {
        i_FactoryAdddress = msg.sender;
    }

    /* Functions*/
    function initizalized(address _token0, address _token1) external {
        require(msg.sender == i_FactoryAdddress, "Not a Owner");
        require(!isInitialized, "Already initizalized");
        require(_token0 != address(0) && _token1 != address(0), "Zero Address");
        require(_token0 != _token1, "Same Token");
        isInitialized = true;
        token0 = _token0;
        token1 = _token1;
    }

    function addLiquidity(
        uint256 _qtyToken0,
        uint256 _qtyToken1,
        address _user
    ) public nonReentrant {
        //Check
        require(_qtyToken0 > 0 && _qtyToken1 > 0, "Zero Amounts");
        //get the number of LP token to be minted
        bool firstLp = (totalSupply() == 0);
        uint256 _LpTokenToMint = mintLpToken(_qtyToken0, _qtyToken1, firstLp);
        require(_LpTokenToMint > 0, "Insufficient Liquidity Minted");

        //Effect

        qtyToken0 += _qtyToken0;
        qtyToken1 += _qtyToken1;

        if (firstLp) {
            _mint(DEAD_ADDRESS, MINIMUM_LIQUIDITY); //burn but tokens are still counted for supply
        }

        _mint(_user, _LpTokenToMint);
        //Interactions
        // bool success1 = IERC20(token0).transferFrom(
        //     msg.sender,
        //     address(this),
        //     _qtyToken0
        // );
        // bool success2 = IERC20(token1).transferFrom(
        //     msg.sender,
        //     address(this),
        //     _qtyToken1
        // );
        // require(success1 && success2, "Transfer failed");

        emit Mint(_user, _qtyToken0, _qtyToken1, _LpTokenToMint);
    }

    /* To give the number of LP token to be minted */
    function mintLpToken(
        uint256 _qtyToken0,
        uint256 _qtyToken1,
        bool firstLp
    ) private view returns (uint256) {
        if (firstLp) {
            uint256 sqrtValue = Math.sqrt(_qtyToken0 * _qtyToken1);
            if (sqrtValue <= MINIMUM_LIQUIDITY) {
                return 0;
            }
            uint256 mintLpQty = sqrtValue - MINIMUM_LIQUIDITY;
            return mintLpQty;
        } else {
            uint256 total_Supply = totalSupply();
            uint256 share0 = (_qtyToken0 * total_Supply) / qtyToken0;
            uint256 share1 = (_qtyToken1 * total_Supply) / qtyToken1;
            uint256 mintLpQty = share0 > share1 ? share1 : share0;
            return mintLpQty;
        }
    }

    /* Swap Function */
    function swap(
        uint256 _tokenAmtIn,
        address _tokenIn,
        uint256 _minAmtOut,
        address _user
    ) public nonReentrant {
        //Checks
        require(qtyToken0 > 0 && qtyToken1 > 0, "Insufficient Liquidity");
        require(_tokenAmtIn > 0, "Can not be null");
        require(_tokenIn == token0 || _tokenIn == token1, "Invalid Token");

        // Effect
        bool isToken0 = (_tokenIn == token0);
        address _tokenOut = isToken0 ? token1 : token0;
        uint256 outTokenAmt = isToken0 ? qtyToken1 : qtyToken0; //Y
        uint256 inTokenAmt = isToken0 ? qtyToken0 : qtyToken1; //X
        // Δy = _tokenAmtOut
        // Δx = _tokenAmtIn

        /* fee = 0.3% --> Δy = (y · Δx · 997) / (x · 1000 + Δx · 997)*/
        //qtyToken0=x
        uint256 _tokenAmtOut = (outTokenAmt * _tokenAmtIn * 997) /
            (inTokenAmt * 1000 + _tokenAmtIn * 997);
        require(_tokenAmtOut > 0, "Insufficient output");

        require(_tokenAmtOut >= _minAmtOut, "Slippage wiped");
        if (isToken0) {
            qtyToken0 += _tokenAmtIn;
            qtyToken1 -= _tokenAmtOut;
        } else {
            qtyToken1 += _tokenAmtIn;
            qtyToken0 -= _tokenAmtOut;
        }

        // Interactions

        //transfer

        // require(
        //     IERC20(_tokenIn).transferFrom(
        //         msg.sender,
        //         address(this),
        //         _tokenAmtIn
        //     ),
        //     "In Transfer Failed"
        // );
        require(
            IERC20(_tokenOut).transfer(_user, _tokenAmtOut),
            "Out Transfer Failed"
        );
        emit Swap(_user, _tokenIn, _tokenAmtIn, _tokenAmtOut);
    }

    /* Remove Liquidity */
    function removeLiquidity(
        uint256 _lpTokenQty,
        address _user
    ) public nonReentrant returns (uint256 amount0, uint256 amount1) {
        //Checks
        require(_lpTokenQty > 0, "Zero LP Token");
        require(qtyToken0 > 0 && qtyToken1 > 0, "Insufficient Liquidity");
        //Effects
        //amount0 = (shares · reserve0) / totalSupply
        uint256 totalLpSupply = totalSupply();
        amount0 = (_lpTokenQty * qtyToken0) / totalLpSupply;
        amount1 = (_lpTokenQty * qtyToken1) / totalLpSupply;
        require(amount0 > 0 && amount1 > 0, "Insufficient Amounts");

        qtyToken0 = qtyToken0 - amount0;
        qtyToken1 = qtyToken1 - amount1;
        //Interaction

        _burn(msg.sender, _lpTokenQty);

        // require(
        //     IERC20(token0).transfer(_user, amount0),
        //     "Token_0 Transfer Failed"
        // );
        // require(
        //     IERC20(token1).transfer(_user, amount1),
        //     "Token_1 Transfer Failed"
        // );
        emit RemovedLiquidity(_user, _lpTokenQty, amount0, amount1);
    }
}
