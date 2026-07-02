//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {Test} from "forge-std/Test.sol";
import {Router} from "../src/Router.sol";
import {factory} from "../src/factory.sol";
import {mockToken0} from "./mockToken0.sol";
import {mockToken1} from "./mockToken1.sol";
import {pool} from "../src/pool.sol";

contract routerAddLiquidity is Test {
    Router public router;
    pool public Pool;
    factory public Factory;
    mockToken0 public MockToken0;
    mockToken1 public MockToken1;
    address public poolAddr;

    address public USER = address(0x123);
    event LiquidityAdded(
        address indexed poolAddress,
        address indexed user,
        uint256 amountA,
        uint256 amountB
    );

    function setUp() public {
        Factory = new factory();
        router = new Router(address(Factory));
        MockToken0 = new mockToken0("MockTKN1", "MTKN_1", 1000000);
        MockToken1 = new mockToken1("MockTKN2", "MTKN_2", 500000);
        // MockToken0.approve(USER, 10000);
        // MockToken1.approve(USER, 10000);
        MockToken0.transfer(USER, 10000);
        MockToken1.transfer(USER, 10000);
        vm.startPrank(USER);
        MockToken0.approve(address(router), 10000);
        MockToken1.approve(address(router), 10000);
        router.addLiquidity(
            address(MockToken0),
            address(MockToken1),
            8000,
            8000,
            USER
        );
        vm.stopPrank();
        poolAddr = router.getExpectedAddr(
            address(MockToken0),
            address(MockToken1)
        );
    }

    function testBurnLpToken() public {
        Pool = pool(poolAddr);
        uint256 lpBal = Pool.balanceOf(USER);

        vm.startPrank(USER);
        Pool.approve(address(router), 10000);
        router.removeLiquidity(10, poolAddr, USER, 0, 0);
        vm.stopPrank();
        uint256 finalLpBal = Pool.balanceOf(USER);
        assertGt(lpBal, finalLpBal);
    }

    function testMinAcceptedToken0() public {
        Pool = pool(poolAddr);
        vm.startPrank(USER);

        Pool.approve(address(router), 10000);
        vm.expectRevert("Router: Insufficient Token0 output");
        router.removeLiquidity(10, poolAddr, USER, 11, 0);
        vm.stopPrank();
    }

    function testMinAcceptedToken1() public {
        Pool = pool(poolAddr);
        vm.startPrank(USER);

        Pool.approve(address(router), 10000);
        vm.expectRevert("Router: Insufficient Token1 output");
        router.removeLiquidity(10, poolAddr, USER, 0, 11);
        vm.stopPrank();
    }

    function testWithoutApproval() public {
        Pool = pool(poolAddr);
        vm.startPrank(USER);
        vm.expectRevert();
        router.removeLiquidity(10, poolAddr, USER, 0, 0);
        vm.stopPrank();
    }

    function testRouterConstructorRevertsOnZeroAddress() public {
        vm.expectRevert("Router: Zero address");
        new Router(address(0));
    }
}
