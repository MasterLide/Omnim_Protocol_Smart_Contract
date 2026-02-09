import { network } from "hardhat";

import { formatEther } from "viem";
import { Address } from "viem";
import { getAddr, args } from "./arguments.js";

const { viem } = await network.connect();

console.log("proposeSubToken on ");

const publicClient = await viem.getPublicClient();
const [senderClient] = await viem.getWalletClients();
const signer = senderClient.account.address;
const Balance = await publicClient.getBalance({ address: signer})
const chainId = await publicClient.getChainId();
const addrs = getAddr(chainId);
console.log("chainId: ", chainId);
console.log("signer: ", signer);
console.log("Balance :", formatEther(Balance));
console.log("------------------Base Address: --------------------- ");
console.log("MainToken: ", addrs.MainToken);
console.log("TokenFactoryV2: ", addrs.TokenFactoryV2);
console.log("DataNft: ", addrs.DataNft);
console.log("---------------------------------------------------- ");

console.log("proposeSubToken ...");
const mainToken = await viem.getContractAt("MainToken",addrs.MainToken as Address);
const tokenFactoryV2 = await viem.getContractAt("TokenFactoryV2",addrs.TokenFactoryV2 as Address);
const dataNft = await viem.getContractAt("DataNft",addrs.DataNft as Address);
const threshold1 = await tokenFactoryV2.read.getApplicationThreshold();
console.log("threshold :", threshold1);
await mainToken.write.approve([tokenFactoryV2.address,threshold1]);
const txHash = await tokenFactoryV2.write.proposeSubToken(["TestSub", "TSB", 1, 18, args.mainSuppy, threshold1, signer]);
console.log("proposeSubToken txHash:", txHash);
const blocknum = (await publicClient.getTransactionReceipt({hash:txHash})).blockNumber;
const id = (await tokenFactoryV2.getEvents.NewApplication({fromBlock:blocknum,toBlock:blocknum}))[0].args.id;
const ApplicationId = id ? id : 0n;
console.log("ApplicationId: ", ApplicationId);
let info = await tokenFactoryV2.read.getApplication([ApplicationId]);
if (info.subTokenId == 0n){
    await tokenFactoryV2.write.executeApplication([ApplicationId,true]);
    info = await tokenFactoryV2.read.getApplication([ApplicationId]);
}
console.log("ApplicationInfo :",info);
const subTokenInfo = await dataNft.read.subTokenInfo([info.subTokenId]);
console.log("subTokenInfo :",subTokenInfo);