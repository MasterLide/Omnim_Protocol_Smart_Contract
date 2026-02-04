import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

describe("VeToken", async function () {
  const { viem } = await network.connect();
  const [senderClient, test] = await viem.getWalletClients();

  it("Should stake and change delegatee when calling the stake() function", async function () {
    const mainToken = await viem.deployContract("MainToken",[100000n,senderClient.account.address]);
    const veToken = await viem.deployContract("VeToken");

    await veToken.write.initialize(["vetes","vts",test.account.address,mainToken.address,0n,true]);
    await mainToken.write.approve([veToken.address,200n]);
    await veToken.write.stake([100n,senderClient.account.address,test.account.address]);
    assert.equal(100n, await veToken.read.balanceOf([senderClient.account.address]));
    assert.equal(100n, await veToken.read.getVotes([test.account.address]));
    assert.equal(0n, await veToken.read.getVotes([senderClient.account.address]));

    await veToken.write.stake([100n,senderClient.account.address,senderClient.account.address]);
    assert.equal(200n, await veToken.read.balanceOf([senderClient.account.address]));
    assert.equal(200n, await veToken.read.getVotes([senderClient.account.address]));
    assert.equal(0n, await veToken.read.getVotes([test.account.address]));

  });

  it("Should withdraw and change delegatee Votes when calling the withdraw() function", async function () {
    const mainToken = await viem.deployContract("MainToken",[100000n,senderClient.account.address]);
    const veToken = await viem.deployContract("VeToken");

    await veToken.write.initialize(["vetes","vts",test.account.address,mainToken.address,0n,true]);
    await mainToken.write.approve([veToken.address,200n]);
    await veToken.write.stake([200n,senderClient.account.address,test.account.address]);

    await veToken.write.withdraw([100n]);
    assert.equal(100n, await veToken.read.balanceOf([senderClient.account.address]));
    assert.equal(0n, await veToken.read.getVotes([senderClient.account.address]));
    assert.equal(100n, await veToken.read.getVotes([test.account.address]));

  });
});
