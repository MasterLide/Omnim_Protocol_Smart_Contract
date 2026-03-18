import { network } from "hardhat";

import { formatEther } from "viem";

const { viem } = await network.connect();

const publicClient = await viem.getPublicClient();
const [senderClient] = await viem.getWalletClients();
const signer = senderClient.account.address;
const Balance = await publicClient.getBalance({ address: signer})
const chainId = await publicClient.getChainId();
console.log("------------------Net Test: --------------------- ");
console.log("chainId: ", chainId);
console.log("signer: ", signer);
console.log("Balance :", formatEther(Balance));
console.log("------------------Net Test End --------------------- ");

