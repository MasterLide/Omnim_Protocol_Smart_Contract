import { network } from "hardhat";

import { formatEther } from "viem";
import { keccak256, encodeFunctionData, stringToBytes, Address } from "viem";
import { getAddr, args } from "./arguments.js";

const { viem } = await network.connect();

console.log("Mint on ");

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
console.log("TokenDAO: ", addrs.TokenDAO);
console.log("---------------------------------------------------- ");
console.log("Mint start...");

console.log("Mint before..");
const mainToken = await viem.getContractAt("MainToken",addrs.MainToken as Address);
const tokenDAO = await viem.getContractAt("TokenDAO",addrs.TokenDAO as Address);
let mainTokenBalance = await mainToken.read.balanceOf([signer]);
console.log("mainTokenBalance :", formatEther(mainTokenBalance));
console.log("Propose Mint Proposal on TokenDAO");
const calldata = encodeFunctionData({abi:mainToken.abi,functionName: "mint",args: [signer,args.mainSuppy]});
const des = "Mint Proposal";
const desHash = keccak256(stringToBytes(des));
await tokenDAO.write.propose([[mainToken.address],[0n],[calldata],des]);

console.log("CastVote Mint Proposal on TokenDAO");
const pid = await tokenDAO.read.getProposalId([[mainToken.address],[0n],[calldata],desHash]);
await tokenDAO.write.castVote([pid, 1]);

console.log("Mint after..");
mainTokenBalance = await mainToken.read.balanceOf([signer]);
console.log("mainTokenBalance :", formatEther(mainTokenBalance));
console.warn("Warning: If forVotes < totalSupply,Proposal can not auto execute, it many call execute(proposalId) when votingPeriod end!");
console.log("Mint end");
