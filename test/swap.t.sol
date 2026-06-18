// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {deployPool} from "../script/deployPool.s.sol";
import {pool} from "../src/pool.sol";
import {mockToken0} from "./mockToken0.sol";
import {mockToken1} from "./mockToken1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract swap is Test {
    pool public Pool;

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
        MockToken0 = new mockToken0("MockTKN1", "MTKN_1", 1000000);
        MockToken1 = new mockToken1("MockTKN2", "MTKN_2", 500000);
        DeployPool = new deployPool();
        DeployPool.run(address(MockToken0), address(MockToken1));
        USER = makeAddr("USER");

        //the the hidden getter function for ' pool public Pool;'
        Pool = DeployPool.Pool();
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000, address(this));
    }

    //Swap Function tests
    function testForNoLiquidity() public {
        pool Pool1 = new pool(address(MockToken1), address(MockToken0));
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
        MockToken0.approve(address(Pool), 10000);
        Pool.swap(1000, address(MockToken0), 900, address(this));
        assertEq(Pool.qtyToken0(), 11000);
        assertLt(Pool.qtyToken1(), 10000);
    }

    function testQuantityUpdateTkn1() public {
        MockToken1.approve(address(Pool), 10000);
        Pool.swap(1000, address(MockToken1), 900, address(this));
        assertEq(Pool.qtyToken1(), 11000);
        assertLt(Pool.qtyToken0(), 10000);
    }

    // emit Swap(address(this), _tokenIn, _tokenAmtIn, _tokenAmtOut);
    function testEmitEvent() public {
        MockToken0.approve(address(Pool), 10000);
        uint256 inT = 1000;
        //$$\Delta Y = 906$$
        uint256 outT = 906;
        vm.expectEmit(true, true, false, true);
        emit Swap(address(this), address(MockToken0), inT, outT);
        Pool.swap(1000, address(MockToken0), 900, address(this));
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
