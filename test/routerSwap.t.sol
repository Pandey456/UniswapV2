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
    mockToken0 public MockToken3;
    mockToken1 public MockToken4;

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
            msg.sender
        );
        vm.stopPrank();
    }

    function testDeadline() public {
        address[] memory path = new address[](2);
        path[0] = address(MockToken0);
        path[1] = address(MockToken1);
        vm.expectRevert("Router: EXPIRED");
        router.swap(100, 90, path, USER, block.timestamp - 1);
    }

    function testSimpleSwap() public {
        address[] memory path = new address[](2);
        path[0] = address(MockToken0);
        path[1] = address(MockToken1);
        MockToken0.approve(address(router), 10000);
        address poolAddr = router.getExpectedAddr(
            address(MockToken0),
            address(MockToken1)
        );
        uint256 token0Exist = pool(poolAddr).qtyToken0();
        router.swap(100, 90, path, USER, block.timestamp + 20);
        uint256 token0Left = pool(poolAddr).qtyToken0();
        // $$\Delta y = \frac{8000 \cdot 100 \cdot 997}{8000 \cdot 1000 + 100 \cdot 997}$$
        assertEq(token0Exist, 8000);
        assertEq(token0Left, 7902);
    }

    function testMultiHop() public {
        MockToken3 = new mockToken0("MockTKN1", "MTKN_1", 1000000);
        MockToken4 = new mockToken1("MockTKN2", "MTKN_2", 500000);
        MockToken1.transfer(USER, 10000);
        MockToken3.transfer(USER, 20000);
        MockToken4.transfer(USER, 10000);
        vm.startPrank(USER);
        MockToken3.approve(address(router), 10000);
        MockToken1.approve(address(router), 10000);
        router.addLiquidity(
            address(MockToken1),
            address(MockToken3),
            8000,
            8000,
            msg.sender
        );
        MockToken3.approve(address(router), 10000);
        MockToken4.approve(address(router), 10000);
        router.addLiquidity(
            address(MockToken3),
            address(MockToken4),
            8000,
            8000,
            msg.sender
        );
        vm.stopPrank();
        address[] memory path = new address[](4);
        path[0] = address(MockToken0);
        path[1] = address(MockToken1);
        path[2] = address(MockToken3);
        path[3] = address(MockToken4);
        address poolAddr = router.getExpectedAddr(
            address(MockToken3),
            address(MockToken4)
        );
        MockToken0.approve(address(router), 10000);
        router.swap(100, 90, path, USER, block.timestamp + 20);
        uint256 token0Left = pool(poolAddr).qtyToken0();
        assertLt(token0Left, 8000);
    }

    function testMinAmount() public {
        address[] memory path = new address[](2);
        path[0] = address(MockToken0);
        path[1] = address(MockToken1);
        MockToken0.approve(address(router), 10000);
        vm.expectRevert("Router: INSUFFICIENT_OUTPUT_AMOUNT");
        router.swap(100, 99, path, USER, block.timestamp + 20);

        // $$\Delta y = \frac{8000 \cdot 100 \cdot 997}{8000 \cdot 1000 + 100 \cdot 997}$$
    }
}
