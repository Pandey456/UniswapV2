import {
  createWalletClient,
  custom,
  createPublicClient,
  formatEther,
  parseEther,
} from "https://esm.sh/viem";
import {
  routerAddress,
  factoryAddress,
  factoryABI,
  routerABI,
  poolABI,
  erc20ABI,
} from "./constant-js.js";
import { sepolia } from "https://esm.sh/viem/chains";
const connectBTN = document.getElementById("connect-btn");
const addLiquidityBTN = document.getElementById("addLiquidity_btn");
const currentChain = sepolia;
//for add liquidity
const Token1Address = document.getElementById("Tkn1");
const Token2Address = document.getElementById("Tkn2");
const QuantityToken1 = document.getElementById("Qty1");
const QuantityToken2 = document.getElementById("Qty2");
// for swap
const fromDropdown = document.getElementById("FromTkn");
const toDropdown = document.getElementById("ToTkn");
const spendInput = document.getElementById("FrmQty");
const receiveInput = document.getElementById("ToQty");
const swapBTN = document.getElementById("Swap_btn");

let walletClient;
let publicClient = createPublicClient({
  chain: sepolia,
  transport: custom(window.ethereum),
});
let allPairs = [];
connectBTN.onclick = connect;
addLiquidityBTN.onclick = addLiquidity;
async function connect() {
  if (window.ethereum) {
    walletClient = createWalletClient({
      transport: custom(window.ethereum),
    });
    await walletClient.requestAddresses();
    connectBTN.innerHTML = "Connected";
    await getAllTokens();
  } else {
    connectBTN.innerHTML = "Install Metamask First";
  }
}

async function addLiquidity(e) {
  e.preventDefault();
  if (window.ethereum) {
    walletClient = createWalletClient({
      transport: custom(window.ethereum),
    });
  }

  // this block is only to get msg.sender ----------------------
  const [accountAddress] = await walletClient.requestAddresses();
  // upto here ------------------------------------------
  // const publicClient = createPublicClient({
  //   transport: custom(window.ethereum),
  // });
  const tkn1 = Token1Address.value;
  const tkn2 = Token2Address.value;
  const qty1 = parseEther(QuantityToken1.value);
  const qty2 = parseEther(QuantityToken2.value);

  // ----------------- CHECK & APPROVE TOKEN 1 -----------------
  const allowance1 = await publicClient.readContract({
    address: tkn1,
    abi: erc20ABI,
    functionName: "allowance",
    args: [accountAddress, routerAddress],
  });

  if (allowance1 < qty1) {
    addLiquidityBTN.innerText = "Approving Token 1...";
    const { request } = await publicClient.simulateContract({
      address: tkn1,
      abi: erc20ABI,
      functionName: "approve",
      args: [routerAddress, qty1],
      account: accountAddress,
    });
    const txHash = await walletClient.writeContract({
      ...request,
      chain: currentChain,
    });
    // Wait for approval transaction to be mined before proceeding
    await publicClient.waitForTransactionReceipt({ hash: txHash });
  }

  // ----------------- CHECK & APPROVE TOKEN 2 -----------------
  const allowance2 = await publicClient.readContract({
    address: tkn2,
    abi: erc20ABI,
    functionName: "allowance",
    args: [accountAddress, routerAddress],
  });

  if (allowance2 < qty2) {
    addLiquidityBTN.innerText = "Approving Token 2...";
    const { request } = await publicClient.simulateContract({
      address: tkn2,
      abi: erc20ABI,
      functionName: "approve",
      args: [routerAddress, qty2],
      account: accountAddress,
    });
    const txHash = await walletClient.writeContract({
      ...request,
      chain: currentChain,
    });
    await publicClient.waitForTransactionReceipt({ hash: txHash });
  }

  const { request } = await publicClient.simulateContract({
    address: routerAddress,
    abi: routerABI,
    functionName: "addLiquidity",
    args: [tkn1, tkn2, qty1, qty2, accountAddress],
    account: accountAddress,
  });
  addLiquidityBTN.innerText = "Adding Liquidity...";
  const addLiquidityTxn = await walletClient.writeContract({
    ...request,
    chain: currentChain,
  });
  console.log("Transaction submitted! Hash:", addLiquidityTxn);
  addLiquidityBTN.innerText = "Successs!";
}
async function getAllTokens() {
  const fromDropdown = document.getElementById("FromTkn");
  const toDropdown = document.getElementById("ToTkn");
  // const publicClient = createPublicClient({
  //   transport: custom(window.ethereum),
  // });
  const poolLength = await publicClient.readContract({
    address: factoryAddress,
    abi: factoryABI,
    functionName: "getPoolLength",
  });
  console.log("Length = ", poolLength);
  const uniqueTokens = new Set();
  for (let i = 0; i < poolLength; i++) {
    const poolAddr = await publicClient.readContract({
      address: factoryAddress,
      abi: factoryABI,
      functionName: "allPool",
      args: [BigInt(i)],
    });
    const token0 = await publicClient.readContract({
      address: poolAddr,
      abi: poolABI,
      functionName: "token0",
    });

    const token1 = await publicClient.readContract({
      address: poolAddr,
      abi: poolABI,
      functionName: "token1",
    });
    allPairs.push({ token0: token0, token1: token1 });
    uniqueTokens.add(token0);
    uniqueTokens.add(token1);
  }
  fromDropdown.innerHTML =
    '<option value="" disabled selected>Select Token</option>';
  toDropdown.innerHTML =
    '<option value="" disabled selected>Select Token</option>';
  for (const tokenAddress of uniqueTokens) {
    const tokenSymbol = await publicClient.readContract({
      address: tokenAddress,
      abi: erc20ABI,
      functionName: "name",
    });
    const optionHTML = `<option value="${tokenAddress}">${tokenSymbol}</option>`;
    fromDropdown.insertAdjacentHTML("beforeend", optionHTML);
    toDropdown.insertAdjacentHTML("beforeend", optionHTML);
  }
}

