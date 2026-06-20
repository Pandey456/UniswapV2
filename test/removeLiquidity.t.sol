// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {deployPool} from "../script/deployPool.s.sol";
import {pool} from "../src/pool.sol";
import {mockToken0} from "./mockToken0.sol";
import {mockToken1} from "./mockToken1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract removeLiquidity is Test {
    pool public Pool;

    deployPool public DeployPool;
    mockToken0 public MockToken0;
    mockToken1 public MockToken1;
    address public USER;

    event RemovedLiquidity(
        address indexed sender,
        uint256 lpTokenIn,
        uint256 tokenOut0,
        uint256 tokenOut1
    );

    function setUp() public {
        //Pool = new pool();
        MockToken0 = new mockToken0("MockTKN1", "MTKN_1", 1000000);
        MockToken1 = new mockToken1("MockTKN2", "MTKN_2", 10000000);
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

    function testForNoLPToken() public {
        vm.expectRevert("Zero LP Token");
        Pool.removeLiquidity(0, address(this));
    }

    function testNoLiquidity() public {
        pool Pool1 = new pool();
        address owner = Pool1.i_FactoryAdddress();
        vm.prank(owner);
        Pool1.initizalized(address(MockToken0), address(MockToken1));

        vm.expectRevert("Insufficient Liquidity");
        Pool1.removeLiquidity(10, address(this));
    }

    /*         pool Pool1 = new pool(address(MockToken0), address(MockToken1));
        MockToken0.approve(address(Pool), 10000);
        MockToken1.approve(address(Pool), 10000);
        Pool.addLiquidity(1000, 1000, address(this));*/
    function testNoAmount() public {
        pool Pool1 = new pool();
        address owner = Pool1.i_FactoryAdddress();
        vm.prank(owner);
        Pool1.initizalized(address(MockToken0), address(MockToken1));
        MockToken0.approve(address(Pool1), 10000);
        MockToken1.approve(address(Pool1), 1000001);
        Pool1.addLiquidity(1005, 1000000, address(this));
        vm.expectRevert("Insufficient Amounts");
        Pool1.removeLiquidity(1, address(this));
    }

    function testEmitEvent() public {
        vm.expectEmit(true, false, false, true);
        /* added liquidity = token0 -> 10000 , token1 --> 10000
           LPTOken minted = sqrt (10,000 * 10,000) = 10,000
           out of which burned LP token = 1000
           LP Token Held by this contract = 9000 ( totalSupply-Minimum )
           while Removing liquidity for 1000 LP token 
           amount0 ---> ( number of token 0 to be removed ) 
           amount1 ---> ( number of token 1 to be removed ) 
           amount 0 = (LPToken given * Number of Token0 in pool) / Total LP token
           amount 1 = (LPToken given * Number of Token1 in pool) / Total LP token
           amount 0 = 1000*10,000 / 10,000 --> 1000
           amount 1 =  1000*10,000 / 10,000 --> 1000
           emit RemovedLiquidity(address(this), LPToken Given, Amount0, Amount1);
           */
        emit RemovedLiquidity(address(this), 1000, 1000, 1000);
        Pool.removeLiquidity(1000, address(this));
    }

    function testTransferFailedForToken0() public {
        // We target the MockToken0 address and the 'transfer(address,uint256)' function signature
        bytes memory calldataWithSelector = abi.encodeWithSelector(
            IERC20.transfer.selector,
            address(this), // The user receiving the funds
            1 // The amount expected to be transferred
        );
        bytes memory selectorOnly = abi.encodeWithSignature(
            "transfer(address,uint256)"
        );
        vm.mockCall(address(MockToken0), selectorOnly, abi.encode(false));
        vm.expectRevert("Token_0 Transfer Failed");
        Pool.removeLiquidity(1, address(this));
        vm.clearMockedCalls();
    }

    function testTransferFailedForToken1() public {
        bytes memory calldataWithSelector = abi.encodeWithSelector(
            IERC20.transfer.selector,
            address(this),
            1
        );
        bytes memory selectorOnly = abi.encodeWithSignature(
            "transfer(address,uint256)"
        );
        vm.mockCall(address(MockToken1), selectorOnly, abi.encode(false));
        vm.expectRevert("Token_1 Transfer Failed");
        Pool.removeLiquidity(1, address(this));
        vm.clearMockedCalls();
    }
}
