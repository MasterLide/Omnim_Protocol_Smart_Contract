import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { keccak256, encodeFunctionData, stringToBytes, Address } from "viem";
import { getAddr, args } from "../arguments.js";

describe("FactorySystemV0 For localhost", async function () {
  const { viem } = await network.connect({
  network: "localhost",
  chainType: "l1",
  });

  const [senderClient, test] = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();
  const chainId = await publicClient.getChainId();
  const addrs = getAddr(chainId);
    const mainToken = await viem.getContractAt("MainToken",addrs.MainToken as Address);
    const minerPool = await viem.getContractAt("MinerPool",addrs.MinerPool as Address);

    const subTokenV0 = await viem.getContractAt("SubTokenV0",addrs.SubTokenV0 as Address);
    const tokenFactoryV0 = await viem.getContractAt("TokenFactoryV0",addrs.TokenFactoryV0 as Address);

    const pancakeRouter = await viem.getContractAt("IUniswapV2Router02",addrs.PancakeRouter as Address);
    await mainToken.write.approve([pancakeRouter.address,args.threshold]);
    await subTokenV0.write.approve([pancakeRouter.address,args.threshold]);
    
    const btimestamp = (await publicClient.getBlock()).timestamp;
    console.log("chainId :", chainId, " btimestamp", btimestamp);

    await pancakeRouter.write.addLiquidity([
      mainToken.address,
      subTokenV0.address,
      args.threshold,
      args.threshold,
      0n,
      0n,
      senderClient.account.address,
      btimestamp + 100n
    ]);

    await tokenFactoryV0.write.setUniswapRouter([pancakeRouter.address]);

    const threshold1 = await tokenFactoryV0.read.getApplicationThreshold();
    console.log("thresholdStake :", threshold1);
    const threshold2 = await tokenFactoryV0.read.getApplicationThreshold();
    console.log("thresholdLp :", threshold2);

    await mainToken.write.mint([test.account.address,args.mainSuppy]);

  it("Should able to proposeSubToken", async function () {

    await test.writeContract({
        address: mainToken.address,
        abi:mainToken.abi,
        functionName: 'approve',
        args: [tokenFactoryV0.address,threshold1 + threshold2],
    });
    await viem.assertions.emit(
      test.writeContract({
        address: tokenFactoryV0.address,
        abi:tokenFactoryV0.abi,
        functionName: 'proposeSubToken',
        args: ["TestSub", "TSB",18, args.mainSuppy, test.account.address, threshold1, threshold2],
      }),
      tokenFactoryV0,
      "NewApplication"
    )
  });

  it("Should able to executeApplication and create with model1", async function () {
    await tokenFactoryV0.write.addPrivateTokenImpl([subTokenV0.address]);
    await tokenFactoryV0.write.setBurnPoint([args.burnPoint]);

    await viem.assertions.emit(
      test.writeContract({
        address: tokenFactoryV0.address,
        abi:tokenFactoryV0.abi,
        functionName: 'executeApplication',
        args: [1n, true,50n,1],
      }),
      tokenFactoryV0,
      "NewPersona"
    )
  });
/*
  it("Should deny SubTokenStakeWithdraw when block.timestamp < subTokenInfo.withdrawAbleAt", async function () {
    await viem.assertions.revert(
      test.writeContract({
        address: tokenFactoryV0.address,
        abi:tokenFactoryV0.abi,
        functionName: 'withdrawStake',
        args: [1n],
      })
    )
  });
*/
  it("Should able read SubTokenInfo when SubToken created ", async function () {
    const infos = await tokenFactoryV0.read.getSubTokenInfo([1n]);
    assert.equal(test.account.address, infos.founder.toLowerCase());
  });

  it("Should able to write SubToken when SubToken created", async function () {
    const infos = await tokenFactoryV0.read.getSubTokenInfo([1n]);
    const testSub = await viem.getContractAt("SubTokenV0",infos.token);
    await test.writeContract({
        address: testSub.address,
        abi:testSub.abi,
        functionName: 'transfer',
        args: [senderClient.account.address, args.threshold],
      });
    assert.equal(args.threshold, await testSub.read.balanceOf([senderClient.account.address]));
  });

  it("Should able to stake lp get Votes when SubToken created ", async function () {
    const infos = await tokenFactoryV0.read.getSubTokenInfo([1n]);
    const testSub = await viem.getContractAt("SubToken",infos.token);
    const testVe = await viem.getContractAt("VeToken",infos.veToken);
    const testLp = await viem.getContractAt("SubToken",infos.pool);

    await mainToken.write.mint([senderClient.account.address,args.threshold]);

    await mainToken.write.approve([pancakeRouter.address,args.threshold]);
    await testSub.write.approve([pancakeRouter.address,args.threshold]);
    
    const ctimestamp = (await publicClient.getBlock()).timestamp;
    console.log(" ctimestamp ", ctimestamp);

    await pancakeRouter.write.addLiquidity([
      mainToken.address,
      testSub.address,
      args.threshold,
      args.threshold,
      0n,
      0n,
      senderClient.account.address,
      ctimestamp + 100n
    ]);

    const mainbalance = await testLp.read.balanceOf([senderClient.account.address]);
    assert(mainbalance > 0 , "addLiquidity fail");

    await testLp.write.approve([testVe.address,mainbalance]);
    await testVe.write.stake([mainbalance,senderClient.account.address,senderClient.account.address]);

    assert.equal(mainbalance, await testVe.read.balanceOf([senderClient.account.address]));
  });

  it("Should able to mint/claim and auto mint on subMinerPool when created and mine opened", async function () {
    await minerPool.write.openMine();

    const infos = await tokenFactoryV0.read.getSubTokenInfo([1n]);
    const testMine = await viem.getContractAt("SubMinerPoolV0",infos.minerPool);

    await testMine.write.doMine();

    const [hadmine,minenum] = await testMine.read.getClaimableMines([senderClient.account.address]);
    console.log(" hadmine ", hadmine, " minenum ", minenum);
    assert(hadmine > 0 , "auto mint fail");
  });

});
