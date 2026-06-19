//SDPX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {pool} from "./pool.sol";

contract factory {
    mapping(address => mapping(address => address)) public poolRegistry;

    address[] public allPool;
    address public immutable i_ROUTER;

    constructor() {
        i_ROUTER = msg.sender;
    }

    modifier onlyRouter() {
        _onlyRouter();
        _;
    }

    function _onlyRouter() internal view {
        require(msg.sender == i_ROUTER, "only Router can perform");
    }

    function createPool(
        address _tokenA,
        address _tokenB
    ) external onlyRouter returns (address) {
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
        pool Pool = new pool{salt: salt}(token0, token1);
        address newPool = address(Pool);
        poolRegistry[token0][token1] = newPool;
        poolRegistry[token1][token0] = newPool;
        allPool.push(newPool);
        return newPool;
    }

    function getAllPool() external view returns (address[] memory) {
        return allPool;
    }
}
