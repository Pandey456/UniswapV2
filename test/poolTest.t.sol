// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {deployPool} from "../script/deployPool.s.sol";
import {pool} from "../src/pool.sol";

contract poolTest is Test {
    pool public Pool;
    deployPool public DeployPool;

    function setUp() public {
        //Pool = new pool();
        DeployPool = new deployPool();
        DeployPool.run();
        //the the hidden getter function for ' pool public Pool;'
        Pool = DeployPool.Pool();
    }

    function testLiquidityTokenQuantity() public {}
}
