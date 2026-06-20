//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {pool} from "./pool.sol";

contract factory {
    mapping(address => mapping(address => address)) public poolRegistry;

    address[] public allPool;
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        address poolAddress,
        uint256 poolCount
    );

    function createPool(
        address _tokenA,
        address _tokenB
    ) external returns (address) {
        //checks
        require(_tokenA != _tokenB, "Same Token");
        (address token0, address token1) = _tokenA < _tokenB
            ? (_tokenA, _tokenB)
            : (_tokenB, _tokenA);
        require(token0 != address(0), "Zero Address");
        require(
            poolRegistry[token0][token1] == address(0),
            "Pool Already Exists"
        );

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pool Pool = new pool{salt: salt}();

        address newPool = address(Pool);

        poolRegistry[token0][token1] = newPool;
        poolRegistry[token1][token0] = newPool;
        allPool.push(newPool);
        Pool.initizalized(token0, token1); // moved it down to satisfy check - effects - interactions
        emit PoolCreated(token0, token1, newPool, allPool.length);
        return newPool;
    }

    function getPoolLength() external view returns (uint256) {
        return allPool.length;
    }
}
