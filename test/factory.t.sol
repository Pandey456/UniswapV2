// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {deployFactory} from "../script/deployFactory.s.sol";
import {factory} from "../src/factory.sol";
import {mockToken0} from "./mockToken0.sol";
import {mockToken1} from "./mockToken1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {pool} from "../src/pool.sol";

contract factoryTest is Test {
    factory public Factory;

    deployFactory public DeployFactory;
    mockToken0 public MockToken0;
    mockToken1 public MockToken1;
    address public USER;
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        address poolAddress,
        uint256 poolCount
    );

    function setUp() public {
        //Factory = new factory();
        MockToken0 = new mockToken0("MockTKN1", "MTKN_1", 1000000);
        MockToken1 = new mockToken1("MockTKN2", "MTKN_2", 500000);
        DeployFactory = new deployFactory();
        DeployFactory.run();
        USER = makeAddr("USER");

        //the the hidden getter function for ' factory public Factory;'
        Factory = DeployFactory.Factory();
    }

    function testIfPoolDeployed() public {
        address newPool = Factory.createPool(
            address(MockToken0),
            address(MockToken1)
        );
        assertNotEq(newPool, address(0));
    }

    function testSameToken() public {
        vm.expectRevert("Same Token");
        address newPool = Factory.createPool(
            address(MockToken0),
            address(MockToken0)
        );
    }

    function testSortingAndZeroAddr() public {
        vm.expectRevert("Zero Address");
        address newPool = Factory.createPool(address(1), address(0));
    }

    function testPoolExist() public {
        Factory.createPool(address(MockToken1), address(MockToken0));
        vm.expectRevert("Pool Already Exists");
        Factory.createPool(address(MockToken1), address(MockToken0));
    }

    function testPoolExistReverse() public {
        Factory.createPool(address(MockToken0), address(MockToken1));
        vm.expectRevert("Pool Already Exists");
        Factory.createPool(address(MockToken1), address(MockToken0));
    }

    function testGetAllPoollengthZero() public {
        uint256 length = Factory.getPoolLength();
        assertEq(length, 0);
    }

    function testForMapping() public {
        address actualPool = Factory.createPool(
            address(MockToken0),
            address(MockToken1)
        );
        address expectedPool = Factory.poolRegistry(
            address(MockToken0),
            address(MockToken1)
        );
        assertEq(actualPool, expectedPool);
    }

    function testForMappingReverse() public {
        address actualPool = Factory.createPool(
            address(MockToken0),
            address(MockToken1)
        );
        address expectedPool = Factory.poolRegistry(
            address(MockToken1),
            address(MockToken0)
        );
        assertEq(actualPool, expectedPool);
    }

    function testGetAllPoolReturns() public {
        address poolAddress = Factory.createPool(
            address(MockToken0),
            address(MockToken1)
        );
        uint256 length = Factory.getPoolLength();

        assertNotEq(length, 0);
    }

    function testEmitEvent() public {
        (address token0, address token1) = address(MockToken0) <
            address(MockToken1)
            ? (address(MockToken0), address(MockToken1))
            : (address(MockToken1), address(MockToken0));
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(type(pool).creationCode)
        );

        address expectedPoolAddress = vm.computeCreate2Address(
            salt,
            bytecodeHash,
            address(Factory)
        );

        vm.expectEmit(true, true, false, true);

        emit PoolCreated(token0, token1, expectedPoolAddress, 1);

        Factory.createPool(address(MockToken0), address(MockToken1));
    }
}
