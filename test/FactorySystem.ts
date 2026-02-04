import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { keccak256, encodeFunctionData, stringToBytes } from "viem";

describe("FactorySystem", async function () {
  const { viem } = await network.connect();
  const [senderClient, test] = await viem.getWalletClients();
    const mainToken = await viem.deployContract("MainToken",[1000000000000000000n,senderClient.account.address]);

    const veToken = await viem.deployContract("VeToken");
    await veToken.write.initialize(["vetes","vts",senderClient.account.address,mainToken.address,0n,true]);

    const tokenDAO = await viem.deployContract("TokenDAO");
    await tokenDAO.write.initialize(["TokenDAO",veToken.address,1000000000000000000n,5]);

    const dataNft = await viem.deployContract("DataNft");
    await dataNft.write.initialize([senderClient.account.address]);

    const subToken = await viem.deployContract("SubToken");
    await subToken.write.initialize(["SubToken","SBT",18,20000000000000000000n,1000000000000000000n,senderClient.account.address]);

    const tokenFactory = await viem.deployContract("TokenFactory");
    await tokenFactory.write.initialize([
      subToken.address,
      mainToken.address,
      veToken.address,
      subToken.address,
      dataNft.address,
      1000000000000000000n,
      senderClient.account.address]);  
      
    await dataNft.write.grantRole([await dataNft.read.MINTER_ROLE(),tokenFactory.address]);

    await mainToken.write.approve([veToken.address,1000000000000000000n]);
    await veToken.write.stake([1000000000000000000n,senderClient.account.address,senderClient.account.address]);
    await mainToken.write.transferOwnership([tokenDAO.address]);
    const cd = encodeFunctionData({abi:mainToken.abi,functionName: "mint",args: [test.account.address,2000000000000000000n]});
    const des = "test";
    const desHash = keccak256(stringToBytes(des));
    await tokenDAO.write.propose([[mainToken.address],[0n],[cd],des]);

    const pid = await tokenDAO.read.getProposalId([[mainToken.address],[0n],[cd],desHash]);
    await tokenDAO.write.castVote([pid, 1]);

  it("Should able to proposeSubToken and auto create", async function () {
    await test.writeContract({
        address: mainToken.address,
        abi:mainToken.abi,
        functionName: 'approve',
        args: [tokenFactory.address,1000000000000000000n],
    });
    await viem.assertions.emit(
      test.writeContract({
        address: tokenFactory.address,
        abi:tokenFactory.abi,
        functionName: 'proposeSubToken',
        args: ["TestSub", "TSB", 0, 18, 1000000000000000000n, 1000000000000000000n, test.account.address],
      }),
      tokenFactory,
      "NewPersona"
    )
  });

  it("Should deny proposeSubToken when pledgeAmount < getApplicationThreshold", async function () {
    await viem.assertions.revertWith(
      test.writeContract({
        address: tokenFactory.address,
        abi:tokenFactory.abi,
        functionName: 'proposeSubToken',
        args: ["TestSub", "TSB", 0, 18, 1000000000000000000n, 100000000000000000n, test.account.address],
      }),
      "Insufficient asset token"
    )
  });

  it("Should deny proposeSubToken when allowance < pledgeAmount", async function () {
    await viem.assertions.revertWith(
      test.writeContract({
        address: tokenFactory.address,
        abi:tokenFactory.abi,
        functionName: 'proposeSubToken',
        args: ["TestSub", "TSB", 0, 18, 1000000000000000000n, 1000000000000000000n, test.account.address],
      }),
      "Insufficient asset token allowance"
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
        args: [senderClient.account.address, 1000000000000000000n],
      });
    assert.equal(1000000000000000000n, await testSub.read.balanceOf([senderClient.account.address]));
  });

  it("Should able control SubToken to propose/castVote", async function () {
    const [,token,,,] = await dataNft.read.subTokenInfos([1n]);
    const testSub = await viem.getContractAt("SubToken",token);
    const des2 = "test2";
    const desHash2 = keccak256(stringToBytes(des2));
    const cda = encodeFunctionData({abi:mainToken.abi,functionName: "mint",args: [test.account.address,1500000000000000000n]});
    const cdb = encodeFunctionData({abi:tokenDAO.abi,functionName: "propose",args: [[mainToken.address],[0n],[cda],des2]});

    await test.writeContract({
        address: testSub.address,
        abi:testSub.abi,
        functionName: 'executeOperations',
        args: [tokenDAO.address, 0n,cdb],
      });

    const pid2 = await tokenDAO.read.getProposalId([[mainToken.address],[0n],[cda],desHash2]);
    assert.equal(testSub.address, (await tokenDAO.read.proposalProposer([pid2])));
    await tokenDAO.write.castVote([pid2, 1]);

    assert.equal(1000000000000000000n, await mainToken.read.balanceOf([test.account.address]));

    const cdc = encodeFunctionData({abi:tokenDAO.abi,functionName: "castVote",args: [pid2, 1]});

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

    assert.equal(2500000000000000000n, await mainToken.read.balanceOf([test.account.address]));
  });

});
