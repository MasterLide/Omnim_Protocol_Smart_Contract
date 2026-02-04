import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

describe("MinerPool", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const testClient = await viem.getTestClient();
  const [senderClient, test] = await viem.getWalletClients();

  it("Should able to mint/claim and auto mint when calling", async function () {
    const mainToken = await viem.deployContract("MainToken",[100000n,senderClient.account.address]);

    const veToken = await viem.deployContract("VeToken");
    await veToken.write.initialize(["vetes","vts",senderClient.account.address,mainToken.address,0n,true]);

    const minerPool = await viem.deployContract("MinerPool");
    await minerPool.write.initialize([mainToken.address,veToken.address,100000n,5000n,5000,50]);
    await veToken.write.setMiner([minerPool.address]);

    await mainToken.write.approve([veToken.address,200n]);
    await veToken.write.stake([200n,senderClient.account.address,test.account.address]);
    await mainToken.write.mint([minerPool.address,100000000n]);
    await minerPool.write.grantRole([await minerPool.read.GOV_ROLE(),senderClient.account.address]);
    await minerPool.write.openMine();

    const [claim, nums] = await minerPool.read.getTotalClaimableMines([senderClient.account.address]);

    assert.equal(50000n, claim);
    assert.equal(1n, nums);

    await testClient.request({method:"evm_increaseTime",params:[`0x15180`]});

    await minerPool.write.claimMyMines([senderClient.account.address]);

    const [claim2, nums2] = await minerPool.read.getTotalClaimableMines([senderClient.account.address]);
    assert.equal(0n, claim2);
    assert.equal(2n, nums2);
    //day1 = 100000 * 5000 / 10000 = 50000
    //day2 = (100000 - 5000) * (5000 + 50) / 10000 = 47975
    //100000 - 200 + 50000 + 47975 = 197775
    assert.equal(197775n, await mainToken.read.balanceOf([senderClient.account.address]));

    await testClient.request({method:"evm_increaseTime",params:[`0x15180`]});

    await minerPool.write.doMine();

    const [claim3, nums3] = await minerPool.read.getTotalClaimableMines([senderClient.account.address]);
    //day3 = (100000 - 10000) * (5000 + 100) / 10000 = 45900
    assert.equal(45900n, claim3);
    assert.equal(3n, nums3);


  });

});
