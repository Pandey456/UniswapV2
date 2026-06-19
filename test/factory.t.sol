// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {deployFactory} from "../script/deployFactory.s.sol";
import {factory} from "../src/factory.sol";
import {mockToken0} from "./mockToken0.sol";
import {mockToken1} from "./mockToken1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract factoryTest is Test {
    factory public Factory;

    deployFactory public DeployFactory;
    mockToken0 public MockToken0;
    mockToken1 public MockToken1;
    address public USER;

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

    function testIfPoolDeployedNonROuter() public {
        vm.prank(USER);
        vm.expectRevert("only Router can perform");
        address newPool = Factory.createPool(
            address(MockToken0),
            address(MockToken1)
        );
    }

    function testIfPoolDeployed() public {
        vm.prank(Factory.i_ROUTER());
        address newPool = Factory.createPool(
            address(MockToken0),
            address(MockToken1)
        );
        assertNotEq(newPool, address(0));
    }

    function testSameToken() public {
        vm.prank(Factory.i_ROUTER());
        vm.expectRevert("Same Token");
        address newPool = Factory.createPool(
            address(MockToken0),
            address(MockToken0)
        );
    }

    function testSortingAndZeroAddr() public {
        vm.prank(Factory.i_ROUTER());
        vm.expectRevert("Zero Address");
        address newPool = Factory.createPool(address(1), address(0));
    }

    function testPoolExist() public {
        vm.prank(Factory.i_ROUTER());
        Factory.createPool(address(MockToken1), address(MockToken0));
        vm.prank(Factory.i_ROUTER());
        vm.expectRevert("Pool Already Exists");
        Factory.createPool(address(MockToken1), address(MockToken0));
    }

    function testPoolExistReverse() public {
        vm.prank(Factory.i_ROUTER());
        Factory.createPool(address(MockToken0), address(MockToken1));
        vm.prank(Factory.i_ROUTER());
        vm.expectRevert("Pool Already Exists");
        Factory.createPool(address(MockToken1), address(MockToken0));
    }

    function testGetAllPoolReturnsEmptyArrayInitially() public {
        address[] memory pools = Factory.getAllPool();
        assertEq(pools.length, 0);
    }

    function testForMapping() public {
        vm.prank(Factory.i_ROUTER());
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
        vm.prank(Factory.i_ROUTER());
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
        vm.prank(Factory.i_ROUTER());
        address poolAddress = Factory.createPool(
            address(MockToken0),
            address(MockToken1)
        );
        address[] memory pools = Factory.getAllPool();
        address expectedPool = pools[0];
        assertEq(poolAddress, expectedPool);
    }
}
