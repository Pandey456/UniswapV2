// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {factory} from "../src/factory.sol";
import {deployPool} from "../script/deployPool.s.sol";
import {pool} from "../src/pool.sol";
import {mockToken0} from "./mockToken0.sol";
import {mockToken1} from "./mockToken1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Router} from "../src/Router.sol";

contract swap is Test {
    pool public Pool;
    Router public router;
    factory public Factory;
    deployPool public DeployPool;
    mockToken0 public MockToken0;
    mockToken1 public MockToken1;
    address public USER;
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut
    );

    function setUp() public {
        //Pool = new pool();
        Factory = new factory();

        router = new Router(address(Factory));
        MockToken0 = new mockToken0("MockTKN1", "MTKN_1", 1000000);
        MockToken1 = new mockToken1("MockTKN2", "MTKN_2", 500000);
        DeployPool = new deployPool();
        DeployPool.run();
        USER = makeAddr("USER");

        //the the hidden getter function for ' pool public Pool;'
        Pool = DeployPool.Pool();
        address owner = Pool.i_FactoryAdddress();
        vm.prank(owner);
        Pool.initizalized(address(MockToken0), address(MockToken1));

        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000, address(this));
    }

    //Swap Function tests
    function testForNoLiquidity() public {
        pool Pool1 = new pool();
        address owner = Pool1.i_FactoryAdddress();
        vm.prank(owner);
        Pool1.initizalized(address(MockToken0), address(MockToken1));
        vm.expectRevert("Insufficient Liquidity");
        Pool1.swap(32, address(MockToken0), 2, address(this));
    }

    function testNullSwap() public {
        vm.expectRevert("Can not be null");
        Pool.swap(0, address(MockToken0), 2, address(this));
    }

    function testInvalidToken() public {
        vm.expectRevert("Invalid Token");
        Pool.swap(100, address(1), 2, address(this));
    }

    function testInsufficientOutput() public {
        vm.expectRevert("Insufficient output");
        Pool.swap(1, address(MockToken0), 0, address(this));
    }

    function testSlippageWiped() public {
        vm.expectRevert("Slippage wiped");
        Pool.swap(100, address(MockToken0), 100, address(this));
    }

    function testQuantityUpdateTkn0() public {
        //start
        address USER1 = address(0x123);
        MockToken0.transfer(USER1, 10000);
        MockToken1.transfer(USER1, 10000);
        vm.startPrank(USER1);
        MockToken0.approve(address(router), 12000);
        MockToken1.approve(address(router), 12000);
        router.addLiquidity(
            address(MockToken0),
            address(MockToken1),
            10000,
            10000,
            USER1
        );

        vm.stopPrank();
        address Pool1 = router.getExpectedAddr(
            address(MockToken0),
            address(MockToken1)
        );
        pool newPool = pool(Pool1);
        MockToken0.approve(address(newPool), 10000);
        MockToken0.transfer(address(newPool), 1000);

        //end

        newPool.swap(1000, address(MockToken0), 900, address(this));
        address poolToken0 = newPool.token0();
        if (poolToken0 == address(MockToken0)) {
            assertEq(newPool.qtyToken0(), 11000);
        } else {
            assertEq(newPool.qtyToken0(), 10000 - 906);
        }
    }

    // function testQuantityUpdateTkn1() public {
    //     MockToken1.approve(address(Pool), 10000);
    //     Pool.swap(1000, address(MockToken1), 900, address(this));
    //     assertEq(Pool.qtyToken1(), 11000);
    //     assertLt(Pool.qtyToken0(), 10000);
    // }

    // emit Swap(address(this), _tokenIn, _tokenAmtIn, _tokenAmtOut);
    function testEmitEvent() public {
        address USER1 = address(0x123);
        MockToken0.transfer(USER1, 10000);
        MockToken1.transfer(USER1, 10000);
        vm.startPrank(USER1);
        MockToken0.approve(address(router), 10000);
        MockToken1.approve(address(router), 10000);
        router.addLiquidity(
            address(MockToken0),
            address(MockToken1),
            2001,
            2002,
            USER1
        );

        vm.stopPrank();
        address Pool1 = router.getExpectedAddr(
            address(MockToken0),
            address(MockToken1)
        );
        pool newPool = pool(Pool1);
        uint256 inT = 1000;
        //$$\Delta Y = 906$$
        uint256 outT = 665;
        MockToken0.approve(address(newPool), 10000);
        MockToken0.transfer(address(newPool), inT);

        vm.expectEmit(true, true, false, true, address(newPool));
        emit Swap(address(this), address(MockToken0), inT, outT);

        newPool.swap(1000, address(MockToken0), 0, address(this));
    }

    function testTransferFailedForToken1() public {
        MockToken0.approve(address(Pool), 10000);

        bytes memory selectorOnly = abi.encodeWithSignature(
            "transfer(address,uint256)"
        );
        vm.mockCall(address(MockToken1), selectorOnly, abi.encode(false));

        vm.expectRevert("Out Transfer Failed");
        Pool.swap(1000, address(MockToken0), 900, address(this));

        vm.clearMockedCalls();
    }
}
