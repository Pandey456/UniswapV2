// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {factory} from "../src/factory.sol";

contract deployFactory is Script {
    factory public Factory;

    function run() public {
        vm.startBroadcast();
        Factory = new factory();
        vm.stopBroadcast();
    }
}
