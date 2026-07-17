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
//for remove liquidity
const poolTkn = document.getElementById("poolTkn");
const exp_display = document.getElementById("exp_display");
const removeLiquidity_btn = document.getElementById("removeLiquidity_btn");
const lpQty = document.getElementById("lpQty");

let walletClient;
let publicClient = createPublicClient({
  chain: sepolia,
  transport: custom(window.ethereum),
});
let allPairs = [];
connectBTN.onclick = connect;
addLiquidityBTN.onclick = addLiquidity;
swapBTN.onclick = handleSwapSubmit;
removeLiquidity_btn.onclick = handleRemoveLiquidity;
async function connect() {
  if (window.ethereum) {
    walletClient = createWalletClient({
      transport: custom(window.ethereum),
    });
    await walletClient.requestAddresses();
    connectBTN.innerHTML = "Connected";
    await getAllTokens();
    await populateUserLPPools();
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

async function handleSwapSubmit(e) {
  e.preventDefault();
  const [account] = await walletClient.requestAddresses();
  const amountIn = parseEther(spendInput.value);

  // 1. Get the pre-calculated path and estimate
  const result = await getRouteAndEstimate(
    fromDropdown.value,
    toDropdown.value,
    spendInput.value,
    allPairs,
  );
  const amountOutMin = calculateMinimumAmount(parseEther(result.estimate));

  const deadline = BigInt(Math.floor(Date.now() / 1000) + 1200); // 20 mins

  //start here
  swapBTN.innerText = "Approving...";
  const allowance = await publicClient.readContract({
    address: fromDropdown.value,
    abi: erc20ABI,
    functionName: "allowance",
    args: [account, routerAddress],
  });

  if (allowance < amountIn) {
    console.log("Allowance insufficient. Requesting approval...");
    const { request: approveReq } = await publicClient.simulateContract({
      address: fromDropdown.value,
      abi: erc20ABI,
      functionName: "approve",
      args: [routerAddress, amountIn],
      account,
    });
    const approveTx = await walletClient.writeContract({
      ...approveReq,
      chain: currentChain,
    });
    // Block code execution until the approval transaction is fully mined
    await publicClient.waitForTransactionReceipt({ hash: approveTx });
    console.log("Approval confirmed.");
  }
  swapBTN.innerText = "Confirming Swap...";

  //end here

  const { request } = await publicClient.simulateContract({
    address: routerAddress,
    abi: routerABI,
    functionName: "swap",
    args: [amountIn, amountOutMin, result.path, account, deadline],
    account,
  });
  swapBTN.innerText = "Processing Trade...";
  const tx = await walletClient.writeContract({
    ...request,
    chain: currentChain,
  });
  swapBTN.innerText = "Success!";
  setTimeout(() => {
    swapBTN.innerText = "Swap";
  }, 3000);
}

async function populateUserLPPools() {
  walletClient = createWalletClient({
    transport: custom(window.ethereum),
  });

  const [account] = await walletClient.requestAddresses();

  //Get the total number of pools deployed by your factory
  const poolLength = await publicClient.readContract({
    address: factoryAddress,
    abi: factoryABI,
    functionName: "getPoolLength",
  });

  // Clear previous list options
  poolTkn.innerHTML =
    '<option value="" disabled selected>Select an LP Position</option>';
  let activePositionsCount = 0;

  // Loop through all tracked pairs
  for (let i = 0n; i < poolLength; i++) {
    const poolAddress = await publicClient.readContract({
      address: factoryAddress,
      abi: factoryABI,
      functionName: "allPool",
      args: [i],
    });

    // Check if the logged-in wallet holds any LP tokens for this address
    const lpBalance = await publicClient.readContract({
      address: poolAddress,
      abi: erc20ABI,
      functionName: "balanceOf",
      args: [account],
    });

    // If they own shares, fetch underlying token details to show a readable label
    if (lpBalance > 0n) {
      activePositionsCount++;

      const token0Address = await publicClient.readContract({
        address: poolAddress,
        abi: poolABI,
        functionName: "token0",
      });
      const token1Address = await publicClient.readContract({
        address: poolAddress,
        abi: poolABI,
        functionName: "token1",
      });

      const symbol0 = await publicClient.readContract({
        address: token0Address,
        abi: erc20ABI,
        functionName: "symbol",
      });
      const symbol1 = await publicClient.readContract({
        address: token1Address,
        abi: erc20ABI,
        functionName: "symbol",
      });

      const formattedBalance = formatEther(lpBalance);

      //Append to dropdown with unique data tags for removal parsing
      const optionHTML = `
        <option value="${poolAddress}" data-tkn0="${token0Address}" data-tkn1="${token1Address}">
          ${symbol0} / ${symbol1} (${parseFloat(formattedBalance).toFixed(4)} LP)
        </option>
      `;
      poolTkn.insertAdjacentHTML("beforeend", optionHTML);
    }
  }

  if (activePositionsCount === 0) {
    poolDropdown.innerHTML =
      '<option value="" disabled selected>No LP positions found in this wallet</option>';
  }
}

async function getMinAmount(poolAddress, lpTknAmount) {
  const lpAmount = BigInt(lpTknAmount);
  walletClient = createWalletClient({
    transport: custom(window.ethereum),
  });
  const totalLPSupply = await publicClient.readContract({
    address: poolAddress,
    abi: poolABI,
    functionName: "totalSupply",
  });
  const reserve0 = await publicClient.readContract({
    address: poolAddress,
    abi: poolABI,
    functionName: "qtyToken0",
  });
  const reserve1 = await publicClient.readContract({
    address: poolAddress,
    abi: poolABI,
    functionName: "qtyToken1",
  });
  if (totalLPSupply === 0n) {
    exp_display.innerHTML = `<p>Token 1: 0.0 <br> Token 2: 0.0</p>`;
    return { qtyAmount0Min: 0n, qtyAmount1Min: 0n };
  }
  const expectedAmount0 = (lpAmount * reserve0) / totalLPSupply;
  const expectedAmount1 = (lpAmount * reserve1) / totalLPSupply;
  console.log(expectedAmount0, expectedAmount1);

  const cleanToken1 = formatEther(expectedAmount0);
  const cleanToken2 = formatEther(expectedAmount1);

  exp_display.innerHTML = `
  <p>
    Token 1: ${cleanToken1}<br>
    Token 2: ${cleanToken2}
  </p>
`;
  const qtyAmount0Min = (expectedAmount0 * 97n) / 100n;
  const qtyAmount1Min = (expectedAmount1 * 97n) / 100n;
  return { qtyAmount0Min, qtyAmount1Min };
}

async function handleRemoveLiquidity(e) {
  e.preventDefault();
  if (!window.ethereum) return alert("Provider not found");

  walletClient = createWalletClient({
    transport: custom(window.ethereum),
  });

  const LPtokenQty = parseEther(lpQty.value);
  const LPtokenAddress = poolTkn.value;
  const [account] = await walletClient.requestAddresses();

  const { qtyAmount0Min, qtyAmount1Min } = await getMinAmount(
    LPtokenAddress,
    LPtokenQty,
  );

  removeLiquidity_btn.innerText = "Approving...";
  const allowance = await publicClient.readContract({
    address: LPtokenAddress,
    abi: erc20ABI,
    functionName: "allowance",
    args: [account, routerAddress],
  });

  if (allowance < LPtokenQty) {
    console.log("Allowance insufficient. Requesting approval...");
    const { request: approveReq } = await publicClient.simulateContract({
      address: LPtokenAddress,
      abi: erc20ABI,
      functionName: "approve",
      args: [routerAddress, LPtokenQty],
      account,
    });
    const approveTx = await walletClient.writeContract({
      ...approveReq,
      chain: currentChain,
    });
    await publicClient.waitForTransactionReceipt({ hash: approveTx });
    console.log("Approval confirmed.");
  }

  removeLiquidity_btn.innerText = "Processing Trade...";

  const { request } = await publicClient.simulateContract({
    address: routerAddress,
    abi: routerABI,
    functionName: "removeLiquidity",
    args: [LPtokenQty, LPtokenAddress, account, qtyAmount0Min, qtyAmount1Min],
    account,
  });

  const tx = await walletClient.writeContract({
    ...request,
    chain: currentChain,
  });

  await publicClient.waitForTransactionReceipt({ hash: tx });

  removeLiquidity_btn.innerText = "Success!";
  setTimeout(() => {
    removeLiquidity_btn.innerText = "Remove Liquidity";
  }, 3000);
}
