// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {deployPool} from "../script/deployPool.s.sol";
import {pool} from "../src/pool.sol";
import {mockToken0} from "./mockToken0.sol";
import {mockToken1} from "./mockToken1.sol";
import {LPToken} from "../src/LPToken.sol";

contract poolTest is Test {
    pool public Pool;
    LPToken public lpToken;
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
        DeployPool.run(address(MockToken0), address(MockToken1));
        USER = makeAddr("USER");

        //the the hidden getter function for ' pool public Pool;'
        Pool = DeployPool.Pool();
    }

    function testCretePool() public view {
        address poolCreated = address(Pool);
        assertNotEq(poolCreated, address(0));
    }

    function testLpTokenCreated() public view {
        address lpTokenAddress = address(Pool.lpToken());
        assertNotEq(lpTokenAddress, address(0));
    }

    function testLPTokenMint() public {
        lpToken = new LPToken("LPTOken", "LPT");
        lpToken.mint(USER, 100);
        assertEq(lpToken.balanceOf(USER), 100);
    }

    function testLPTokenBurn() public {
        lpToken = new LPToken("LPTOken", "LPT");
        lpToken.mint(USER, 100);
        lpToken.burn(USER, 50);
        assertEq(lpToken.balanceOf(USER), 50);
    }

    function testLpOnlyTokenMintRevert() public {
        lpToken = new LPToken("LPTOken", "LPT");
        vm.prank(USER);
        vm.expectRevert("Only Pool Can Perform this action");
        lpToken.mint(USER, 100);
    }

    function testLPTokenBurnRevert() public {
        lpToken = new LPToken("LPTOken", "LPT");
        lpToken.mint(USER, 100);
        vm.expectRevert("Only Pool Can Perform this action");
        vm.prank(USER);
        lpToken.burn(USER, 50);
    }

    function testNullTokenPool() public {
        vm.expectRevert("Zero Address");
        //pool Pool1 = new pool(address(MockToken1), address(0));
        new pool(address(MockToken1), address(0));
    }

    function testSameToken() public {
        vm.expectRevert("Same Token");
        //pool Pool1 = new pool(address(MockToken1), address(MockToken1));
        new pool(address(MockToken1), address(MockToken1));
    }

    function testAddLiquidity() public {
        vm.expectRevert("Zero Amounts");
        Pool.addLiquidity(0, 0);
    }

    function testNoTokenMint() public {
        vm.expectRevert("Insufficient Liquidity Minted");
        Pool.addLiquidity(10, 10);
    }

    function testQuantityIsGettingUpdatedtkn0() public {
        uint256 initialQty = Pool.qtyToken0();
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000);
        uint256 finalQty = Pool.qtyToken0();
        assertNotEq(initialQty, finalQty);
    }

    function testQuantityIsGettingUpdatedtkn1() public {
        uint256 initialQty = Pool.qtyToken1();
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000);
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
        Pool.addLiquidity(10000, 10000);
    }

    function testToken0TransferToPool() public {
        //uint256 initialtoken0 = MockToken0.balanceOf(address(Pool));
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000);
        uint256 finaltoken0 = MockToken0.balanceOf(address(Pool));
        assertEq(finaltoken0, 10000);
    }

    function testToken1TransferToPool() public {
        //uint256 initialtoken0 = MockToken0.balanceOf(address(Pool));
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000);
        uint256 finaltoken1 = MockToken1.balanceOf(address(Pool));
        assertEq(finaltoken1, 10000);
    }

    function testLPTokenIsBurned() public {
        LPToken realLpToken = LPToken(Pool.lpToken());
        uint256 initialtotalLp = realLpToken.totalSupply();

        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000);

        uint256 lpAtAdd0 = realLpToken.balanceOf(address(1));
        uint256 userLpTkn = realLpToken.balanceOf(address(this));

        assertEq(initialtotalLp, 0);
        assertEq(lpAtAdd0, 1000);
        assertEq(userLpTkn, 9000);
    }

    function testSecondTimeLiquidity() public {
        //uint256 initialtoken0 = MockToken0.balanceOf(address(Pool));
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000);
        MockToken0.approve(address(Pool), 500);
        MockToken1.approve(address(Pool), 500);
        Pool.addLiquidity(500, 500);
        uint256 finaltoken0 = MockToken0.balanceOf(address(Pool));
        assertEq(finaltoken0, 10500);
    }

    function testLpTokenIsGenerated2ndTime() public {
        LPToken realLpToken = LPToken(Pool.lpToken());
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000);
        // upto here the User must hold 9000 LP token
        MockToken0.approve(address(Pool), 5000); //x>y:x?y --> True condition
        MockToken1.approve(address(Pool), 2000);
        Pool.addLiquidity(5000, 2000);
        uint256 userLpTkn = realLpToken.balanceOf(address(this));
        assertGt(userLpTkn, 9000); // Checks if userLpTkn > 9000
    }

    function testRevertsWhenNotTransferred() public {
        mockToken0 NewToken = new mockToken0("MockTKN1", "MTKN_1", 1000);
        pool Pool1 = new pool(address(NewToken), address(MockToken1));
        NewToken.approve(address(Pool1), 500);
        MockToken1.approve(address(Pool1), 500);

        vm.expectRevert();
        Pool1.addLiquidity(10000, 10000);
    }

    function testCheckFalseConditionOfTernary() public {
        //x>y:x?y --> false condition
        LPToken realLpToken = LPToken(Pool.lpToken());
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(10000, 10000);
        // upto here the User must hold 9000 LP token
        MockToken0.approve(address(Pool), 2000);
        MockToken1.approve(address(Pool), 2000);
        Pool.addLiquidity(2000, 2000);
        uint256 userLpTkn = realLpToken.balanceOf(address(this));
        assertGt(userLpTkn, 9000); // Checks if userLpTkn > 9000
    }
}
