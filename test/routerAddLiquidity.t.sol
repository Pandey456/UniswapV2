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
        vm.stopPrank();
    }

    function testVariableAssigned() public view {
        assertEq(router.factoryAddress(), address(Factory));
        assertEq(router.poolHash(), keccak256(type(pool).creationCode));
    }

    function testRequiredDifferentTOken() public {
        vm.expectRevert("Identical addresses");
        router.addLiquidity(
            address(MockToken1),
            address(MockToken1),
            21,
            22,
            msg.sender
        );
    }

    function testRequiredMoreLiquidity() public {
        vm.expectRevert("Insufficient amounts");
        router.addLiquidity(
            address(MockToken1),
            address(MockToken0),
            0,
            22,
            msg.sender
        );
    }

    function testemitEvent() public {
        address expectAddrs = router.getExpectedAddr(
            address(MockToken0),
            address(MockToken1)
        );
        vm.expectEmit(true, true, false, true, address(router));
        emit LiquidityAdded(expectAddrs, USER, 1500, 1500);
        vm.startPrank(USER);
        router.addLiquidity(
            address(MockToken1),
            address(MockToken0),
            1500,
            1500,
            USER
        );
        vm.stopPrank();
    }

    function testSorting() public {
        (address smaller, ) = router.sortToken(address(1), address(0));
        assertEq(smaller, address(0));
    }

    function testPoolExistWithoutLiquidity() public {
        address Pool2 = Factory.createPool(
            address(MockToken1),
            address(MockToken0)
        );
        pool Pool1 = pool(Pool2);
        uint256 initial = Pool1.qtyToken0();
        vm.prank(USER);
        router.addLiquidity(
            address(MockToken1),
            address(MockToken0),
            1500,
            1500,
            USER
        );
        uint256 finalVal = Pool1.qtyToken0();
        assertGt(finalVal, initial);
    }

    function testPoolSecondTimeLiquidity() public {
        address Pool2 = Factory.createPool(
            address(MockToken1),
            address(MockToken0)
        );
        pool Pool1 = pool(Pool2);
        MockToken0.approve(address(this), 10000);
        MockToken1.approve(address(this), 10000);
        Pool1.addLiquidity(1500, 1500, address(2));
        uint256 initial = Pool1.qtyToken0();
        vm.prank(USER);
        router.addLiquidity(
            address(MockToken1),
            address(MockToken0),
            1500,
            1500,
            USER
        );
        uint256 finalVal = Pool1.qtyToken0();
        assertGt(finalVal, initial);
        assertEq(initial, 1500);
        assertEq(finalVal, 3000);
    }
}
