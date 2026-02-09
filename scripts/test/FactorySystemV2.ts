import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { keccak256, encodeFunctionData, stringToBytes, Address } from "viem";
import { getAddr, args } from "../arguments.js";

describe("FactorySystemV2 For localhost", async function () {
  const { viem } = await network.connect({
  network: "localhost",
  chainType: "l1",
  });

  const [senderClient, test] = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();
  const chainId = await publicClient.getChainId();
  const addrs = getAddr(chainId);
    const mainToken = await viem.getContractAt("MainToken",addrs.MainToken as Address);
    const veToken = await viem.getContractAt("VeToken",addrs.VeToken as Address);
    const tokenDAO = await viem.getContractAt("TokenDAO",addrs.TokenDAO as Address);
    const dataNft = await viem.getContractAt("DataNft",addrs.DataNft as Address);
    const minerPool = await viem.getContractAt("MinerPool",addrs.MinerPool as Address);
    const subMinerPool = await viem.getContractAt("SubMinerPool",addrs.SubMinerPool as Address);
    const subToken = await viem.getContractAt("SubToken",addrs.SubToken as Address);
    const tokenFactoryV2 = await viem.getContractAt("TokenFactoryV2",addrs.TokenFactoryV2 as Address);

    const pancakeRouter = await viem.getContractAt("IUniswapV2Router02",addrs.PancakeRouter as Address);
    await mainToken.write.approve([pancakeRouter.address,args.suppyMines]);
    await subToken.write.approve([pancakeRouter.address,args.suppyMines]);
    
    const btimestamp = (await publicClient.getBlock()).timestamp;
    console.log("chainId :", chainId, " btimestamp", btimestamp);

    await pancakeRouter.write.addLiquidity([
      mainToken.address,
      subToken.address,
      args.suppyMines,
      args.suppyMines,
      0n,
      0n,
      senderClient.account.address,
      btimestamp + 100n
    ]);

    await tokenFactoryV2.write.setUniswapRouter([pancakeRouter.address]);

    const threshold1 = await tokenFactoryV2.read.getApplicationThreshold();
    console.log("threshold1 :", threshold1);
    const cd = encodeFunctionData({abi:mainToken.abi,functionName: "mint",args: [test.account.address,args.mainSuppy]});
    const des0 = "test0";
    const des0Hash = keccak256(stringToBytes(des0));
    await tokenDAO.write.propose([[mainToken.address],[0n],[cd],des0]);

    const pid0 = await tokenDAO.read.getProposalId([[mainToken.address],[0n],[cd],des0Hash]);
    await tokenDAO.write.castVote([pid0, 1]);

  it("Should able to proposeSubToken and auto create", async function () {

    await test.writeContract({
        address: mainToken.address,
        abi:mainToken.abi,
        functionName: 'approve',
        args: [tokenFactoryV2.address,threshold1],
    });
    await viem.assertions.emit(
      test.writeContract({
        address: tokenFactoryV2.address,
        abi:tokenFactoryV2.abi,
        functionName: 'proposeSubToken',
        args: ["TestSub", "TSB", 0, 18, args.mainSuppy, threshold1, test.account.address],
      }),
      tokenFactoryV2,
      "NewPersona"
    )
  });

  it("Should able read SubTokenInfo in dataNft when SubToken created", async function () {
    const [,,founder,,] = await dataNft.read.subTokenInfos([1n]);
    assert.equal(test.account.address, founder.toLowerCase());
  });

  it("Should able to read/write SubToken", async function () {
    const [,token,,,] = await dataNft.read.subTokenInfos([1n]);
    const testSub = await viem.getContractAt("SubToken",token);
    await test.writeContract({
        address: testSub.address,
        abi:testSub.abi,
        functionName: 'mint',
        args: [senderClient.account.address, args.threshold],
      });
    assert.equal(args.threshold, await testSub.read.balanceOf([senderClient.account.address]));
  });

  it("Should able control SubToken to propose/castVote", async function () {
    const [,token,,,] = await dataNft.read.subTokenInfos([1n]);
    const testSub = await viem.getContractAt("SubToken",token);
    const des1 = "test1";
    const des1Hash = keccak256(stringToBytes(des1));
    const cda = encodeFunctionData({abi:mainToken.abi,functionName: "mint",args: [test.account.address,threshold1]});
    const cdb = encodeFunctionData({abi:tokenDAO.abi,functionName: "propose",args: [[mainToken.address],[0n],[cda],des1]});

    await test.writeContract({
        address: testSub.address,
        abi:testSub.abi,
        functionName: 'executeOperations',
        args: [tokenDAO.address, 0n,cdb],
      });

    const pid1 = await tokenDAO.read.getProposalId([[mainToken.address],[0n],[cda],des1Hash]);
    assert.equal(testSub.address, (await tokenDAO.read.proposalProposer([pid1])));
    await tokenDAO.write.castVote([pid1, 1]);
    
    let testbalance = args.mainSuppy - threshold1;
    assert.equal(testbalance, await mainToken.read.balanceOf([test.account.address]));

    const cdc = encodeFunctionData({abi:tokenDAO.abi,functionName: "castVote",args: [pid1, 1]});

    await viem.assertions.emit(
      test.writeContract({
        address: testSub.address,
        abi:testSub.abi,
        functionName: 'executeOperations',
        args: [tokenDAO.address, 0n,cdc],
      }),
      tokenDAO,
      "VoteCast"
    )

    assert.equal(args.mainSuppy, await mainToken.read.balanceOf([test.account.address]));
  });

  it("Should able to proposeSubToken and create with model1", async function () {
    await tokenFactoryV2.write.addImplementations([subToken.address,veToken.address,tokenDAO.address,subMinerPool.address]);
    await tokenFactoryV2.write.setPoint([args.poolPoint,args.burnPoint]);

    const threshold2 = threshold1 * 3n;
    console.log("threshold2 :", threshold2);

    await test.writeContract({
        address: mainToken.address,
        abi:mainToken.abi,
        functionName: 'approve',
        args: [tokenFactoryV2.address,threshold2],
    });
    await viem.assertions.emit(
      test.writeContract({
        address: tokenFactoryV2.address,
        abi:tokenFactoryV2.abi,
        functionName: 'proposeSubToken',
        args: ["TestSub2", "TSB2", 1, 18, args.mainSuppy, threshold2, test.account.address],
      }),
      tokenFactoryV2,
      "NewApplication"
    )

    await viem.assertions.emit(
      test.writeContract({
        address: tokenFactoryV2.address,
        abi:tokenFactoryV2.abi,
        functionName: 'executeApplication',
        args: [2n, true],
      }),
      tokenFactoryV2,
      "NewPersona"
    )
  });

  it("Should able read SubTokenInfo in dataNft when SubToken created with model1", async function () {
    const [,,founder,,] = await dataNft.read.subTokenInfos([2n]);
    assert.equal(test.account.address, founder.toLowerCase());
  });

  it("Should able to read/write SubToken when created with model1", async function () {
    const [,token2,,,] = await dataNft.read.subTokenInfos([2n]);
    const testSub2 = await viem.getContractAt("SubToken",token2);
    await test.writeContract({
        address: testSub2.address,
        abi:testSub2.abi,
        functionName: 'transfer',
        args: [senderClient.account.address, args.threshold],
      });
    assert.equal(args.threshold, await testSub2.read.balanceOf([senderClient.account.address]));
  });

  it("Should able control SubTokenDAO to control SubToken when created with model1", async function () {
    const [dao,token,,,] = await dataNft.read.subTokenInfos([2n]);
    const testSub = await viem.getContractAt("SubToken",token);
    const testDAO = await viem.getContractAt("TokenDAO",dao);
    const des2 = "test2";
    const des2Hash = keccak256(stringToBytes(des2));
    const cdc = encodeFunctionData({abi:testSub.abi,functionName: "mint",args: [senderClient.account.address,args.threshold]});

    await test.writeContract({
        address: testDAO.address,
        abi:testDAO.abi,
        functionName: 'propose',
        args: [[testSub.address], [0n],[cdc],des2],
      });

    const pid2 = await testDAO.read.getProposalId([[testSub.address],[0n],[cdc],des2Hash]);
    assert.equal(test.account.address, (await testDAO.read.proposalProposer([pid2])).toLowerCase());
    await viem.assertions.emit(
      test.writeContract({
        address: testDAO.address,
        abi:testDAO.abi,
        functionName: 'castVote',
        args: [pid2, 1],
      }),
      testDAO,
      "VoteCast"
    )    

    assert.equal(args.threshold, await testSub.read.balanceOf([senderClient.account.address]));
  });

  it("Should able control SubTokenDAO to propose/castVote when created with model1", async function () {
    const [dao,token,,,] = await dataNft.read.subTokenInfos([2n]);
    const testSub = await viem.getContractAt("SubToken",token);
    const testDAO = await viem.getContractAt("TokenDAO",dao);
    const des3 = "test3";
    const des3Hash = keccak256(stringToBytes(des3));
    const cdd = encodeFunctionData({abi:mainToken.abi,functionName: "mint",args: [test.account.address,threshold1]});
    const cde = encodeFunctionData({abi:tokenDAO.abi,functionName: "propose",args: [[mainToken.address],[0n],[cdd],des3]});

    await test.writeContract({
        address: testDAO.address,
        abi:testDAO.abi,
        functionName: 'propose',
        args: [[tokenDAO.address], [0n],[cde],des3],
      });

    const pid3 = await testDAO.read.getProposalId([[tokenDAO.address], [0n],[cde],des3Hash]);

    await test.writeContract({
        address: testDAO.address,
        abi:testDAO.abi,
        functionName: 'castVote',
        args: [pid3, 1],
      });

    const pid3_1 = await tokenDAO.read.getProposalId([[mainToken.address],[0n],[cdd],des3Hash]);

    assert.equal(testDAO.address, (await tokenDAO.read.proposalProposer([pid3_1])));
    await tokenDAO.write.castVote([pid3_1, 1]);
    
    let testbalance = args.mainSuppy - (threshold1 * 3n);
    assert.equal(testbalance, await mainToken.read.balanceOf([test.account.address]));

    const cdf = encodeFunctionData({abi:tokenDAO.abi,functionName: "castVote",args: [pid3_1, 1]});
    await test.writeContract({
        address: testDAO.address,
        abi:testDAO.abi,
        functionName: 'propose',
        args: [[tokenDAO.address], [0n],[cdf],des3],
      });

    const pid4 = await testDAO.read.getProposalId([[tokenDAO.address], [0n],[cdf],des3Hash]);
    await test.writeContract({
        address: testDAO.address,
        abi:testDAO.abi,
        functionName: 'castVote',
        args: [pid4, 1],
      });
    assert.equal(testbalance, await mainToken.read.balanceOf([test.account.address]));

    const [,token0,,,] = await dataNft.read.subTokenInfos([1n]);
    const test0Sub = await viem.getContractAt("SubToken",token0);
    await viem.assertions.emit(
      test.writeContract({
        address: test0Sub.address,
        abi:test0Sub.abi,
        functionName: 'executeOperations',
        args: [tokenDAO.address, 0n,cdf],
      }),
      tokenDAO,
      "VoteCast"
    )

    testbalance = args.mainSuppy - (threshold1 * 2n);
    assert.equal(testbalance, await mainToken.read.balanceOf([test.account.address]));
  });

  it("Should able to stake lp get Votes when created with model1", async function () {
    const [,token,,lp,vetoken] = await dataNft.read.subTokenInfos([2n]);
    const testSub = await viem.getContractAt("SubToken",token);
    const testVe = await viem.getContractAt("VeToken",vetoken);
    const testLp = await viem.getContractAt("SubToken",lp);

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

  it("Should able to mint/claim and auto mint on subMinerPool when created with model1", async function () {
    await minerPool.write.openMine();

    const [,,,,vetoken] = await dataNft.read.subTokenInfos([2n]);
    const testVe = await viem.getContractAt("VeToken",vetoken);
    const testmine = await testVe.read.mineaddr();
    const testMine = await viem.getContractAt("SubMinerPool",testmine);

    await testMine.write.doMine();

    const [hadmine,minenum] = await testMine.read.getClaimableMines([senderClient.account.address]);
    console.log(" hadmine ", hadmine, " minenum ", minenum);
    assert(hadmine > 0 , "auto mint fail");
  });

});
