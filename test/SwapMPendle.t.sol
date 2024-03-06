// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IWombatRouter {
    function getAmountOut(address[] calldata tokenPath, address[] calldata poolPath, int256 amountIn)
        external
        view
        returns (uint256 amountOut, uint256[] memory haircuts);

    /**
     * @notice Returns the minimum input asset amount required to buy the given output asset amount
     * (accounting for fees and slippage)
     * Note: This function should be used as estimation only. The actual swap amount might
     * be different due to precision error (the error is typically under 1e-6)
     */
    function getAmountIn(address[] calldata tokenPath, address[] calldata poolPath, uint256 amountOut)
        external
        view
        returns (uint256 amountIn, uint256[] memory haircuts);

    function swapExactTokensForTokens(
        address[] calldata tokenPath,
        address[] calldata poolPath,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);
}

interface IPool {
    function exchangeRate(address token) external view returns (uint256 xr);
}

contract SwapMPendle is Test {
    address public constant PENDLE = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8;
    address public constant MPENDLE = 0xB688BA096b7Bb75d7841e47163Cd12D18B36A5bF;
    address public constant MPENDLE_PENDLE_POOL = 0xe7159f15e7b1d6045506B228A1ed2136dcc56F48;

    IPool public pool = IPool(MPENDLE_PENDLE_POOL);
    IWombatRouter public router = IWombatRouter(0xc4B2F992496376C6127e73F1211450322E580668);
    IERC20 public pendle = IERC20(PENDLE);
    IERC20 public mPendle = IERC20(MPENDLE);

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("arbitrum"));

        // mock with 1000 ether and 1000 mPendle
        vm.deal(address(this), 100 ether);
        deal(MPENDLE, address(this), 1000 * 10 ** mPendle.decimals());
        mPendle.approve(address(router), type(uint256).max);

        vm.label(address(router), "ROUTER");
        vm.label(address(pendle), "PENDLE");
        vm.label(address(mPendle), "MPENDLE");
        vm.label(MPENDLE_PENDLE_POOL, "MPENDLE_PENDLE_POOL");
    }

    function testArbPendle() public {
        // input your token amount
        uint256 amountIn = 1000 * 1e18;

        address[] memory tokenPath = new address[](2);
        tokenPath[0] = MPENDLE;
        tokenPath[1] = PENDLE;
        address[] memory poolPath = new address[](1);
        poolPath[0] = MPENDLE_PENDLE_POOL;
        (uint256 amountOut,) = router.getAmountOut(tokenPath, poolPath, int256(amountIn));

        console.log("[START] Arb mPendle...");
        console.log("================= BEFORE ======================");
        console.log("mPendle:Pendle exchange rate", amountOut * (10 ** mPendle.decimals()) / amountIn);
        console.log("mPendle balance", mPendle.balanceOf(address(this)) / (10 ** mPendle.decimals()));
        console.log("pendle balance", pendle.balanceOf(address(this)) / (10 ** pendle.decimals()));

        address to = address(this);
        uint256 deadline = block.timestamp + 300;

        router.swapExactTokensForTokens(tokenPath, poolPath, amountIn, amountOut, to, deadline);

        console.log("[END] Arb mPendle");
        console.log("================= AFTER ======================");
        (uint256 newAmountOut,) = router.getAmountOut(tokenPath, poolPath, int256(amountIn));
        console.log("mPendle:Pendle exchange rate", newAmountOut * (10 ** mPendle.decimals()) / amountIn);
        console.log("mPendle balance", mPendle.balanceOf(address(this)) / (10 ** mPendle.decimals()));
        console.log("pendle balance", pendle.balanceOf(address(this)) / (10 ** pendle.decimals()));
    }
}
