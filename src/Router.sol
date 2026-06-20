//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {factory} from "../src/factory.sol";
import {pool} from "../src/pool.sol";

contract Router is ReentrancyGuard {
    address public immutable factoryAddress;
    bytes32 public immutable poolHash;
    factory public Factory;

    constructor(address _Factory) {
        factoryAddress = _Factory;
        poolHash = keccak256(type(pool).creationCode);
        
    }

    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _qtyToken0,
        uint256 _qtyToken1,
        address _user
    ) public nonReentrant {
    
        address poolAddress = factoryAddress.poolRegistry(token0, token1);
        if (poolAddress == address(0)) {
            //deploy factory
            Factory = new factory();
            poolAddress = Factory.createPool(_tokenA,_tokenB );
        }
        poolAddress
    }

    function getExpectedAddr(
        address _tokenA,
        address _tokenB
    ) internal view returns (address) {
        (address tokenA, address tokenB) = _tokenA < _tokenB
            ? (_tokenA, _tokenB)
            : (_tokenB, _tokenA);
        bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB));
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), factoryAddress, salt, poolHash)
        );
        address expectedPoolAddress = address(uint160(uint256(hash)));
        return expectedPoolAddress;
    }

    function Swap() public nonReentrant {}

    function removeLiquidity() public nonReentrant {}
}
