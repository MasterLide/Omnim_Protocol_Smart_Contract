import { network } from "hardhat";

import { formatEther } from "viem";
import { Address } from "viem";
import { getAddr, args } from "./arguments.js";

const { viem } = await network.connect();

console.log("Init on ");

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
console.log("PancakeRouter: ", addrs.PancakeRouter);
console.log("MainToken: ", addrs.MainToken);
console.log("VeToken: ", addrs.VeToken);
console.log("TokenDAO: ", addrs.TokenDAO);
console.log("TUSD: ", addrs.TUSD);
console.log("TokenFactoryV2: ", addrs.TokenFactoryV2);
console.log("MinerPool: ", addrs.MinerPool);
console.log("SubMinerPool: ", addrs.SubMinerPool);
console.log("SubToken: ", addrs.SubToken);
console.log("---------------------------------------------------- ");
console.log("Init start...");

console.log("Create Lp for MainToken&TUSD and addLiquidity..");
const pancakeRouter = await viem.getContractAt("IUniswapV2Router02",addrs.PancakeRouter as Address);
const PancakeFactory = await viem.getContractAt("IUniswapV2Factory", await pancakeRouter.read.factory());
const mainToken = await viem.getContractAt("MainToken",addrs.MainToken as Address);
const TUSD = await viem.getContractAt("SubToken",addrs.TUSD as Address);
await mainToken.write.approve([pancakeRouter.address,args.suppyPool]);
await TUSD.write.approve([pancakeRouter.address,args.suppyTUSDPool]);
const btimestamp = (await publicClient.getBlock()).timestamp;
await pancakeRouter.write.addLiquidity([
      mainToken.address,
      TUSD.address,
      args.suppyPool,
      args.suppyTUSDPool,
      0n,
      0n,
      signer,
      btimestamp + 300n
]);
const pairLp = await PancakeFactory.read.getPair([mainToken.address,TUSD.address]);
const Lp = await viem.getContractAt("IUniswapV2Pair",pairLp);
const LpBalance = await Lp.read.balanceOf([signer]);
console.log("Lp for MainToken&TUSD is : ", pairLp);
console.log("Liquidity: ",formatEther(LpBalance));
console.log("Create Lp for MainToken&TUSD and addLiquidity end");

const tokenFactoryV2 = await viem.getContractAt("TokenFactoryV2",addrs.TokenFactoryV2 as Address);
const minerPool = await viem.getContractAt("MinerPool",addrs.MinerPool as Address);
console.log("Set Router and Point on TokenFactoryV2..");
await tokenFactoryV2.write.setUniswapRouter([pancakeRouter.address]);
await tokenFactoryV2.write.setPoint([args.poolPoint,args.burnPoint]);
console.log("Set Router and Point on TokenFactoryV2 end");

console.log("Open Mine on minerPool..");
await minerPool.write.openMine();
console.log("Open Mine on minerPool end");

console.log("Init end");
