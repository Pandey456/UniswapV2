import {
  createWalletClient,
  custom,
  createPublicClient,
  formatEther,
  parseEther,
} from "https://esm.sh/viem";

const connectBTN = document.getElementById("connect-btn");
const add_liquidity = document.getElementById("add_Liquidity");
// const goal_amt = document.getElementById("goal")
// const crt_cmp = document.getElementById("campgn")
// const display = document.getElementById("display")

// import { contractAddress, abi, abi_cmg } from "./constant-js.js";
// import { sepolia } from "https://esm.sh/viem/chains";

connectBTN.onclick = connect;
add_liquidity.onclick = addLiquidity;

let walletClient;
let publicClient;
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
async function addLiquidity() {
  connect();
}