async function getRouteAndEstimate(startToken, endToken, rawAmountIn, pairs) {
  const start = startToken.toLowerCase();
  const end = endToken.toLowerCase();
  if (start === end) return { path: [start], estimate: rawAmountIn };
  const adList = {};
  pairs.forEach((pair) => {
    const t0 = pair.token0.toLowerCase();
    const t1 = pair.token1.toLowerCase();
    if (!adList[t0]) adList[t0] = [];
    if (!adList[t1]) adList[t1] = [];
    adList[t0].push(t1);
    adList[t1].push(t0);
  });
  if (!adList[start] || !adList[end]) return null;
  const queue = [[start]];
  const visited = new Set([start]);
  let winningPath = null;
  while (queue.length > 0) {
    const path = queue.shift();
    const currentToken = path[path.length - 1];
    if (currentToken === end) {
      winningPath = path;
      break;
    }
    const nextNodes = adList[currentToken] || [];
    for (const nextNode of nextNodes) {
      if (!visited.has(nextNode)) {
        visited.add(nextNode);
        const newPath = [...path, nextNode];
        queue.push(newPath);
      }
    }
  }
  if (!winningPath) return null;
  try {
    let currentAmount = parseEther(rawAmountIn);
    for (let i = 0; i < winningPath.length - 1; i++) {
      const currentToken = winningPath[i];
      const nextToken = winningPath[i + 1];
      const poolAddress = await publicClient.readContract({
        address: routerAddress,
        abi: routerABI,
        functionName: "getExpectedAddr",
        args: [currentToken, nextToken],
      });
      // get reserve 0 from pool
      const reserve0 = await publicClient.readContract({
        address: poolAddress,
        abi: poolABI,
        functionName: "qtyToken0",
      });
      // get reserve 1 from pool
      const reserve1 = await publicClient.readContract({
        address: poolAddress,
        abi: poolABI,
        functionName: "qtyToken1",
      });
      // get token 0 from pool , so we can match it and sort
      const token0 = await publicClient.readContract({
        address: poolAddress,
        abi: poolABI,
        functionName: "token0",
      });
      // sorting to avaoid any mismatch in token address and quantity
      const [reserveIn, reserveOut] =
        currentToken.toLowerCase() === token0.toLowerCase()
          ? [reserve0, reserve1]
          : [reserve1, reserve0];
      if (reserveIn === 0n || reserveOut === 0n)
        return { path: winningPath, estimate: "0.0" };
      // Δy = (y · Δx · 997) / (x · 1000 + Δx · 997)
      const amountInWithFee = currentAmount * 997n;
      const numerator = amountInWithFee * reserveOut;
      const denominator = reserveIn * 1000n + amountInWithFee;

      currentAmount = numerator / denominator;
    }
    return {
      path: winningPath,
      estimate: formatEther(currentAmount),
    };
  } catch (error) {
    console.error("Failed to calculate pool price matrix:", error);
    return { path: winningPath, estimate: "Error" };
  }
}
function calculateMinimumAmount(expectedAmount) {
  const amount = BigInt(expectedAmount);
  if (amount === 0n) return 0n;

  return (amount * 97n) / 100n;
}

async function updateEstimatedOutput() {
  const tokenIn = fromDropdown.value;
  const tokenOut = toDropdown.value;
  const rawAmountIn = spendInput.value;

  // Clear output field early if inputs are incomplete
  if (!tokenIn || !tokenOut || !rawAmountIn || parseFloat(rawAmountIn) <= 0) {
    receiveInput.value = "";
    return;
  }

  try {
    receiveInput.value = "Calculating...";

    const result = await getRouteAndEstimate(
      tokenIn,
      tokenOut,
      rawAmountIn,
      allPairs,
    );

    if (!result || result.estimate === "0.0") {
      receiveInput.value = "No Liquidity/Route";
      return;
    }

    receiveInput.value = result.estimate;
  } catch (error) {
    console.error("Quote fetching failed:", error);
    receiveInput.value = "Error";
  }
}

// trigger update estimate
spendInput.oninput = updateEstimatedOutput;
fromDropdown.onchange = updateEstimatedOutput;
toDropdown.onchange = updateEstimatedOutput;
