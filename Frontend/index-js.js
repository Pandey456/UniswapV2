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
} from "./constant-js.js";
import { sepolia } from "https://esm.sh/viem/chains";
const connectBTN = document.getElementById("connect-btn");
const addLiquidityBTN = document.getElementById("addLiquidity_btn");

const Token1Address = document.getElementById("Tkn1");
const Token2Address = document.getElementById("Tkn2");
const QuantityToken1 = document.getElementById("Qty1");
const QuantityToken2 = document.getElementById("Qty2");

let walletClient;
let publicClient;
connectBTN.onclick = connect;
addLiquidityBTN.onclick = addLiquidity;
async function connect() {
  if (window.ethereum) {
    walletClient = createWalletClient({
      transport: custom(window.ethereum),
    });
    await walletClient.requestAddresses();
    connectBTN.innerHTML = "Connected";
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
  console.log("heyyeye");
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

  const { request } = await publicClient.simulateContract({
    address: routerAddress,
    abi: routerABI,
    functionName: "addLiquidity",
    args: [tkn1, tkn2, qty1, qty2, accountAddress],
    account: accountAddress,
  });
  const addLiquidityTxn = await walletClient.writeContract(request);
  console.log("Transaction submitted! Hash:", addLiquidityTxn);
}
