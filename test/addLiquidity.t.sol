// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {deployPool} from "../script/deployPool.s.sol";
import {pool} from "../src/pool.sol";
import {mockToken0} from "./mockToken0.sol";
import {mockToken1} from "./mockToken1.sol";

contract addLiquidity is Test {
    pool public Pool;
    deployPool public DeployPool;
    mockToken0 public MockToken0;
    mockToken1 public MockToken1;
    address public USER;
    event Mint(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        uint256 lpshares
    );

    function setUp() public {
        //Pool = new pool();
        MockToken0 = new mockToken0("MockTKN1", "MTKN_1", 1000000);
        MockToken1 = new mockToken1("MockTKN2", "MTKN_2", 500000);
        DeployPool = new deployPool();
        DeployPool.run();
        USER = makeAddr("USER");

        //the the hidden getter function for ' pool public Pool;'
        Pool = DeployPool.Pool();
        address owner = Pool.i_FactoryAddress();
        vm.prank(owner);
        Pool.initizalize(address(MockToken0), address(MockToken1));
    }

    function testCretePool() public view {
        address poolCreated = address(Pool);
        assertNotEq(poolCreated, address(0));
    }

    function testLpTokenCreated() public view {
        address lpTokenAddress = address(Pool);
        assertNotEq(lpTokenAddress, address(0));
    }

    function testLPTokenMint() public {
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000, address(this));

        assertEq(Pool.balanceOf(address(this)), 9000);
    }

    function testLPTokenBurn() public {
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000, address(this));

        assertEq(Pool.balanceOf(address(1)), 1000);
    }

    function testNullTokenPool() public {
        //vm.expectRevert("Zero Address");
        pool Pool1 = new pool();
        address owner = Pool1.i_FactoryAddress();
        vm.prank(owner);
        vm.expectRevert("Zero Address");
        Pool1.initizalize(address(MockToken1), address(0));
    }

    function testSameToken() public {
        pool Pool1 = new pool();
        address owner = Pool1.i_FactoryAddress();
        vm.prank(owner);
        vm.expectRevert("Same Token");
        Pool1.initizalize(address(MockToken1), address(MockToken1));
    }

    function testAddLiquidity() public {
        vm.expectRevert("Zero Amounts");
        Pool.addLiquidity(0, 0, address(this));
    }

    function testNoTokenMint() public {
        vm.expectRevert("Insufficient Liquidity Minted");
        Pool.addLiquidity(10, 10, address(this));
    }

    function testQuantityIsGettingUpdatedtkn0() public {
        uint256 initialQty = Pool.qtyToken0();
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000, address(this));
        uint256 finalQty = Pool.qtyToken0();
        assertNotEq(initialQty, finalQty);
    }

    function testQuantityIsGettingUpdatedtkn1() public {
        uint256 initialQty = Pool.qtyToken1();
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000, address(this));
        uint256 finalQty = Pool.qtyToken1();
        assertNotEq(initialQty, finalQty);
    }

    function testEventEmit() public {
        uint256 token0Qty = 10000;
        uint256 token1Qty = 10000;
        // Calculate what the LP tokens to mint will be:
        // sqrt(10000 * 10000) - 1000 = 10000 - 1000 = 9000
        uint256 expectedLpTokens = 9000;

        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        vm.expectEmit(true, false, false, true);
        //solidity : named emit can only have 3 indexed value,
        // 1st true = 1st indexed value
        // 2nd false = there is no 2nd indexed value
        // 3rd false = there is not 3rd indexed value either
        // 4th true = apart from indexed value any data

        emit Mint(address(this), token0Qty, token1Qty, expectedLpTokens);
        // in above line we are saying foundry what value and structure of emit to expect
        Pool.addLiquidity(10000, 10000, address(this));
    }

    function testLPTokenIsBurned() public {
        uint256 initialtotalLp = Pool.totalSupply();

        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000, address(this));

        uint256 lpAtAdd0 = Pool.balanceOf(address(1));
        uint256 userLpTkn = Pool.balanceOf(address(this));

        assertEq(initialtotalLp, 0);
        assertEq(lpAtAdd0, 1000);
        assertEq(userLpTkn, 9000);
    }

    function testLpTokenIsGenerated2ndTime() public {
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000, address(this));
        // upto here the User must hold 9000 LP token
        MockToken0.approve(address(Pool), 5000); //x>y:x?y --> True condition
        MockToken1.approve(address(Pool), 2000);
        Pool.addLiquidity(5000, 2000, address(this));
        uint256 userLpTkn = Pool.balanceOf(address(this));
        assertGt(userLpTkn, 9000); // Checks if userLpTkn > 9000
    }

    function testCheckFalseConditionOfTernary() public {
        //x>y:x?y --> false condition

        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000, address(this));
        // upto here the User must hold 9000 LP token
        MockToken0.approve(address(Pool), 2000);
        MockToken1.approve(address(Pool), 2000);
        Pool.addLiquidity(2000, 2000, address(this));
        uint256 userLpTkn = Pool.balanceOf(address(this));
        assertGt(userLpTkn, 9000); // Checks if userLpTkn > 9000
    }

    function testOnlyOwner() public {
        address mockFactory = address(0x123);
        pool Pool1 = new pool();
        vm.prank(mockFactory);
        vm.expectRevert("Not a Owner");
        Pool1.initizalize(address(MockToken1), address(MockToken0));
    }

    function testAlreadyInitialized() public {
        pool Pool1 = new pool();
        Pool1.initizalize(address(MockToken1), address(MockToken0));
        vm.expectRevert("Already initizalize");
        Pool1.initizalize(address(MockToken0), address(MockToken1));
    }

    function testInitializedZeroAddress() public {
        pool Pool1 = new pool();

        vm.expectRevert("Zero Address");
        Pool1.initizalize(address(0), address(MockToken1));
    }

    function testInitializedSameAddress() public {
        pool Pool1 = new pool();

        vm.expectRevert("Same Token");
        Pool1.initizalize(address(MockToken1), address(MockToken1));
    }
}
