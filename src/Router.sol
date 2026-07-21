// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {factory} from "../src/factory.sol";
import {pool} from "../src/pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Router is ReentrancyGuard {
    address public immutable factoryAddress;
    bytes32 public immutable poolHash;
    using SafeERC20 for IERC20;

    event LiquidityAdded(
        address indexed poolAddress,
        address indexed user,
        uint256 amountA,
        uint256 amountB
    );

    constructor(address _factory) {
        require(_factory != address(0), "Router: Zero address");
        factoryAddress = _factory;
        poolHash = keccak256(type(pool).creationCode);
    }

    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountA,
        uint256 _amountB,
        address _to
    ) public nonReentrant {
        require(_tokenA != _tokenB, "Identical addresses");
        require(_amountA > 0 && _amountB > 0, "Insufficient amounts");

        address poolAddress = factory(factoryAddress).poolRegistry(
            _tokenA,
            _tokenB
        );

        if (poolAddress == address(0)) {
            poolAddress = factory(factoryAddress).createPool(_tokenA, _tokenB);
        }

        uint256 reserve0 = pool(poolAddress).qtyToken0();
        uint256 reserve1 = pool(poolAddress).qtyToken1();

        uint256 amountAUsed;
        uint256 amountBUsed;

        if (reserve0 == 0 && reserve1 == 0) {
            // Initial liquidity
            amountAUsed = _amountA;
            amountBUsed = _amountB;
        } else {
            (address token0, ) = sortToken(_tokenA, _tokenB);
            (uint256 reserveA, uint256 reserveB) = _tokenA == token0
                ? (reserve0, reserve1)
                : (reserve1, reserve0);

            // Calculate optimal amountB for given amountA (based on current ratio)
            uint256 optimalB = (_amountA * reserveB) / reserveA;

            if (optimalB <= _amountB) {
                amountAUsed = _amountA;
                amountBUsed = optimalB;
            } else {
                // Use all of tokenB, calculate required tokenA
                uint256 optimalA = (_amountB * reserveA) / reserveB;
                amountAUsed = optimalA;
                amountBUsed = _amountB;
            }

            assert(amountAUsed <= _amountA && amountBUsed <= _amountB);
        }
        //interactions
        IERC20(_tokenA).safeTransferFrom(msg.sender, poolAddress, amountAUsed);
        IERC20(_tokenB).safeTransferFrom(msg.sender, poolAddress, amountBUsed);

        (address token0, ) = sortToken(_tokenA, _tokenB);
        (uint256 amount0, uint256 amount1) = _tokenA == token0
            ? (amountAUsed, amountBUsed)
            : (amountBUsed, amountAUsed);

        pool(poolAddress).addLiquidity(amount0, amount1, _to);

        emit LiquidityAdded(poolAddress, _to, amountAUsed, amountBUsed);
    }

    function getExpectedAddr(
        address _tokenA,
        address _tokenB
    ) public view returns (address) {
        (address token0, address token1) = sortToken(_tokenA, _tokenB);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), factoryAddress, salt, poolHash)
        );
        return address(uint160(uint256(hash)));
    }

    function sortToken(
        address _tokenA,
        address _tokenB
    ) public pure returns (address token0, address token1) {
        (token0, token1) = _tokenA < _tokenB
            ? (_tokenA, _tokenB)
            : (_tokenB, _tokenA);
    }

    function swap(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata hopPath,
        address to,
        uint256 deadline
    ) external nonReentrant {
        require(block.timestamp <= deadline, "Router: EXPIRED");
        uint256[] memory amount = new uint256[](hopPath.length);
        amount[0] = amountIn;
        for (uint256 i = 0; i < hopPath.length - 1; i++) {
            address tokenIn = hopPath[i];
            address tokenOut = hopPath[i + 1];
            address poolAddressExpected = getExpectedAddr(tokenIn, tokenOut);
            uint256 reserv0 = pool(poolAddressExpected).qtyToken0();
            uint256 reserv1 = pool(poolAddressExpected).qtyToken1();
            address poolToken0 = pool(poolAddressExpected).token0();
            (
                uint256 reserveOfTokenIn,
                uint256 reserveOfTokenOut
            ) = poolToken0 == tokenIn ? (reserv0, reserv1) : (reserv1, reserv0);
            //Δy = (y · Δx · 997) / (x · 1000 + Δx · 997)
            // Δx --> amount[i]
            //Δy --> amount [i+1]
            //X --> reserveOfTokenIn
            //Y --> reserveOfTokenOut
            amount[i + 1] =
                (reserveOfTokenOut * amount[i] * 997) /
                (reserveOfTokenIn * 1000 + amount[i] * 997);
        }
        require(
            amount[hopPath.length - 1] >= amountOutMin,
            "Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        address firstPool = getExpectedAddr(hopPath[0], hopPath[1]);

        IERC20(hopPath[0]).safeTransferFrom(msg.sender, firstPool, amount[0]);
        for (uint256 i = 0; i < hopPath.length - 1; i++) {
            address tokenIn = hopPath[i];
            address tokenOut = hopPath[i + 1];
            address poolAddressExpected = getExpectedAddr(tokenIn, tokenOut);
            address addressto = i < hopPath.length - 2
                ? getExpectedAddr(tokenOut, hopPath[i + 2])
                : to;
            pool(poolAddressExpected).swap(
                amount[i],
                hopPath[i],
                amount[i + 1],
                addressto
            );
        }
    }

    function removeLiquidity(
        uint256 _lpTokenQty,
        address poolAddress,
        address _user,
        uint256 _qtyAmount0Min,
        uint256 _qtyAmount1Min
    ) external nonReentrant {
        IERC20(poolAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _lpTokenQty
        );
        (uint256 actualAmt0, uint256 actualAmt1) = pool(poolAddress)
            .removeLiquidity(_lpTokenQty, _user);
        require(
            actualAmt0 >= _qtyAmount0Min,
            "Router: Insufficient Token0 output"
        );
        require(
            actualAmt1 >= _qtyAmount1Min,
            "Router: Insufficient Token1 output"
        );
    }
}
