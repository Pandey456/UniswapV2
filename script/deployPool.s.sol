// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {pool} from "../src/pool.sol";

contract deployPool is Script {
    pool public Pool;

    function run(address _token0, address _token1) public {
        vm.startBroadcast();
        Pool = new pool(_token0, _token1);
        vm.stopBroadcast();
    }
}
