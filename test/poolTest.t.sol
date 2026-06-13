// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {deployPool} from "../script/deployPool.s.sol";
import {pool} from "../src/pool.sol";
import {mockToken0} from "./mockToken0.sol";
import {mockToken1} from "./mockToken1.sol";
import {LPToken} from "../src/LPToken.sol";

contract poolTest is Test {
    pool public Pool;
    LPToken public lpToken;
    deployPool public DeployPool;
    mockToken0 public MockToken0;
    mockToken1 public MockToken1;
    address public USER;

    function setUp() public {
        //Pool = new pool();
        MockToken0 = new mockToken0("MockTKN1", "MTKN_1", 100);
        MockToken1 = new mockToken1("MockTKN2", "MTKN_2", 50);
        DeployPool = new deployPool();
        DeployPool.run(address(MockToken0), address(MockToken1));
        USER = makeAddr("USER");

        //the the hidden getter function for ' pool public Pool;'
        Pool = DeployPool.Pool();
    }

    function testCretePool() public {
        address poolCreated = address(Pool);
        assertNotEq(poolCreated, address(0));
    }

    function testLpTokenCreated() public {
        address lpTokenAddress = address(Pool.lpToken());
        assertNotEq(lpTokenAddress, address(0));
    }

    function testLPTokenMint() public {
        lpToken = new LPToken("LPTOken", "LPT");
        lpToken.mint(USER, 100);
        assertEq(lpToken.balanceOf(USER), 100);
    }

    function testLPTokenBurn() public {
        lpToken = new LPToken("LPTOken", "LPT");
        lpToken.mint(USER, 100);
        lpToken.burn(USER, 50);
        assertEq(lpToken.balanceOf(USER), 50);
    }

    function testLpOnlyTokenMintRevert() public {
        lpToken = new LPToken("LPTOken", "LPT");
        vm.prank(USER);
        vm.expectRevert("Only Pool Can Perform this action");
        lpToken.mint(USER, 100);
    }

    function testLPTokenBurnRevert() public {
        lpToken = new LPToken("LPTOken", "LPT");
        lpToken.mint(USER, 100);
        vm.expectRevert("Only Pool Can Perform this action");
        vm.prank(USER);
        lpToken.burn(USER, 50);
    }
}
