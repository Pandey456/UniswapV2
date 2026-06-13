// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {pool} from "../src/pool.sol";

contract deployPool is Script {
    pool public Pool;

    function run() public {
        vm.startBroadcast();
        Pool = new pool(address(0), address(0));
        vm.stopBroadcast();
    }
}
