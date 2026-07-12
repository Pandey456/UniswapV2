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
const Token1Address = document.getElementById("Tkn1");
const Token2Address = document.getElementById("Tkn2");
const QuantityToken1 = document.getElementById("Qty1");
const QuantityToken2 = document.getElementById("Qty2");

let walletClient;
let publicClient;
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
  const publicClient = createPublicClient({
    transport: custom(window.ethereum),
  });
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
  const publicClient = createPublicClient({
    transport: custom(window.ethereum),
  });
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
    allPairs.push({ token0, token1 });
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
