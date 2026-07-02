// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {deployV2} from "../script/deployV2.s.sol";
import {factory} from "../src/factory.sol";
import {Router} from "../src/Router.sol";

contract DeployV2Test is Test {
    deployV2 public deployer;
    factory public Factory;
    Router public router;

    function setUp() public {
        deployer = new deployV2();

        vm.setEnv(
            "PRIVATE_KEY",
            "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
        );

        deployer.run();

        Factory = deployer.Factory();
        router = deployer.router();
    }

    function testDeployerSetsUpContracts() public view {
        assertTrue(address(Factory) != address(0));
        assertTrue(address(router) != address(0));
    }
}
