// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {factory} from "../src/factory.sol";
import {Router} from "../src/Router.sol";

contract deployV2 is Script {
    factory public Factory;
    Router public router;

    function run() public {
        vm.startBroadcast();
        Factory = new factory();
        router = new Router(address(Factory));
        vm.stopBroadcast();
        console2.log("=== Sepolia Deployment Successful ===");
        console2.log("Factory Address:", address(Factory));
        console2.log("Router Address: ", address(router));
        console2.log("=====================================");
    }
}
